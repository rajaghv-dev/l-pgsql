# Concurrency Design Principles

Principles for writing PostgreSQL applications that perform correctly and efficiently under concurrent load.

---

## Principle 1: Use SKIP LOCKED for queue-style processing

### One-line rule
Use `SELECT ... FOR UPDATE SKIP LOCKED` to implement work queues — it prevents workers from blocking each other.

### Rationale
A standard `SELECT ... FOR UPDATE` blocks a worker if another worker has already locked the row. `SKIP LOCKED` skips locked rows and immediately returns the next available one, allowing multiple workers to process different jobs in parallel without contention.

### Example (correct)
```sql
-- Each worker runs this in a loop
BEGIN;
SELECT id, payload
FROM jobs
WHERE status = 'pending'
ORDER BY created_at
FOR UPDATE SKIP LOCKED
LIMIT 1;

UPDATE jobs SET status = 'processing', started_at = now()
WHERE id = $job_id;
COMMIT;

-- After processing:
UPDATE jobs SET status = 'done', finished_at = now() WHERE id = $job_id;
```

### Counter-example (incorrect)
```sql
-- Without SKIP LOCKED: Worker 2 blocks until Worker 1 releases the lock
SELECT id FROM jobs WHERE status = 'pending' LIMIT 1 FOR UPDATE;
```

### When this principle applies
Any queue, task processor, or event pipeline implemented on top of PostgreSQL.

### When to break it (with justification)
When jobs must be processed strictly in order and parallel processing is not safe. In that case, use a single consumer with `FOR UPDATE`.

### Agent/MCP implications
MCP tools that process work queues must use SKIP LOCKED to avoid a single slow job blocking all other tool calls.

---

## Principle 2: Avoid SELECT FOR UPDATE on large result sets

### One-line rule
Never lock more rows than you need to modify — use `SELECT ... FOR UPDATE` with a tight WHERE clause and LIMIT.

### Rationale
`SELECT ... FOR UPDATE` acquires a row-level lock on every row in the result set. Locking 10,000 rows at once blocks every other transaction that touches those rows, creating a lock queue that can cascade into application-wide slowdowns.

### Example (correct)
```sql
-- Lock only the specific row you need
SELECT * FROM orders WHERE id = 42 FOR UPDATE;
```

### Counter-example (incorrect)
```sql
-- Locks all pending orders — blocks all other modifications to these rows
SELECT * FROM orders WHERE status = 'pending' FOR UPDATE;
-- If 50,000 rows match, 50,000 locks held until COMMIT
```

### When to break it (with justification)
Bulk migrations where you deliberately need exclusive access to a full result set. Schedule during maintenance windows.

---

## Principle 3: Prefer optimistic locking for low-contention scenarios

### One-line rule
Use a `version` integer column and check-on-update instead of `FOR UPDATE` when conflicts are rare.

### Rationale
Pessimistic locking (`FOR UPDATE`) holds a lock from read to commit. If the read-to-write gap is long, you hold locks for a long time. Optimistic locking assumes conflicts are rare, does no locking at read time, and fails fast if a conflict is detected at write time — with lower average latency.

### Example (correct)
```sql
-- Schema
ALTER TABLE documents ADD COLUMN version int NOT NULL DEFAULT 1;

-- Read (no lock)
SELECT id, content, version FROM documents WHERE id = $1;

-- Write: increment version and verify no one else changed it
UPDATE documents
SET content = $new_content, version = version + 1
WHERE id = $1 AND version = $expected_version;

-- If 0 rows updated → conflict detected → application retries
```

### When to break it (with justification)
High-contention rows (e.g., a shared counter, a hot inventory record) see many conflicts with optimistic locking — retries pile up. Use `FOR UPDATE` or explicit advisory locks for hot rows.

---

## Principle 4: Know which DDL statements take AccessExclusiveLock

### One-line rule
Before running any DDL in production, check what lock it takes — `AccessExclusiveLock` blocks all reads and writes.

### Rationale
Some DDL operations appear safe but take the strongest possible lock. `ALTER TABLE ADD COLUMN` with a non-null default used to rewrite the table entirely (fixed in PG 11+, but still takes a brief AccessExclusiveLock). `TRUNCATE`, `DROP TABLE`, `VACUUM FULL`, and most `ALTER TABLE` variants block all concurrent access.

### Example (correct)
```sql
-- Safe in PG 11+: Adding a column with a constant default is instant
ALTER TABLE orders ADD COLUMN archived bool NOT NULL DEFAULT false;

-- Unsafe: Adding a column with a computed default rewrites the table
-- ALTER TABLE orders ADD COLUMN hash text DEFAULT md5(id::text);
-- Prefer: Add as nullable first, backfill, then add NOT NULL separately

ALTER TABLE orders ADD COLUMN hash text;                 -- Fast
UPDATE orders SET hash = md5(id::text) WHERE hash IS NULL;  -- Batched
ALTER TABLE orders ALTER COLUMN hash SET NOT NULL;       -- Brief lock after backfill
```

### Counter-example (incorrect)
```sql
-- Adding NOT NULL with DEFAULT that requires a rewrite during peak hours
ALTER TABLE orders ADD COLUMN processed bool NOT NULL DEFAULT false;
-- PG < 11: rewrites entire table with AccessExclusiveLock
```

### PostgreSQL implementation
Use `pg_locks` to inspect current lock contention:
```sql
SELECT l.pid, l.mode, a.query, now() - a.query_start AS duration
FROM pg_locks l
JOIN pg_stat_activity a ON a.pid = l.pid
WHERE l.granted = false
ORDER BY duration DESC;
```

---

## Principle 5: Use advisory locks for distributed mutual exclusion

### One-line rule
Use `pg_try_advisory_lock(key)` for application-level mutexes — they are lightweight, automatically released on disconnect, and do not require a lock table.

### Rationale
Application code often needs "only one process runs this at a time" guarantees (cron jobs, singleton workers, exclusive reports). Advisory locks provide this without the complexity of a lock management table that can get stale if a process crashes.

### Example (correct)
```sql
-- Try to acquire lock for job ID 7
SELECT pg_try_advisory_lock(7);  -- Returns true if acquired, false if already held

-- ... do exclusive work ...

SELECT pg_advisory_unlock(7);    -- Release when done
-- If process crashes, lock is released when the connection closes
```

### Counter-example (incorrect)
```sql
CREATE TABLE running_jobs (job_id int PRIMARY KEY);
INSERT INTO running_jobs VALUES (7);  -- "Lock"
-- ... process crashes ...
-- Row remains! No process can run job 7 until manually cleaned up
```

---

## Principle 6: Set lock_timeout and statement_timeout to protect against lock waits

### One-line rule
Set `lock_timeout` on DDL sessions and `statement_timeout` on application connections to prevent runaway lock waits.

### Rationale
Without timeouts, a transaction waiting for a lock can wait indefinitely, consuming a connection and potentially becoming the head of a lock queue that blocks all subsequent requests on that table.

### Example (correct)
```sql
-- For DDL migrations: fail fast rather than blocking for minutes
SET lock_timeout = '5s';
ALTER TABLE orders ADD COLUMN archived bool NOT NULL DEFAULT false;
RESET lock_timeout;

-- For application connections (set in connection string or session):
SET statement_timeout = '30s';  -- No single query should take more than 30s
```

### PostgreSQL implementation
Set defaults in `postgresql.conf` or per-role:
```sql
ALTER ROLE app_user SET statement_timeout = '30s';
ALTER ROLE migration_user SET lock_timeout = '10s';
```
