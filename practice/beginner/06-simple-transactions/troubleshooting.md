# Troubleshooting: Simple Transactions

Common errors encountered in this practice session and how to fix them.

---

## Error 1: `ERROR: current transaction is aborted, commands ignored until end of transaction block`

**Trigger:** Attempting to run any SQL after a statement inside a transaction caused an error (e.g., constraint violation).

**Cause:** PostgreSQL transitions the transaction to an "aborted" state after any error. In this state, it refuses to execute any further statements except ROLLBACK or ROLLBACK TO SAVEPOINT.

**Fix:**
```bash
# Option A: Roll back the entire transaction
docker exec cfp_postgres psql -U cfp -d cfp -c "ROLLBACK;"

# Option B: Roll back to a savepoint (if you created one before the error)
docker exec cfp_postgres psql -U cfp -d cfp -c "ROLLBACK TO SAVEPOINT before_charlie;"
```

**Prevention:** Create SAVEPOINTs before risky operations. Handle errors in application code and issue ROLLBACK TO SAVEPOINT or ROLLBACK before retrying.

---

## Error 2: `ERROR: new row for relation "bank_accounts" violates check constraint "bank_accounts_balance_check"`

**Trigger:** Running an UPDATE that would make `balance < 0`.

**Cause:** The CHECK constraint `balance >= 0` prevents negative balances.

**Fix:** Check that the deduction amount does not exceed the current balance before running the UPDATE:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT balance FROM bank_accounts WHERE owner = 'Charlie';
  -- If balance < transfer amount, do not proceed
"
```

**Prevention in application code:**
```sql
-- Use a CTE to verify balance before deducting
WITH check_balance AS (
    SELECT balance FROM bank_accounts WHERE owner = 'Charlie' FOR UPDATE
)
UPDATE bank_accounts
SET balance = balance - 100
WHERE owner = 'Charlie'
  AND (SELECT balance FROM check_balance) >= 100;
-- If 0 rows updated, insufficient funds
```

---

## Error 3: Silent failure — transaction appears to commit but changes are lost

**Symptom:** You run BEGIN, UPDATE, COMMIT in separate `psql -c` calls and the changes do not persist.

**Cause:** Each `psql -c` call opens a new connection. BEGIN in one call, COMMIT in another, are NOT the same transaction — each command gets its own auto-committed transaction.

**Trigger:**
```bash
# WRONG — three separate connections, three separate transactions
docker exec cfp_postgres psql -U cfp -d cfp -c "BEGIN;"
docker exec cfp_postgres psql -U cfp -d cfp -c "UPDATE bank_accounts SET balance = 9999 WHERE owner = 'Alice';"
docker exec cfp_postgres psql -U cfp -d cfp -c "COMMIT;"
```
The UPDATE in the middle is auto-committed immediately (the BEGIN and COMMIT are no-ops in separate connections).

**Fix:** Use a heredoc to send all statements over one connection:
```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
BEGIN;
UPDATE bank_accounts SET balance = 9999 WHERE owner = 'Alice';
COMMIT;
EOF
```

Or use a SQL file:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -f /path/to/transfer.sql
```

---

## Error 4: `idle in transaction` — session is stuck

**Symptom:** You started a transaction with BEGIN in an interactive psql session and closed the terminal without committing or rolling back. The next time you connect, you see a warning about existing locks.

**Diagnosis:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT pid, state, query, now() - query_start AS idle_duration
  FROM pg_stat_activity
  WHERE state = 'idle in transaction';
"
```

**Fix:** Terminate the idle transaction:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT pg_terminate_backend(pid)
  FROM pg_stat_activity
  WHERE state = 'idle in transaction'
    AND query_start < now() - INTERVAL '5 minutes';
"
```

**Prevention:** Set `idle_in_transaction_session_timeout` in `postgresql.conf` (e.g., `= '5min'`) to automatically terminate idle transactions.

---

## Setup troubleshooting

**Problem:** Balances are not what you expect — previous exercise changed them
**Fix:** Re-run setup.sql to reset to the demo-post state (Alice 800, Bob 700, Charlie 250):
```bash
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/06-simple-transactions/setup.sql
```

**Problem:** Container is not running
**Fix:**
```bash
docker ps | grep cfp_postgres
docker compose -f /mnt/d/wsl/l-pgsql/tools/dashboards/docker-compose.yml up -d cfp_postgres
```
