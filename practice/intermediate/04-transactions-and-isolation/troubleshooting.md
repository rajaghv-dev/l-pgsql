# Troubleshooting — Transactions and Isolation Levels

## Error: could not serialize access due to read/write dependencies among transactions
**SQLSTATE:** 40001
**Cause:** Two SERIALIZABLE transactions created a dependency cycle (serialization anomaly).
**Fix:** Retry the entire transaction from BEGIN. Use exponential backoff. This is expected behavior, not a bug.

```python
import time, random
def run_with_retry(conn, fn, max_attempts=5):
    for attempt in range(max_attempts):
        try:
            with conn.transaction(isolation_level='SERIALIZABLE'):
                return fn(conn)
        except psycopg2.errors.SerializationFailure:
            if attempt == max_attempts - 1:
                raise
            time.sleep(random.uniform(0.1, 0.5) * (2 ** attempt))
```

## Error: deadlock detected
**SQLSTATE:** 40P01
**Cause:** Two transactions each hold a lock the other needs.
**Fix:** Ensure all transactions lock rows in the same order (e.g., always lock by ascending id). Also requires retry.

## Error: ERROR: new row for relation "bank_accounts" violates check constraint "bank_accounts_balance_check"
**Cause:** UPDATE reduced balance below 0.
**Fix:** Always read the current balance inside the transaction (with FOR UPDATE) and validate before updating.

## Transaction left open (idle in transaction)
**Symptom:** Queries hang waiting for a lock; `pg_stat_activity` shows sessions with `state = 'idle in transaction'`.
**Fix:** Set `idle_in_transaction_session_timeout = '30s'` in postgresql.conf or per-session. Ensure application code always commits or rolls back.

```sql
-- Per-session timeout
SET idle_in_transaction_session_timeout = '30s';
```

## Non-repeatable reads occurring unexpectedly
**Symptom:** Same SELECT returns different results within one transaction.
**Diagnosis:** Check that the transaction is using READ COMMITTED (the default). Verify with:
```sql
SHOW transaction_isolation;
```
**Fix:** Use REPEATABLE READ or SERIALIZABLE if consistent snapshot is required.

## ROLLBACK TO SAVEPOINT fails
**Error:** `ERROR: no such savepoint`
**Cause:** SAVEPOINT name was misspelled or the transaction was aborted before the SAVEPOINT.
**Fix:** After any error in a transaction, the transaction enters an error state. You must ROLLBACK the whole transaction (not just to a savepoint) before starting fresh.

## Performance: SERIALIZABLE is slow
**Symptom:** High serialization failure rate causing many retries.
**Diagnosis:** Check for contention patterns with `pg_stat_activity`. Look for hot rows (same row being read and written frequently).
**Fix:** Consider whether REPEATABLE READ with explicit FOR UPDATE locking is sufficient for your use case. SERIALIZABLE adds overhead proportional to the number of concurrent transactions tracking dependencies.
