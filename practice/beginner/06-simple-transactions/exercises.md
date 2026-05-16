# Exercises: Simple Transactions

Level: Beginner

Work through each exercise in order. Do not look at `solutions.md` until you have tried.

Note: After each exercise, re-run `setup.sql` to reset balances to the post-demo state (Alice 800, Bob 700, Charlie 250) before the next exercise.

---

## Exercise 1: Successful Transfer (BEGIN/COMMIT)

**Goal:** Transfer $150 from Alice to Bob using an explicit transaction.

**First-principles question:** What would happen if the database crashed between the two UPDATE statements without a transaction?

**Task:**
1. Check current balances.
2. Begin a transaction.
3. Deduct $150 from Alice.
4. Add $150 to Bob.
5. Commit.
6. Verify balances changed correctly.

**Your SQL:**
```sql
-- Step 1: Check current balances
SELECT id, owner, balance FROM bank_accounts ORDER BY id;

-- Step 2-5: The transfer
BEGIN;

UPDATE bank_accounts
SET balance = balance - 150
WHERE owner = 'Alice';

UPDATE bank_accounts
SET balance = balance + 150
WHERE owner = 'Bob';

COMMIT;

-- Step 6: Verify
SELECT id, owner, balance FROM bank_accounts ORDER BY id;
```

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  BEGIN;
  UPDATE bank_accounts SET balance = balance - 150 WHERE owner = 'Alice';
  UPDATE bank_accounts SET balance = balance + 150 WHERE owner = 'Bob';
  COMMIT;
  SELECT id, owner, balance FROM bank_accounts ORDER BY id;
"
```

**Expected result after commit:**
```
 id |  owner  | balance
----+---------+---------
  1 | Alice   |  650.00
  2 | Bob     |  850.00
  3 | Charlie |  250.00
```

**Critical-thinking question:** Is a single UPDATE statement also a transaction? (Yes — every statement is implicitly wrapped in a transaction in auto-commit mode. What does this imply about statement-level atomicity?)

**Ontology-thinking question:** COMMIT is a "decision point" — before it, changes are tentative. What data structure does PostgreSQL use to store tentative changes? (Hint: WAL)

**Agent/MCP angle:**
- Agent scenario: A payment processing agent debits a payer and credits a payee.
- MCP tool name: `transfer_funds`
- Tool input: `{ "from": "Alice", "to": "Bob", "amount": 150.00 }`
- PostgreSQL operation: The BEGIN/COMMIT block above, parameterized.
- Required permission: `UPDATE` on `bank_accounts` for the agent role.
- Validation before execution: Verify `from.balance >= amount` before running UPDATEs.
- Audit log entry: INSERT into a `transfer_log` table inside the same transaction.
- Human approval needed: Yes — for amounts > $1000.
- Failure mode: Application crash after first UPDATE but before COMMIT → PostgreSQL rolls back automatically.
- Ontology connection: `[[transaction]]` → `[[atomicity]]` → `[[commit]]`

**What this teaches:** BEGIN/COMMIT groups multiple statements into one atomic unit — all succeed or all fail.

---

## Exercise 2: Explicit Rollback

**Goal:** Start a transaction, make changes, then roll back — observe that the database is unchanged.

**First-principles question:** Why would you want to roll back a transaction you started intentionally? (Think about: constraint violations discovered mid-way, validation failures, user cancellations.)

**Task:**
1. Check balances.
2. Begin a transaction.
3. Delete Charlie's account.
4. Verify Charlie is gone (inside the transaction — only you can see this).
5. Rollback.
6. Verify Charlie is back.

**Your SQL:**
```sql
BEGIN;

DELETE FROM bank_accounts WHERE owner = 'Charlie';

-- Inside the transaction, Charlie is gone:
SELECT COUNT(*) FROM bank_accounts WHERE owner = 'Charlie';  -- Returns 0

ROLLBACK;

-- After rollback, Charlie is back:
SELECT COUNT(*) FROM bank_accounts WHERE owner = 'Charlie';  -- Returns 1
```

**Commands:**
```bash
# Note: psql -c sends one command. For multi-statement transactions,
# use a here-doc or a SQL file. This is a common gotcha.

docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
BEGIN;
DELETE FROM bank_accounts WHERE owner = 'Charlie';
SELECT owner, 'sees Charlie?' AS check FROM bank_accounts WHERE owner = 'Charlie';
ROLLBACK;
SELECT owner, balance FROM bank_accounts ORDER BY id;
EOF
```

**Expected result after rollback:**
```
 id |  owner  | balance
----+---------+---------
  1 | Alice   |  800.00
  2 | Bob     |  700.00
  3 | Charlie |  250.00
```

Charlie is restored exactly as before.

**Critical-thinking question:** What would happen if you closed the psql session (Ctrl+D) in the middle of a transaction without COMMITting or ROLLBACKing? PostgreSQL automatically rolls back the transaction when the connection closes.

**Systems-thinking question:** Long transactions that are rolled back still generated WAL (Write-Ahead Log) entries. Why might frequent large rollbacks be costly even though the data ends up unchanged?

**What this teaches:** ROLLBACK undoes all changes since BEGIN. The database returns to its pre-BEGIN state exactly.

---

## Exercise 3: SAVEPOINT — Partial Rollback

**Goal:** Use SAVEPOINT to undo only part of a transaction while keeping other changes.

**First-principles question:** If ROLLBACK undoes everything, why do we need SAVEPOINT? What use case requires partial undo within a single transaction?

**Task:**
1. Begin a transaction.
2. Transfer $50 from Alice to Bob (step 1 — keep this).
3. Create a SAVEPOINT.
4. Attempt to overdraw Charlie (step 2 — undo this).
5. ROLLBACK TO SAVEPOINT.
6. Verify: step 1 changes are still present, step 2 is undone.
7. COMMIT.

**Your SQL:**
```sql
BEGIN;

-- Step 1: Transfer Alice → Bob ($50) — we want to keep this
UPDATE bank_accounts SET balance = balance - 50 WHERE owner = 'Alice';
UPDATE bank_accounts SET balance = balance + 50 WHERE owner = 'Bob';

-- Create a savepoint before the risky operation
SAVEPOINT before_charlie;

-- Step 2: Attempt to overdraw Charlie ($1000 from $250) — we will undo this
UPDATE bank_accounts SET balance = balance - 1000 WHERE owner = 'Charlie';
-- This succeeds as a statement but violates business rules (balance goes negative)
-- NOTE: the CHECK constraint prevents balance < 0, so this will raise an error
-- After an error, the transaction is aborted — you must ROLLBACK TO SAVEPOINT or ROLLBACK

ROLLBACK TO SAVEPOINT before_charlie;

-- Step 1 changes are still here; step 2 is undone:
SELECT owner, balance FROM bank_accounts ORDER BY id;

COMMIT;
```

**Command (using a file):**
```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
BEGIN;
UPDATE bank_accounts SET balance = balance - 50 WHERE owner = 'Alice';
UPDATE bank_accounts SET balance = balance + 50 WHERE owner = 'Bob';
SAVEPOINT before_charlie;
UPDATE bank_accounts SET balance = balance - 1000 WHERE owner = 'Charlie';
ROLLBACK TO SAVEPOINT before_charlie;
SELECT owner, balance FROM bank_accounts ORDER BY id;
COMMIT;
EOF
```

**Expected result (after ROLLBACK TO SAVEPOINT, before COMMIT):**
```
 id |  owner  | balance
----+---------+---------
  1 | Alice   |  750.00   ← step 1 applied (800 - 50)
  2 | Bob     |  750.00   ← step 1 applied (700 + 50)
  3 | Charlie |  250.00   ← unchanged (step 2 rolled back)
```

**Critical-thinking question:** In exercise 3, the CHECK constraint fires when Charlie's balance would go negative. After a constraint error, the transaction is automatically in an "aborted" state — you cannot run any more statements except ROLLBACK or ROLLBACK TO SAVEPOINT. Why does PostgreSQL abort the transaction on error instead of allowing the next statement to continue?

**Creative-thinking question:** SAVEPOINTs are useful in ORMs when processing a batch of records: process each item in a loop, SAVEPOINT before each, ROLLBACK TO SAVEPOINT on per-item failure, RELEASE SAVEPOINT on success. How would you implement a batch import with SAVEPOINT-based per-row error recovery?

**Systems-thinking question:** SAVEPOINTs generate WAL entries. Each ROLLBACK TO SAVEPOINT must undo those entries. For large batches with many SAVEPOINTs, is this approach still efficient? (Hint: compare with separate transactions per item.)

**Ontology-thinking question:** A SAVEPOINT is a named point in the transaction's history. Is a transaction a sequence or a tree? (If you create multiple SAVEPOINTs with the same name, what happens?)

**What this teaches:** SAVEPOINTs allow nested "undo points" within a transaction — useful when batch operations need per-item error recovery without aborting the entire transaction.

---

## Exercise 4: Observe Uncommitted Changes from Another Session

**Goal:** See how transaction isolation prevents one session from seeing another session's uncommitted changes.

**First-principles question:** PostgreSQL defaults to READ COMMITTED isolation. What does this mean for what one session can see from another session's uncommitted work?

**Task:** This exercise requires two terminal windows (two separate psql sessions).

**Terminal A (session 1):**
```bash
docker exec -it cfp_postgres psql -U cfp -d cfp
```
```sql
BEGIN;
UPDATE bank_accounts SET balance = balance + 9999 WHERE owner = 'Alice';
-- DO NOT COMMIT YET
SELECT balance FROM bank_accounts WHERE owner = 'Alice';
-- You see: 9799.00 (800 + 9999)
```

**Terminal B (session 2) — while session 1 is still open and uncommitted:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT balance FROM bank_accounts WHERE owner = 'Alice';
"
-- You see: 800.00 (original value — session 1's change is not yet committed)
```

**Terminal A — now commit:**
```sql
COMMIT;
```

**Terminal B — query again:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT balance FROM bank_accounts WHERE owner = 'Alice';
"
-- You now see: 9799.00 (committed, now visible to all sessions)
```

**Critical-thinking question:** Under READ COMMITTED, session B sees Alice's old balance until session A commits. Under SERIALIZABLE isolation, session B's transaction would see the balance as of its own start time throughout, even after session A commits. What application scenario would require SERIALIZABLE instead of READ COMMITTED?

**Systems-thinking question:** This exercise demonstrates why "read your own writes" is not guaranteed across sessions. If session B opens a long-running report and session A commits a change during the report, what does session B see? (Under READ COMMITTED: it sees the committed change if it re-reads the same row. Under REPEATABLE READ or SERIALIZABLE: it sees the original value for the entire transaction.)

**What this teaches:** PostgreSQL's default READ COMMITTED isolation means committed changes from other sessions are visible immediately. Uncommitted changes are never visible across sessions.

---

## Exercise 5 (stretch): Transaction with RETURNING

**Goal:** Use RETURNING inside a transaction to capture the ID of a newly inserted row, then use that ID in a subsequent statement.

**Difficulty:** Stretch — only attempt after completing exercises 1–4.

**Task:** Insert a new account and immediately insert a transfer record to that new account, all in one transaction. Use RETURNING to capture the new account's ID.

```sql
BEGIN;

-- Insert new account and capture the generated ID
INSERT INTO bank_accounts (owner, balance) VALUES ('Dave', 0.00)
RETURNING id;

-- In a real application, use the returned ID in the next statement.
-- In psql, you can use a CTE:
WITH new_account AS (
    INSERT INTO bank_accounts (owner, balance) VALUES ('Eve', 0.00)
    RETURNING id
)
UPDATE bank_accounts
SET balance = balance - 50
WHERE id = (SELECT id FROM new_account);

ROLLBACK;  -- Undo so we don't leave test data
```

**What this teaches:** RETURNING turns INSERT into a write + read in one statement. Combined with CTEs, it enables chained writes in a single atomic block.
