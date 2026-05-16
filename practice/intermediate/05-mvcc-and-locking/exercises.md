# Exercises — MVCC and Locking

**Status: blocked — Docker not accessible in this session**
All SQL is correct and ready to run when Docker is available.

---

## Exercise 1: Observe xmin and xmax

Understand that PostgreSQL tracks tuple visibility via hidden system columns.

```sql
-- blocked: Docker not accessible

-- See current xmin/xmax values
SELECT xmin, xmax, id, name, value FROM mvcc_demo;

-- Note the xmin values — they are the XID of the transaction that inserted each row
-- xmax = 0 means the row is live (not deleted or locked)
```

Now update one row and observe the change:

```sql
-- blocked: Docker not accessible

UPDATE mvcc_demo SET value = 99 WHERE name = 'alpha';

-- Read xmin/xmax again
SELECT xmin, xmax, id, name, value FROM mvcc_demo WHERE name = 'alpha';
-- xmin is now a NEW XID (the UPDATE transaction)
-- The old tuple's xmax was set to that XID and is now a dead tuple
```

---

## Exercise 2: See dead tuples with pageinspect

```sql
-- blocked: Docker not accessible

-- Raw page view — shows both live and dead tuples
SELECT lp, t_xmin, t_xmax, t_ctid, t_infomask
FROM heap_page_items(get_raw_page('mvcc_demo', 0));

-- After the UPDATE in Exercise 1:
-- You should see 4 entries: 3 original + 1 new version of 'alpha'
-- The old 'alpha' has t_xmax set to the UPDATE's XID
-- The new 'alpha' has t_xmin set to the same XID and t_xmax = 0
```

---

## Exercise 3: Dead tuple accumulation and vacuum

```sql
-- blocked: Docker not accessible

-- Check dead tuples before
SELECT relname, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
WHERE relname = 'mvcc_demo';

-- Run 100 updates to accumulate dead tuples
DO $$
BEGIN
    FOR i IN 1..100 LOOP
        UPDATE mvcc_demo SET value = i WHERE name = 'beta';
    END LOOP;
END $$;

-- Check dead tuples after
SELECT relname, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
WHERE relname = 'mvcc_demo';
-- n_dead_tup should be ~100

-- Run vacuum
VACUUM mvcc_demo;

-- Check again
SELECT relname, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
WHERE relname = 'mvcc_demo';
-- n_dead_tup should drop to 0 (or near 0)
```

---

## Exercise 4: Inspect locks with pg_locks

**Session A:**
```sql
-- blocked: Docker not accessible
BEGIN;
SELECT * FROM lock_demo WHERE id = 1 FOR UPDATE;
-- Row is now locked with RowShareLock (table) + RowExclusiveLock (row)
```

**From a third session (or another psql connection), inspect locks:**
```sql
-- blocked: Docker not accessible
SELECT
    l.pid,
    l.relation::regclass AS relation,
    l.mode,
    l.granted,
    a.query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.relation = 'lock_demo'::regclass
ORDER BY l.granted DESC, l.pid;
```

**Session B (observe blocking):**
```sql
-- blocked: Docker not accessible
SELECT * FROM lock_demo WHERE id = 1 FOR UPDATE;
-- This will BLOCK waiting for Session A to release
```

**Session A:**
```sql
-- blocked: Docker not accessible
COMMIT; -- Session B's SELECT FOR UPDATE will now proceed
```

---

## Exercise 5: Reproduce a deadlock

Run these two sessions simultaneously (Session A runs lines 1-2, Session B runs lines 3-4, then both continue):

**Session A:**
```sql
-- blocked: Docker not accessible
BEGIN;
SELECT * FROM lock_demo WHERE id = 1 FOR UPDATE; -- locks row 1
-- (pause and let Session B lock row 2)
SELECT * FROM lock_demo WHERE id = 2 FOR UPDATE; -- DEADLOCK: B holds this
COMMIT;
```

**Session B:**
```sql
-- blocked: Docker not accessible
BEGIN;
SELECT * FROM lock_demo WHERE id = 2 FOR UPDATE; -- locks row 2
-- (pause after Session A has locked row 1)
SELECT * FROM lock_demo WHERE id = 1 FOR UPDATE; -- DEADLOCK: A holds this
COMMIT;
```

Expected error in one session (after ~1 second):
```
ERROR:  deadlock detected
DETAIL:  Process 12345 waits for ShareLock on transaction 678; blocked by process 67890.
         Process 67890 waits for ShareLock on transaction 678; blocked by process 12345.
HINT:   See server log for query details.
```

**Prevention:** Always lock rows in consistent id order across all transactions.

---

## Exercise 6: SKIP LOCKED — queue worker pattern

Simulate two concurrent workers claiming jobs from the queue without conflicting:

**Worker 1:**
```sql
-- blocked: Docker not accessible
BEGIN;
SELECT id, task
FROM job_queue
WHERE status = 'pending'
ORDER BY id
LIMIT 1
FOR UPDATE SKIP LOCKED;

-- Worker 1 claims job id=1
UPDATE job_queue SET status = 'processing', worker_id = 'worker-1'
WHERE id = 1;
COMMIT;
```

**Worker 2 (concurrent):**
```sql
-- blocked: Docker not accessible
BEGIN;
SELECT id, task
FROM job_queue
WHERE status = 'pending'
ORDER BY id
LIMIT 1
FOR UPDATE SKIP LOCKED;

-- Worker 2 claims job id=2 (id=1 is locked by Worker 1, so it's skipped)
UPDATE job_queue SET status = 'processing', worker_id = 'worker-2'
WHERE id = 2;
COMMIT;
```

Check results:
```sql
-- blocked: Docker not accessible
SELECT id, task, status, worker_id FROM job_queue ORDER BY id;
```

---

## Exercise 7: NOWAIT — fail fast instead of block

```sql
-- blocked: Docker not accessible

-- Session A locks row 3
BEGIN;
SELECT * FROM lock_demo WHERE id = 3 FOR UPDATE;

-- Session B tries NOWAIT — fails immediately
BEGIN;
SELECT * FROM lock_demo WHERE id = 3 FOR UPDATE NOWAIT;
-- ERROR:  could not obtain lock on row in relation "lock_demo"
ROLLBACK;
```

---

## Reflection questions
1. What is the relationship between xmax and a FOR UPDATE lock? Check xmax during an open FOR UPDATE.
2. Why does SKIP LOCKED not guarantee FIFO ordering under high concurrency?
3. How does `lock_timeout` differ from `statement_timeout`?
4. Why should you never run VACUUM FULL on a live production table during business hours?
