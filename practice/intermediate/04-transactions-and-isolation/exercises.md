# Exercises — Transactions and Isolation Levels

**Status: blocked — Docker not accessible in this session**
All SQL below is correct and ready to run when Docker is available.

---

## Exercise 1: Basic transaction lifecycle

Run this in Session A. Observe that changes are invisible in Session B until COMMIT.

**Session A:**
```sql
-- blocked: Docker not accessible
BEGIN;
UPDATE bank_accounts SET balance = balance - 100 WHERE owner = 'Alice';
SELECT owner, balance FROM bank_accounts WHERE owner = 'Alice';
-- Alice shows 900.00 in Session A
```

**Session B (before Session A commits):**
```sql
-- blocked: Docker not accessible
SELECT owner, balance FROM bank_accounts WHERE owner = 'Alice';
-- With READ COMMITTED: still shows 1000.00 (original committed value)
```

**Session A:**
```sql
-- blocked: Docker not accessible
COMMIT;
```

**Session B (after COMMIT):**
```sql
-- blocked: Docker not accessible
SELECT owner, balance FROM bank_accounts WHERE owner = 'Alice';
-- Now shows 900.00
```

**Question:** What isolation level was Session B using? Why did it see 1000.00 before the commit?

---

## Exercise 2: Non-repeatable read in READ COMMITTED

Demonstrate that READ COMMITTED allows non-repeatable reads.

**Session B:**
```sql
-- blocked: Docker not accessible
-- Default READ COMMITTED
BEGIN;
SELECT balance FROM bank_accounts WHERE owner = 'Bob';
-- Returns 500.00
```

**Session A (between Session B's two reads):**
```sql
-- blocked: Docker not accessible
BEGIN;
UPDATE bank_accounts SET balance = balance + 200 WHERE owner = 'Bob';
COMMIT;
```

**Session B (second read, still in same transaction):**
```sql
-- blocked: Docker not accessible
SELECT balance FROM bank_accounts WHERE owner = 'Bob';
-- Returns 700.00 -- NON-REPEATABLE READ: different value in same transaction
COMMIT;
```

---

## Exercise 3: Phantom read — READ COMMITTED vs SERIALIZABLE

**READ COMMITTED allows phantom reads:**

**Session B:**
```sql
-- blocked: Docker not accessible
BEGIN; -- READ COMMITTED (default)
SELECT COUNT(*) FROM bank_accounts WHERE balance > 600;
-- Returns 2 (Charlie 2500, Diana 750)
```

**Session A:**
```sql
-- blocked: Docker not accessible
INSERT INTO bank_accounts (owner, balance) VALUES ('Frank', 800.00);
COMMIT;
```

**Session B (second count, same transaction):**
```sql
-- blocked: Docker not accessible
SELECT COUNT(*) FROM bank_accounts WHERE balance > 600;
-- Returns 3 -- PHANTOM ROW appeared
COMMIT;
```

**SERIALIZABLE prevents this:**

```sql
-- blocked: Docker not accessible
-- Session B:
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) FROM bank_accounts WHERE balance > 600;

-- Session A concurrently inserts Frank (as above)

-- Session B second read:
SELECT COUNT(*) FROM bank_accounts WHERE balance > 600;
-- Still returns 2 -- snapshot is frozen at transaction start
-- OR: transaction is aborted with ERROR 40001 if write skew detected
COMMIT;
```

---

## Exercise 4: SAVEPOINT — partial rollback

```sql
-- blocked: Docker not accessible
BEGIN;

UPDATE bank_accounts SET balance = balance - 50 WHERE owner = 'Alice';
SAVEPOINT after_alice;

UPDATE bank_accounts SET balance = balance - 50 WHERE owner = 'Bob';

-- Something goes wrong for Bob's step
ROLLBACK TO SAVEPOINT after_alice;

-- Only Alice's deduction remains
SELECT owner, balance FROM bank_accounts WHERE owner IN ('Alice', 'Bob');
-- Alice: 950.00, Bob: 500.00 (Bob's deduction rolled back)

COMMIT;
```

---

## Exercise 5: Transfer — correct isolation pattern

A correct transfer that avoids lost-update and balance errors:

```sql
-- blocked: Docker not accessible
BEGIN ISOLATION LEVEL REPEATABLE READ;

-- Lock both rows in consistent order (always low id first to prevent deadlock)
SELECT id, balance FROM bank_accounts WHERE id IN (1, 2) ORDER BY id FOR UPDATE;

-- Check sufficiency
-- (application layer verifies balance >= amount)

UPDATE bank_accounts SET balance = balance - 200 WHERE id = 1;
UPDATE bank_accounts SET balance = balance + 200 WHERE id = 2;

INSERT INTO transfers (from_id, to_id, amount, note)
VALUES (1, 2, 200.00, 'exercise 5 transfer');

COMMIT;
```

---

## Exercise 6: SET TRANSACTION syntax options

```sql
-- blocked: Docker not accessible

-- Option 1: BEGIN with isolation level
BEGIN ISOLATION LEVEL SERIALIZABLE;

-- Option 2: SET TRANSACTION after BEGIN
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SET TRANSACTION READ ONLY; -- prevents any writes

-- Option 3: READ ONLY transaction (safe for reporting)
BEGIN TRANSACTION READ ONLY;
SELECT SUM(balance) FROM bank_accounts;
COMMIT;
```

---

## Reflection questions
1. Why does PostgreSQL's REPEATABLE READ also prevent phantom reads, when the SQL standard says it shouldn't?
2. When would you choose READ COMMITTED over SERIALIZABLE for a transfer operation?
3. What happens if a SERIALIZABLE transaction fails with ERROR 40001? What must your application do?
4. Why should all transfers lock accounts in a consistent key order?
