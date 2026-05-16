# Solutions: Simple Transactions

Level: Beginner

Read `exercises.md` and attempt the exercises before opening this file.

---

## Solution: Exercise 1 — Successful Transfer

```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
BEGIN;
UPDATE bank_accounts SET balance = balance - 150 WHERE owner = 'Alice';
UPDATE bank_accounts SET balance = balance + 150 WHERE owner = 'Bob';
COMMIT;
SELECT id, owner, balance FROM bank_accounts ORDER BY id;
EOF
```

**Output:**
```
 id |  owner  | balance
----+---------+---------
  1 | Alice   |  650.00
  2 | Bob     |  850.00
  3 | Charlie |  250.00
```

**Why this works:** BEGIN starts a transaction block. Both UPDATEs run in the same transaction. COMMIT makes both permanent simultaneously. If the database crashed between the two UPDATEs, PostgreSQL would replay WAL on recovery and determine the transaction was not committed — it would roll back both UPDATEs automatically.

**Key learning:** All statements between BEGIN and COMMIT are one atomic unit. The intermediate state (Alice deducted but Bob not yet credited) is never visible to other sessions and never persists on crash.

---

## Solution: Exercise 2 — Explicit Rollback

```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
BEGIN;
DELETE FROM bank_accounts WHERE owner = 'Charlie';
SELECT 'inside transaction: ' || COUNT(*)::text || ' Charlies' FROM bank_accounts WHERE owner = 'Charlie';
ROLLBACK;
SELECT 'after rollback: ' || COUNT(*)::text || ' Charlies' FROM bank_accounts WHERE owner = 'Charlie';
SELECT id, owner, balance FROM bank_accounts ORDER BY id;
EOF
```

**Output:**
```
           ?column?
-------------------------------
 inside transaction: 0 Charlies

           ?column?
-------------------------------
 after rollback: 1 Charlies

 id |  owner  | balance
----+---------+---------
  1 | Alice   |  800.00
  2 | Bob     |  700.00
  3 | Charlie |  250.00
```

**Why this works:** Inside the transaction, the DELETE is visible to the same session (you see 0 Charlies). But the transaction was rolled back — Charlie is fully restored. ROLLBACK is as if BEGIN never happened.

**Key learning:** ROLLBACK is a complete undo. The database state after ROLLBACK is identical to the state before BEGIN.

---

## Solution: Exercise 3 — SAVEPOINT

```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
BEGIN;
-- Step 1: keep
UPDATE bank_accounts SET balance = balance - 50 WHERE owner = 'Alice';
UPDATE bank_accounts SET balance = balance + 50 WHERE owner = 'Bob';

-- Create savepoint
SAVEPOINT before_charlie;

-- Step 2: undo
UPDATE bank_accounts SET balance = balance - 1000 WHERE owner = 'Charlie';
-- Error fires: CHECK constraint (balance cannot go below 0)
-- After the error, the transaction is in an aborted state.
-- ROLLBACK TO SAVEPOINT restores to the savepoint and clears the aborted state.

ROLLBACK TO SAVEPOINT before_charlie;

-- Verify: step 1 kept, step 2 undone
SELECT owner, balance FROM bank_accounts ORDER BY id;

COMMIT;
EOF
```

**Output (after ROLLBACK TO SAVEPOINT):**
```
  owner  | balance
---------+---------
 Alice   |  750.00
 Bob     |  750.00
 Charlie |  250.00
```

**Why this works:** SAVEPOINT records the transaction state at a named point. ROLLBACK TO SAVEPOINT undoes all changes made after the savepoint — but leaves changes before the savepoint intact. COMMIT makes the remaining changes permanent.

**Key learning:** SAVEPOINTs enable partial undo within a transaction. After a constraint error, you MUST ROLLBACK TO a savepoint (or ROLLBACK entirely) before the transaction can continue.

---

## Solution: Exercise 4 — Isolation Levels

This exercise requires two terminal sessions and cannot be run in a single bash command.

**Summary of expected behavior:**

Under the default READ COMMITTED isolation:
- Session A starts a transaction and updates Alice's balance to 9799.
- Session B queries Alice's balance: sees **800** (original, uncommitted change is invisible).
- Session A commits.
- Session B queries again: sees **9799** (now committed, visible to all).

**Key learning:** READ COMMITTED means "only committed data is readable." Uncommitted changes in one session are invisible to all other sessions. After COMMIT, the change is immediately visible to new reads in other sessions.

**Why this matters:** Under REPEATABLE READ or SERIALIZABLE, session B's transaction would see Alice's balance as 800 for its entire duration, even after session A commits. This prevents "non-repeatable reads" — the same query returns different results within one transaction. Use REPEATABLE READ when you need consistent reads across multiple queries in one transaction (e.g., a report that reads the same table multiple times).

---

## Solution: Exercise 5 (stretch) — RETURNING in a Transaction

```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
BEGIN;

-- Insert new account and immediately use the ID in a CTE
WITH new_account AS (
    INSERT INTO bank_accounts (owner, balance)
    VALUES ('Dave', 100.00)
    RETURNING id, owner, balance
)
SELECT id, owner, balance FROM new_account;

-- Confirm Dave now exists
SELECT id, owner, balance FROM bank_accounts WHERE owner = 'Dave';

ROLLBACK;  -- Undo test data

-- Confirm Dave is gone after rollback
SELECT COUNT(*) AS dave_count FROM bank_accounts WHERE owner = 'Dave';
EOF
```

**Key learning:** RETURNING makes INSERT a write + read in one statement, eliminating the need for a follow-up SELECT. CTEs with RETURNING allow chaining writes and reads atomically. The ROLLBACK demonstrates that even with RETURNING data returned to the application, the database change can still be fully undone.
