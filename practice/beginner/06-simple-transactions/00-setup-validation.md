# Setup Validation: Simple Transactions

Run each check after executing `setup.sql`. All checks must pass before starting exercises.

Note: `setup.sql` also runs two demo transactions (a successful transfer and a rolled-back transfer), so balances after setup are different from the initial seed values.

---

## Check 1: Table exists

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT table_name FROM information_schema.tables
  WHERE table_schema = 'public' AND table_name = 'bank_accounts';
"
```

**Expected output:**
```
  table_name
-------------
 bank_accounts
(1 row)
```

**Ontology note:** `bank_accounts` is a relation. Each row is a tuple. The balance column has a CHECK constraint — a relational integrity rule. `[[table]]` → `[[constraint]]` → `[[transaction]]`

---

## Check 2: Row count and final balances

After setup.sql runs, the demo transfer (Alice → Bob, $200) was committed. Charlie's balance is unchanged (the Bob → Charlie demo was rolled back).

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT id, owner, balance FROM bank_accounts ORDER BY id;
"
```

**Expected output:**
```
 id |  owner  | balance
----+---------+---------
  1 | Alice   |  800.00
  2 | Bob     |  700.00
  3 | Charlie |  250.00
(3 rows)
```

Alice: 1000 - 200 = 800. Bob: 500 + 200 = 700. Charlie: 250 (rollback means no change).

**Common error:** Balances differ — setup.sql may have partially run. Re-run it (it drops and recreates the table).

---

## Check 3: CHECK constraint is active

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  UPDATE bank_accounts SET balance = -1 WHERE id = 1;
"
```

**Expected output:**
```
ERROR:  new row for relation "bank_accounts" violates check constraint "bank_accounts_balance_check"
DETAIL:  Failing row contains (1, Alice, -1.00).
```

**Why this exists:** The CHECK constraint prevents negative balances. Transactions that would violate this constraint are automatically rolled back.

---

## Setup passed

If all checks show expected output, setup is complete.
Open `exercises.md` and begin.
