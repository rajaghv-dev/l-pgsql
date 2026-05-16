# Solutions — MVCC and Locking

**Status: blocked — Docker not accessible in this session**

---

## Exercise 1 solution
After UPDATE, the new row version has a new xmin (the UPDATE transaction's XID). The old row version still exists in the heap with its original xmin and xmax now set to the UPDATE's XID. Both versions occupy space until VACUUM runs.

The xmin of the new row version equals the xmax of the old row version — they share the same XID.

---

## Exercise 2 solution
`heap_page_items` reveals:
- Old tuple: `t_xmin = <original insert XID>`, `t_xmax = <update XID>`, `t_ctid` points to the new tuple's location
- New tuple: `t_xmin = <update XID>`, `t_xmax = 0`

The `t_ctid` (current tuple ID) in the old version is a forwarding pointer to the new version. This is how index scans can find the current version after an update.

`t_infomask` bits encode whether the xmin/xmax are committed or aborted, avoiding repeated clog lookups (hint bits).

---

## Exercise 3 solution
After 100 updates to 'beta', `n_dead_tup` will be approximately 100 (each UPDATE creates one dead tuple from the previous version). After `VACUUM mvcc_demo`, `n_dead_tup` drops to near 0.

Note: `pg_stat_user_tables` counters are not always exact — they are updated by autovacuum and ANALYZE, not in real time. Run `ANALYZE mvcc_demo` after vacuum to refresh stats.

VACUUM reclaims the space for reuse within the same data file but does NOT shrink the file size. `VACUUM FULL` would shrink the file but requires an ACCESS EXCLUSIVE lock.

---

## Exercise 4 solution
`pg_locks` output shows two entries for Session A's transaction:
1. `relation = lock_demo, mode = RowExclusiveLock, granted = true` — table-level lock
2. `transactionid = <XID>, mode = ExclusiveLock, granted = true` — transaction lock

Session B's entry shows:
- `mode = ShareLock, granted = false` — waiting for Session A's transaction lock

Identify blocking pids: `SELECT pg_blocking_pids(pg_backend_pid());` in Session B returns Session A's pid.

---

## Exercise 5 solution
PostgreSQL detects the cycle after `deadlock_timeout` (default 1s). It aborts one transaction (usually the one that last requested a lock) with:
```
ERROR:  deadlock detected
SQLSTATE: 40P01
```

The surviving transaction continues normally. The aborted transaction's application must retry.

**Prevention pattern:**
```sql
-- Always lock in ascending id order
SELECT * FROM lock_demo
WHERE id IN (1, 2)
ORDER BY id
FOR UPDATE;
```
This single statement acquires locks atomically in id order, preventing the interleaved acquisition that causes deadlocks.

---

## Exercise 6 solution
SKIP LOCKED works by: when the optimizer encounters a row that is locked by another transaction, it skips it and moves to the next eligible row rather than waiting. This makes it ideal for work queues where any pending item is equally valid to process.

After both workers complete:
```
id | task                  | status     | worker_id
---|-----------------------|------------|----------
1  | send-email-001        | processing | worker-1
2  | generate-report-002   | processing | worker-2
3  | process-payment-003   | pending    | NULL
...
```

Ordering guarantee: Workers will claim the lowest available id that isn't locked, but under high concurrency (many workers), id=1 might be claimed by worker-2 if worker-1 is slow to start its transaction.

---

## Exercise 7 solution
`FOR UPDATE NOWAIT` immediately raises an error if any row in the result set is locked. This is preferable to blocking when the application has a timeout budget or can immediately try an alternative row.

Use cases for NOWAIT:
- Optimistic UI flows: "someone else is editing this record, please try again"
- Microservice timeouts: never block longer than the request budget

Use cases for blocking (no NOWAIT):
- Queue workers where waiting for the lock is acceptable
- Batch processes with no urgency
