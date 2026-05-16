# Troubleshooting — MVCC and Locking

## pageinspect: permission denied for function get_raw_page
**Cause:** `get_raw_page` requires superuser or the `pg_monitor` role in PostgreSQL 16.
**Fix:**
```sql
-- As superuser
GRANT EXECUTE ON FUNCTION get_raw_page(text, int) TO cfp;
-- Or run as superuser: psql -U postgres -d cfp
```

## pageinspect: relation does not exist
**Cause:** The extension was not installed or the table name is wrong.
**Fix:**
```sql
CREATE EXTENSION IF NOT EXISTS pageinspect;
-- Confirm table exists
\dt mvcc_demo
```

## n_dead_tup not updating after UPDATEs
**Cause:** `pg_stat_user_tables.n_dead_tup` is updated by autovacuum or explicit ANALYZE, not immediately after every DML.
**Fix:** Run `ANALYZE mvcc_demo;` to force a statistics update, then recheck.

## VACUUM not reducing dead tuples
**Cause:** An open long-running transaction is holding the MVCC horizon back. Dead tuples that might still be visible to that transaction cannot be removed.
**Fix:** Check for long-running transactions:
```sql
SELECT pid, now() - xact_start AS duration, state, query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC NULLS LAST;
```
Terminate the blocking session if appropriate, then re-run VACUUM.

## ERROR: deadlock detected (40P01)
**Cause:** Two transactions each hold a lock the other needs.
**Fix:** Standardize lock acquisition order across all code paths. For multi-row locks:
```sql
-- Always SELECT in id order before locking
SELECT * FROM lock_demo WHERE id IN (1, 2) ORDER BY id FOR UPDATE;
```
Application code must also catch `SQLSTATE 40P01` and retry.

## SKIP LOCKED returns no rows even when pending jobs exist
**Cause:** All 'pending' rows are currently locked by other workers.
**Fix:** This is correct behavior — all jobs are claimed. The worker should sleep briefly and retry:
```python
while True:
    job = claim_job()
    if job:
        process(job)
    else:
        time.sleep(0.1)
```

## FOR UPDATE NOWAIT fails immediately
**Cause:** Another session holds a lock on the target row.
**Error:** `ERROR: could not obtain lock on row in relation "lock_demo"`
**Fix:** This is the intended behavior of NOWAIT. Use it only when you want immediate failure instead of waiting. Retry in the application.

## xmax is non-zero but row is still visible
**Cause:** A non-zero xmax can mean the row was locked (not deleted) by a FOR UPDATE. The row is still live; the xmax encodes the locker's XID, not a deletion.
**Diagnosis:** Check `t_infomask` bits in `heap_page_items` to distinguish a lock xmax from a delete xmax. Also check if the xmax transaction is still active.
