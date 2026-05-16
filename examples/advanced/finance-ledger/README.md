# Finance Ledger Example

Level: Advanced
Domain: Append-only double-entry ledger with window functions and SERIALIZABLE isolation
Synthetic data: Yes — no financial advice, no real account numbers

## Overview

An append-only financial ledger for a fictional company called "Ironclad Books".
All values are synthetic. This example demonstrates:

- **Append-only enforcement** — a trigger raises an exception on any UPDATE or
  DELETE on `ledger_entries`, making the ledger tamper-evident.
- **Double-entry bookkeeping** — every transaction creates two entries (debit one
  account, credit another) inside a single database transaction.
- **Running balance** — window functions compute balance over time without
  materialising a separate balance column.
- **SERIALIZABLE isolation** — prevents phantom reads and write-skew during
  concurrent transfers.

> Disclaimer: this example uses entirely synthetic data and is for database
> learning purposes only. Nothing in this example constitutes financial advice.

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

CREATE TABLE accounts (
    id       SERIAL PRIMARY KEY,
    name     TEXT           NOT NULL UNIQUE,
    type     TEXT           NOT NULL CHECK (type IN ('asset','liability','equity','revenue','expense')),
    balance  NUMERIC(15,2)  NOT NULL DEFAULT 0
    -- Note: balance here is a denormalised cache; the source of truth is ledger_entries.
    -- In a strict append-only system you would compute balance from ledger_entries alone.
);

CREATE TABLE ledger_entries (
    id          BIGSERIAL PRIMARY KEY,
    account_id  INT            NOT NULL REFERENCES accounts(id),
    amount      NUMERIC(15,2)  NOT NULL CHECK (amount > 0),   -- always positive
    direction   TEXT           NOT NULL CHECK (direction IN ('debit','credit')),
    description TEXT           NOT NULL DEFAULT '',
    ref_id      TEXT,           -- optional reference to an external transaction ID
    created_at  TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ledger_account_id  ON ledger_entries (account_id);
CREATE INDEX idx_ledger_created_at  ON ledger_entries (created_at);

-- Append-only enforcement: block UPDATE and DELETE on ledger_entries
CREATE OR REPLACE FUNCTION fn_ledger_immutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION
        'ledger_entries is append-only: % is not permitted on this table', TG_OP;
END;
$$;

CREATE TRIGGER trg_ledger_immutable
BEFORE UPDATE OR DELETE ON ledger_entries
FOR EACH ROW EXECUTE FUNCTION fn_ledger_immutable();
```

## Seed data

```sql
-- Chart of accounts (synthetic)
INSERT INTO accounts (name, type, balance) VALUES
  ('Cash',                 'asset',     50000.00),
  ('Accounts Receivable',  'asset',      8500.00),
  ('Inventory',            'asset',     12000.00),
  ('Accounts Payable',     'liability',  6000.00),
  ('Retained Earnings',    'equity',    64500.00),
  ('Revenue',              'revenue',       0.00),
  ('Cost of Goods Sold',   'expense',       0.00),
  ('Operating Expenses',   'expense',       0.00);

-- Historical ledger entries (synthetic transactions)
-- Transaction 1: Client payment received — debit Cash, credit Revenue
INSERT INTO ledger_entries (account_id, amount, direction, description, ref_id, created_at)
VALUES
  (1, 3500.00, 'debit',  'Client payment: invoice INV-1001', 'TXN-001', NOW() - INTERVAL '30 days'),
  (6, 3500.00, 'credit', 'Client payment: invoice INV-1001', 'TXN-001', NOW() - INTERVAL '30 days');

-- Transaction 2: Supplier invoice paid — debit Accounts Payable, credit Cash
INSERT INTO ledger_entries (account_id, amount, direction, description, ref_id, created_at)
VALUES
  (4, 2000.00, 'debit',  'Supplier payment: Acme Supplies', 'TXN-002', NOW() - INTERVAL '25 days'),
  (1, 2000.00, 'credit', 'Supplier payment: Acme Supplies', 'TXN-002', NOW() - INTERVAL '25 days');

-- Transaction 3: Operating expense — debit Expenses, credit Cash
INSERT INTO ledger_entries (account_id, amount, direction, description, ref_id, created_at)
VALUES
  (8, 750.00,  'debit',  'Office supplies purchase', 'TXN-003', NOW() - INTERVAL '20 days'),
  (1, 750.00,  'credit', 'Office supplies purchase', 'TXN-003', NOW() - INTERVAL '20 days');

-- Transaction 4: Inventory purchase — debit Inventory, credit Cash
INSERT INTO ledger_entries (account_id, amount, direction, description, ref_id, created_at)
VALUES
  (3, 5000.00, 'debit',  'Inventory restock: batch B-0042', 'TXN-004', NOW() - INTERVAL '15 days'),
  (1, 5000.00, 'credit', 'Inventory restock: batch B-0042', 'TXN-004', NOW() - INTERVAL '15 days');

-- Transaction 5: Revenue from product sale
INSERT INTO ledger_entries (account_id, amount, direction, description, ref_id, created_at)
VALUES
  (1, 4200.00, 'debit',  'Product sale: order ORD-2001', 'TXN-005', NOW() - INTERVAL '5 days'),
  (6, 4200.00, 'credit', 'Product sale: order ORD-2001', 'TXN-005', NOW() - INTERVAL '5 days');

-- Transaction 6: COGS recognition
INSERT INTO ledger_entries (account_id, amount, direction, description, ref_id, created_at)
VALUES
  (7, 2100.00, 'debit',  'COGS: order ORD-2001', 'TXN-006', NOW() - INTERVAL '5 days'),
  (3, 2100.00, 'credit', 'COGS: order ORD-2001', 'TXN-006', NOW() - INTERVAL '5 days');
```

## Example queries

### Running balance for an account (window function)

```sql
-- Running balance for the Cash account (id=1)
-- Assets: debit increases balance, credit decreases balance
SELECT id,
       description,
       created_at::DATE             AS date,
       CASE direction
           WHEN 'debit'  THEN  amount
           WHEN 'credit' THEN -amount
       END                          AS signed_amount,
       SUM(
           CASE direction
               WHEN 'debit'  THEN  amount
               WHEN 'credit' THEN -amount
           END
       ) OVER (ORDER BY created_at, id)   AS running_balance
FROM   ledger_entries
WHERE  account_id = 1
ORDER  BY created_at, id;
```

### Current balance per account (derived from ledger)

```sql
SELECT a.id,
       a.name,
       a.type,
       COALESCE(
           SUM(
               CASE e.direction
                   WHEN 'debit'  THEN  e.amount
                   WHEN 'credit' THEN -e.amount
               END
           ), 0
       ) AS computed_balance
FROM   accounts       a
LEFT   JOIN ledger_entries e ON e.account_id = a.id
GROUP  BY a.id, a.name, a.type
ORDER  BY a.id;
```

### Double-entry transfer (SERIALIZABLE transaction)

```sql
-- Transfer 1000.00 from Cash (1) to Accounts Payable (4)
-- Always use SERIALIZABLE to prevent concurrent write-skew
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

  -- Debit Cash (money out of cash asset)
  INSERT INTO ledger_entries (account_id, amount, direction, description, ref_id)
  VALUES (4, 1000.00, 'debit',  'Payment to supplier: Blue Pine Ltd', 'TXN-007');

  -- Credit Cash
  INSERT INTO ledger_entries (account_id, amount, direction, description, ref_id)
  VALUES (1, 1000.00, 'credit', 'Payment to supplier: Blue Pine Ltd', 'TXN-007');

  -- Update denormalised balance cache (optional)
  UPDATE accounts SET balance = balance - 1000.00 WHERE id = 1;
  UPDATE accounts SET balance = balance - 1000.00 WHERE id = 4;

COMMIT;
```

### Prove ledger is append-only

```sql
-- These should both raise: "ledger_entries is append-only: DELETE is not permitted"

-- DELETE FROM ledger_entries WHERE id = 1;

-- UPDATE ledger_entries SET amount = 0 WHERE id = 1;
```

### Period profit and loss (revenue - expenses)

```sql
SELECT
    SUM(CASE WHEN a.type = 'revenue' AND e.direction = 'credit' THEN  e.amount
             WHEN a.type = 'revenue' AND e.direction = 'debit'  THEN -e.amount
             ELSE 0
        END)                           AS total_revenue,
    SUM(CASE WHEN a.type IN ('expense') AND e.direction = 'debit'  THEN  e.amount
             WHEN a.type IN ('expense') AND e.direction = 'credit' THEN -e.amount
             ELSE 0
        END)                           AS total_expenses,
    SUM(CASE WHEN a.type = 'revenue' AND e.direction = 'credit' THEN  e.amount
             WHEN a.type = 'revenue' AND e.direction = 'debit'  THEN -e.amount
             ELSE 0
        END)
    - SUM(CASE WHEN a.type IN ('expense') AND e.direction = 'debit'  THEN  e.amount
               WHEN a.type IN ('expense') AND e.direction = 'credit' THEN -e.amount
               ELSE 0
          END)                         AS net_income
FROM   ledger_entries e
JOIN   accounts       a ON a.id = e.account_id
WHERE  e.created_at >= DATE_TRUNC('month', NOW());  -- current month
```

### Monthly ledger volume

```sql
SELECT DATE_TRUNC('month', created_at)::DATE AS month,
       COUNT(*)                              AS entries,
       SUM(amount)                           AS gross_amount
FROM   ledger_entries
GROUP  BY DATE_TRUNC('month', created_at)
ORDER  BY month;
```

### Entries by reference ID (transaction grouping)

```sql
SELECT ref_id,
       COUNT(*)    AS entry_count,
       SUM(amount) AS total_amount,
       MIN(created_at)::DATE AS date
FROM   ledger_entries
WHERE  ref_id IS NOT NULL
GROUP  BY ref_id
ORDER  BY date;
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

SELECT COUNT(*) FROM accounts;
-- Expected: 8

SELECT COUNT(*) FROM ledger_entries;
-- Expected: 12 (6 transactions × 2 entries each)

-- Double-entry check: every ref_id should have exactly 2 entries
SELECT ref_id, COUNT(*) AS entries
FROM ledger_entries
GROUP BY ref_id
HAVING COUNT(*) <> 2;
-- Expected: 0 rows (all balanced)

-- Immutability test — should raise exception:
-- DELETE FROM ledger_entries WHERE id = 1;

-- Trigger exists
SELECT trigger_name FROM information_schema.triggers
WHERE event_object_table = 'ledger_entries';
```

## Practice tasks

1. **Add a transaction.** Record a new revenue event: debit Cash by 2500.00 and
   credit Revenue by 2500.00 in a SERIALIZABLE transaction with `ref_id = 'TXN-008'`.
   Rerun the running balance query for Cash. Does the balance increase by 2500?

2. **Prove immutability.** Attempt `UPDATE ledger_entries SET amount = 99 WHERE id = 1`.
   Document the exact error message. Then try `DELETE FROM ledger_entries LIMIT 1`.
   Why is immutability important for a ledger?

3. **Window function variants.** Modify the running balance query to also show:
   - Monthly period balance (SUM partitioned by month)
   - Entry rank within each account (ROW_NUMBER)

4. **Detect imbalance.** Write a query that groups entries by `ref_id` and returns
   any `ref_id` where the net signed amount is not zero (debits ≠ credits). Insert
   a deliberately unbalanced pair to test.

5. **SERIALIZABLE isolation experiment.** Open two psql sessions simultaneously.
   In both, begin a SERIALIZABLE transaction. Have both sessions read the Cash balance,
   then both insert a transfer. Commit both. What happens? Read about
   serialization failure (ERROR: could not serialize access due to concurrent update).

## MCP and agent perspective

An AI agent using this ledger via MCP would:

- **Only INSERT** — the append-only trigger means the agent cannot accidentally
  (or maliciously) modify or delete historical entries, even if its SQL generation
  has a bug.
- **Always double-entry** — the agent wraps every financial event in a SERIALIZABLE
  transaction with two INSERT statements, ensuring the ledger stays balanced.
- **Compute balances on demand** — rather than trusting a cached `balance` column,
  the agent can compute current balances from `ledger_entries` for any point in
  time using window functions.
- **Produce reports** — the P&L and monthly volume queries give the agent the data
  needed to answer "how much did we earn this month?" or "what was the net income
  this quarter?".
- **Audit trail** — every agent action that results in a financial entry is
  permanently recorded, providing a full history for human review.

## Teardown

```sql
DROP TRIGGER  IF EXISTS trg_ledger_immutable ON ledger_entries;
DROP FUNCTION IF EXISTS fn_ledger_immutable();
DROP TABLE    IF EXISTS ledger_entries;
DROP TABLE    IF EXISTS accounts;
```

## References

- Window Functions: https://www.postgresql.org/docs/current/tutorial-window.html
- Transaction Isolation: https://www.postgresql.org/docs/current/transaction-iso.html
- SERIALIZABLE Isolation: https://www.postgresql.org/docs/current/transaction-iso.html#XACT-SERIALIZABLE
- Double-Entry Bookkeeping: https://en.wikipedia.org/wiki/Double-entry_bookkeeping
