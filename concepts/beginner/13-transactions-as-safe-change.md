# Transactions as Safe Change

Level: Beginner

## One-line intuition

A transaction is a group of SQL statements that either all succeed together or all fail together — no partial outcomes.

## Why this exists

Real operations involve multiple steps. Transferring money requires deducting from one account and adding to another. If the system crashes between the two steps, the database would be in a corrupt state without transactions. Transactions guarantee that never happens.

## First-principles explanation

A transaction is bounded by BEGIN and COMMIT. Everything between them is treated as a single atomic unit:

```
BEGIN;
  -- step 1
  -- step 2
  -- step 3
COMMIT;  -- all three steps become permanent, or none do
```

If anything goes wrong (application crash, network loss, constraint violation), the transaction is rolled back — all changes are undone, and the database returns to the state before BEGIN.

## Micro-concepts

| Command | Effect |
|---------|--------|
| `BEGIN` | Start a transaction |
| `COMMIT` | Make all changes permanent |
| `ROLLBACK` | Undo all changes since BEGIN |
| `SAVEPOINT name` | Create a partial rollback point within a transaction |
| `ROLLBACK TO name` | Undo back to the savepoint (not the full transaction) |
| `RELEASE SAVEPOINT name` | Discard a savepoint (keep its changes) |

**Auto-commit**: By default, PostgreSQL wraps each statement in its own transaction automatically. Every single statement is already a transaction — BEGIN/COMMIT are only needed when you want to group multiple statements.

## Beginner view

Bank transfer analogy:

```sql
BEGIN;

-- Step 1: Deduct from Alice
UPDATE accounts SET balance = balance - 100 WHERE id = 1;

-- Step 2: Add to Bob
UPDATE accounts SET balance = balance + 100 WHERE id = 2;

COMMIT;  -- Both steps permanent, or neither
```

If the database crashes after step 1 but before COMMIT, PostgreSQL rolls back the deduction on restart. Alice's money is safe.

Without a transaction, a crash after step 1 would leave Alice's money gone and Bob's money unchanged — a permanent loss.

## Intermediate view

**ACID** — the four properties that define a transaction:

| Property | Meaning |
|----------|---------|
| **Atomicity** | All or nothing — no partial commits |
| **Consistency** | Transaction moves DB from one valid state to another |
| **Isolation** | Concurrent transactions do not see each other's partial changes |
| **Durability** | Committed data survives crashes (written to WAL) |

**Isolation levels** (weakest to strongest):

| Level | What it prevents |
|-------|----------------|
| READ COMMITTED (default) | Dirty reads |
| REPEATABLE READ | Non-repeatable reads |
| SERIALIZABLE | Phantom reads, serialization anomalies |

PostgreSQL defaults to READ COMMITTED. Most applications do not need to change this.

**SAVEPOINTs** allow partial rollback:

```sql
BEGIN;
INSERT INTO orders VALUES (1, 'item_a');
SAVEPOINT sp1;
INSERT INTO orders VALUES (2, 'bad_item');  -- mistake
ROLLBACK TO sp1;  -- undo only the bad insert
INSERT INTO orders VALUES (2, 'good_item');
COMMIT;
```

## Advanced view

- PostgreSQL uses **MVCC** (Multi-Version Concurrency Control): writers do not block readers. Each transaction sees a snapshot of the database at its start time.
- **WAL** (Write-Ahead Log): changes are written to WAL before the main table. On crash, PostgreSQL replays the WAL to recover committed transactions and discard uncommitted ones.
- `idle in transaction` is a dangerous state: a session that started a transaction but has not committed/rolled back holds locks. Long-running idle transactions block VACUUM and other writes.
- `lock_timeout` and `statement_timeout` prevent runaway transactions.

## Mental model

A transaction is a checkpoint-based undo/redo system. Every step is logged. COMMIT says "keep all the logged steps." ROLLBACK says "discard all the logged steps." The log (WAL) survives a crash.

## PostgreSQL view

```sql
-- Check current transaction isolation level
SHOW transaction_isolation;

-- Set isolation for a specific transaction
BEGIN ISOLATION LEVEL REPEATABLE READ;
...
COMMIT;

-- See open transactions (admin)
SELECT pid, state, query, now() - query_start AS duration
FROM pg_stat_activity
WHERE state = 'idle in transaction';
```

## SQL view

```sql
-- Safe bank transfer
BEGIN;

UPDATE bank_accounts
SET balance = balance - 100
WHERE id = 1 AND balance >= 100;  -- check sufficient funds

-- In application code, verify 1 row was updated before continuing
-- If 0 rows: ROLLBACK;

UPDATE bank_accounts
SET balance = balance + 100
WHERE id = 2;

COMMIT;

-- Demonstrate rollback
BEGIN;
DELETE FROM bank_accounts WHERE id = 1;
-- Oops, wrong account
ROLLBACK;
-- Table is unchanged
```

## Non-SQL or hybrid view

ORMs wrap each database call in a transaction by default. Django uses `ATOMIC_REQUESTS` to wrap the entire HTTP request in a transaction. The risk: long HTTP requests hold a transaction open for their entire duration, blocking VACUUM and holding locks.

## Design principle

**Keep transactions short.** Long transactions hold locks and block other writers. Do the minimal amount of work inside BEGIN/COMMIT — move validation, computation, and external calls (HTTP, file I/O) outside the transaction.

## Critical thinking

- What happens if the application crashes after COMMIT is sent but before PostgreSQL processes it? PostgreSQL's WAL guarantees durability — the COMMIT is either fully durable or not committed at all. There is no in-between.
- Two concurrent transactions both check `balance >= 100` and both see 150. Both deduct 100. Result: balance = -50. This is a **lost update** — prevented by `SERIALIZABLE` isolation or by using `SELECT ... FOR UPDATE` to lock the row.

## Creative thinking

Transactions can be used for safe schema migrations: wrap DDL in a transaction, run tests, ROLLBACK if tests fail, COMMIT if they pass. PostgreSQL supports transactional DDL (unlike MySQL for most DDL statements).

```sql
BEGIN;
ALTER TABLE books ADD COLUMN rating NUMERIC(3,2);
-- test the change
SELECT * FROM books LIMIT 5;
-- if happy:
COMMIT;
-- if not:
-- ROLLBACK;
```

## Systems thinking

Transactions are a **coordination mechanism** between concurrent processes. They allow multiple agents to write to the same database without corrupting each other's work. The cost is lock contention. The alternative (eventual consistency) shifts the burden to application code, which must handle conflicts manually.

## MCP and agent perspective

Agents that write to the database should use transactions with a timeout:

```sql
SET lock_timeout = '5s';
SET statement_timeout = '30s';
BEGIN;
-- ... agent writes ...
COMMIT;
```

If the agent hangs or crashes, PostgreSQL's `idle_in_transaction_session_timeout` (set in postgresql.conf or per-role) will automatically roll back and release locks. Configure this to prevent orphaned transactions from blocking the system.

## Ontology perspective

- A transaction is a **unit of work** — the smallest indivisible change to the database.
- ACID is a **specification** — transactions are the mechanism that implements it.
- COMMIT is a **decision point** — before COMMIT, all changes are tentative. After, they are permanent.
- MVCC is an **implementation strategy** — one of several ways to achieve transaction isolation without locking reads.

## Practice session

`practice/beginner/06-simple-transactions/` — exercises cover successful transfers, deliberate rollback, SAVEPOINT, and what happens to uncommitted changes.

## References

| Resource | URL | Why |
|----------|-----|-----|
| PostgreSQL docs — Transactions | https://www.postgresql.org/docs/current/tutorial-transactions.html | Beginner tutorial |
| PostgreSQL docs — Transaction Isolation | https://www.postgresql.org/docs/current/transaction-iso.html | ACID and isolation levels |
| PostgreSQL docs — MVCC | https://www.postgresql.org/docs/current/mvcc-intro.html | How PostgreSQL implements isolation |
| PostgreSQL docs — WAL | https://www.postgresql.org/docs/current/wal-intro.html | Durability mechanism |
