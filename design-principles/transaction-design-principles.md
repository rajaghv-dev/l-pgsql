# Transaction Design Principles

Principles for using transactions correctly in PostgreSQL applications.

---

## Principle 1: Keep transactions as short as possible

### One-line rule
Open a transaction only when you are ready to execute all statements; close it immediately after the last statement.

### Rationale
Long-running transactions hold locks, block VACUUM, accumulate MVCC dead tuples, and hold connection resources. Every second a transaction stays open increases the risk of conflict with other transactions.

### Example (correct)
```sql
-- Prepare all values before BEGIN
-- (API calls, validation, etc. happen outside the transaction)
BEGIN;
INSERT INTO orders (user_id, total) VALUES (42, 150.00);
INSERT INTO order_items (order_id, product_id, qty) VALUES (currval('orders_id_seq'), 7, 2);
COMMIT;
```

### Counter-example (incorrect)
```sql
BEGIN;
-- ... application sends email to user (network call, could take seconds/fail) ...
-- ... application waits for user confirmation via API ...
INSERT INTO orders ...;  -- Transaction held open during all of the above
COMMIT;
```

### When this principle applies
Always. No exceptions for application-side I/O inside a transaction.

### When to break it (with justification)
Long-running batch migrations that are intentionally atomic. Schedule during off-peak hours and monitor `pg_stat_activity`.

### PostgreSQL implementation
```sql
-- See current transaction durations
SELECT pid, now() - xact_start AS age, state, query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY age DESC;
```

### Agent/MCP implications
MCP tools must open transactions only around the database statements themselves. Never hold a transaction open across LLM inference calls or HTTP requests.

### Related principles
[[advanced-design-principles]] Principle 1

---

## Principle 2: Never perform user interaction or external I/O inside a transaction

### One-line rule
Do all computation, external API calls, and user prompts before opening a transaction — the transaction should contain only database statements.

### Rationale
If an external API call takes 5 seconds inside a transaction, you hold locks for 5+ seconds. If the API call fails, you have a partial transaction state to handle. If the application crashes, the transaction rolls back but any external effects (email sent, payment charged) do not.

### Example (correct)
```sql
-- 1. Call payment API (outside transaction)
-- 2. If payment succeeds, open transaction:
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 42;
INSERT INTO transactions (type, amount) VALUES ('payment', 100);
COMMIT;
```

### Counter-example (incorrect)
```sql
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 42;
-- [application calls payment API — holds lock on accounts row] 
INSERT INTO transactions ...;
COMMIT;
```

---

## Principle 3: Always handle transaction rollback in application code

### One-line rule
Every code path that opens a transaction must have an explicit handler that rolls back on error — never leave a transaction in limbo.

### Rationale
An uncommitted transaction holds locks and connection state. If the application catches an error and forgets to ROLLBACK, the transaction remains open until the connection closes or times out. In connection pool scenarios, the next request may inherit the broken state.

### Example (correct)
```python
# Python/psycopg3 pattern
with conn.transaction():
    cur.execute("INSERT INTO orders ...")
    cur.execute("INSERT INTO order_items ...")
# conn.transaction() commits on success, rolls back on exception automatically
```

```sql
-- In PL/pgSQL:
BEGIN
    INSERT INTO orders ...;
    INSERT INTO order_items ...;
EXCEPTION WHEN OTHERS THEN
    RAISE;  -- Re-raise; calling code sees the error, transaction rolls back
END;
```

---

## Principle 4: Use SAVEPOINT for partial rollback within a long transaction

### One-line rule
Use `SAVEPOINT` to create partial rollback points when you need to attempt a risky operation and recover without rolling back the entire transaction.

### Rationale
Some operations may fail predictably (e.g., inserting a row that might violate a unique constraint). Without SAVEPOINT, a failure aborts the entire transaction. SAVEPOINT lets you catch the error, roll back to a known-good point, and continue.

### Example (correct)
```sql
BEGIN;
INSERT INTO orders (user_id, total) VALUES (42, 150.00);

SAVEPOINT before_coupon;
BEGIN
    INSERT INTO coupon_uses (order_id, coupon_id) VALUES (currval('orders_id_seq'), 99);
EXCEPTION WHEN unique_violation THEN
    ROLLBACK TO SAVEPOINT before_coupon;
    -- Coupon already used; continue without it
END;

COMMIT;
```

### When to break it (with justification)
When partial failure of any step should fail the entire operation. Don't use SAVEPOINT as a mechanism to silently swallow errors.

---

## Principle 5: Use SERIALIZABLE isolation only when the business logic requires it

### One-line rule
Default to READ COMMITTED; use SERIALIZABLE only for "check-then-act" patterns where write skew would produce incorrect results.

### Rationale
SERIALIZABLE prevents all anomalies but causes more transaction aborts (serialization failures). Your application must detect `ERROR 40001` (serialization_failure) and retry the transaction. This retry logic adds complexity that is only worth it when the correctness guarantee is truly needed.

### Example (correct)
```sql
-- Seat reservation: two users must not book the same seat
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT count(*) FROM bookings WHERE seat_id = 42 AND status = 'confirmed';
-- If count = 0:
INSERT INTO bookings (seat_id, user_id, status) VALUES (42, 99, 'confirmed');
COMMIT;
-- Application catches ERROR 40001 and retries
```

### Counter-example (incorrect)
```sql
-- Using SERIALIZABLE for a simple insert that has no read-check pattern
BEGIN ISOLATION LEVEL SERIALIZABLE;
INSERT INTO log_entries (message, created_at) VALUES ('user logged in', now());
COMMIT;  -- SERIALIZABLE overhead with no benefit here
```

### Agent/MCP implications
MCP tools that implement "check if X exists, then do Y" patterns should use SERIALIZABLE or a `SELECT ... FOR UPDATE` locking approach to prevent write skew.

---

## Principle 6: Prefer explicit locking with FOR UPDATE over application-level retries for critical sections

### One-line rule
Use `SELECT ... FOR UPDATE` to lock specific rows you intend to modify — it is clearer and more efficient than application retries.

### Rationale
`FOR UPDATE` acquires a row-level lock at read time, preventing other transactions from modifying those rows until you commit. This is the correct pattern for "read-modify-write" operations like balance deductions.

### Example (correct)
```sql
BEGIN;
SELECT balance FROM accounts WHERE id = 42 FOR UPDATE;
-- Locked: no other transaction can update this row until we commit
UPDATE accounts SET balance = balance - 100 WHERE id = 42;
COMMIT;
```

### Counter-example (incorrect)
```sql
-- Optimistic pattern without FOR UPDATE — concurrent transactions see same balance
SELECT balance FROM accounts WHERE id = 42;
-- Another transaction also sees balance = 1000 and deducts 100
UPDATE accounts SET balance = balance - 100 WHERE id = 42;
-- Both transactions succeed, but $200 total was deducted from $1000 balance
```

### When to break it (with justification)
Low-contention scenarios with a retry mechanism benefit from optimistic locking (check version/timestamp on update). `FOR UPDATE` serializes access and reduces throughput on hot rows.
