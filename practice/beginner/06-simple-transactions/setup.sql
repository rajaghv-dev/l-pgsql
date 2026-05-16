-- Practice: Simple Transactions
-- Level: Beginner
-- Session: 06-simple-transactions
-- blocked: Docker not accessible; validate against cfp_postgres

-- ---------------------------------------------------------------
-- Clean slate
-- ---------------------------------------------------------------
DROP TABLE IF EXISTS bank_accounts;

-- ---------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------
CREATE TABLE bank_accounts (
    id      SERIAL PRIMARY KEY,
    owner   TEXT        NOT NULL,
    balance NUMERIC(12, 2) NOT NULL CHECK (balance >= 0)
);

-- ---------------------------------------------------------------
-- Seed: 3 synthetic accounts
-- ---------------------------------------------------------------
INSERT INTO bank_accounts (owner, balance) VALUES
    ('Alice',   1000.00),
    ('Bob',      500.00),
    ('Charlie',  250.00);

-- ---------------------------------------------------------------
-- Verify
-- ---------------------------------------------------------------
SELECT id, owner, balance FROM bank_accounts ORDER BY id;

-- ---------------------------------------------------------------
-- Demo 1: successful transfer (Alice -> Bob, $200)
-- ---------------------------------------------------------------
BEGIN;
    UPDATE bank_accounts SET balance = balance - 200 WHERE owner = 'Alice';
    UPDATE bank_accounts SET balance = balance + 200 WHERE owner = 'Bob';
COMMIT;

SELECT id, owner, balance FROM bank_accounts ORDER BY id;

-- ---------------------------------------------------------------
-- Demo 2: rolled-back transfer (Bob -> Charlie, $999 — exceeds balance)
-- The CHECK constraint on balance >= 0 fires and the whole block rolls back.
-- ---------------------------------------------------------------
BEGIN;
    UPDATE bank_accounts SET balance = balance - 999 WHERE owner = 'Bob';
    -- This next statement would violate the CHECK; PostgreSQL aborts the tx.
    UPDATE bank_accounts SET balance = balance + 999 WHERE owner = 'Charlie';
ROLLBACK;  -- explicit rollback shown; in practice the error aborts automatically

SELECT id, owner, balance FROM bank_accounts ORDER BY id;
