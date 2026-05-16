# Advanced Design Principles

Ten principles for engineers running PostgreSQL in production: performance tuning, concurrency, MVCC-aware design, and safety at scale.

---

## Principle 1: Design for MVCC — minimize long-running transactions

### One-line rule
Keep transactions as short as possible; a long transaction is a vacuum blocker and a lock holder.

### Rationale
PostgreSQL's MVCC keeps old row versions alive as long as any open transaction could need them. A transaction open for 10 minutes means dead tuples from all tables it touched cannot be vacuumed for 10 minutes — causing table bloat, index bloat, and eventually transaction ID wraparound risk.

### Example (correct)
```sql
-- Process work in small batches, commit frequently
DO $$
DECLARE batch_size int := 1000; offset_val int := 0;
BEGIN
    LOOP
        UPDATE orders SET processed = true
        WHERE id IN (
            SELECT id FROM orders WHERE processed = false LIMIT batch_size
        );
        EXIT WHEN NOT FOUND;
        COMMIT;
    END LOOP;
END $$;
```

### Counter-example (incorrect)
```sql
BEGIN;
-- Long application-side loop over millions of rows
-- Transaction stays open for hours
UPDATE orders SET processed = true;  -- Blocks all vacuum on orders
COMMIT;
```

### When to break it (with justification)
Bulk migrations that must be atomic. Mitigate by scheduling during low-traffic windows and monitoring `pg_stat_activity`.

### PostgreSQL implementation
```sql
-- Find long-running transactions
SELECT pid, now() - xact_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active' AND xact_start < now() - interval '5 minutes';
```

### Agent/MCP implications
MCP tools must never hold a transaction open waiting for human input or external API calls.

### Related principles
[[transaction-design-principles]]

---

## Principle 2: Use RLS over application-level row filtering

### One-line rule
For multi-tenant data, enforce isolation with Row Level Security policies — not WHERE clauses in application code.

### Rationale
Application-level filtering can be bypassed: a buggy WHERE clause, a new developer forgetting to add the filter, or a direct database connection. RLS is enforced by the engine for every query on the table, including those from application bugs.

### Example (correct)
```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON orders
    FOR ALL
    USING (tenant_id = current_setting('app.tenant_id')::bigint);

-- Application sets context before any query:
SET LOCAL app.tenant_id = '42';
SELECT * FROM orders;  -- Automatically filtered to tenant 42
```

### Counter-example (incorrect)
```sql
-- Application always adds WHERE tenant_id = $1, but...
SELECT * FROM orders WHERE tenant_id = $tenant_id;
-- ...a developer forgets the filter in one endpoint, exposing all tenants
```

### When to break it (with justification)
Internal admin tools that legitimately need cross-tenant access. Use a separate role with `BYPASSRLS` privilege, not a disabled policy.

### PostgreSQL implementation
`SET LOCAL` is session-scoped; use it in functions or at transaction start in your connection pool setup.

### Related principles
[[security-design-principles]]

---

## Principle 3: Never run VACUUM FULL during business hours

### One-line rule
`VACUUM FULL` takes an `AccessExclusiveLock` — the table is completely unavailable. Schedule it only during maintenance windows.

### Rationale
`VACUUM FULL` rewrites the entire table and holds the strongest lock possible. All reads and writes to that table block until VACUUM FULL finishes. For a 100GB table this can take hours.

### Example (correct)
```sql
-- Check bloat first
SELECT relname,
       pg_size_pretty(pg_total_relation_size(oid)) AS total_size,
       n_dead_tup
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Use pg_repack instead of VACUUM FULL (runs without ExclusiveLock)
-- pg_repack --table=orders mydb
```

### Counter-example (incorrect)
```sql
VACUUM FULL orders;  -- During peak hours: all order queries block immediately
```

### When to break it (with justification)
During planned maintenance windows for tables that have extreme bloat and cannot be pg_repacked. Announce downtime and coordinate with stakeholders.

### PostgreSQL implementation
`pg_repack` is the production-safe alternative: it rebuilds the table concurrently, switching over at the end with a brief lock.

---

## Principle 4: Vacuum before you partition

### One-line rule
Run VACUUM ANALYZE on a table before converting it to partitioned — stale stats and dead tuples make the migration slower and plans worse.

### Rationale
Partitioning requires creating new table structures and migrating data. If the source table has high bloat, the migrated partitions inherit that bloat. Stale statistics mean the planner makes poor partition pruning decisions immediately after migration.

### Example (correct)
```sql
VACUUM ANALYZE orders;  -- Clean up first
-- Then proceed with partitioning:
CREATE TABLE orders_partitioned (LIKE orders INCLUDING ALL)
    PARTITION BY RANGE (created_at);
```

---

## Principle 5: Index only what you query — remove unused indexes

### One-line rule
Regularly audit `pg_stat_user_indexes` and drop indexes with zero or near-zero scans.

### Rationale
Every index adds write overhead (INSERT, UPDATE, DELETE all maintain index entries). An unused index costs write performance and storage without providing any query benefit.

### Example (correct)
```sql
-- Find candidates for removal (zero scans since last stats reset)
SELECT indexrelname, idx_scan, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND NOT indisprimary
  AND NOT indisunique
ORDER BY pg_relation_size(indexrelid) DESC;

-- Remove after verification
DROP INDEX CONCURRENTLY IF EXISTS idx_orders_old_status;
```

### When to break it (with justification)
Indexes with `idx_scan = 0` may still be critical for FK integrity checks or occasional reports. Verify before dropping. Use `CREATE INDEX CONCURRENTLY` to recreate if needed.

---

## Principle 6: Use CONCURRENTLY for index creation and deletion in production

### One-line rule
Always use `CREATE INDEX CONCURRENTLY` and `DROP INDEX CONCURRENTLY` in production — never block writes.

### Rationale
`CREATE INDEX` without `CONCURRENTLY` takes a `ShareLock` that blocks all writes on the table until the index is built. On a busy table this can cause cascading lock waits.

### Example (correct)
```sql
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders (user_id);
DROP INDEX CONCURRENTLY idx_orders_old;
```

### Counter-example (incorrect)
```sql
CREATE INDEX ON orders (user_id);  -- Blocks all writes during build
```

### When to break it (with justification)
Initial schema setup before any production traffic. Maintenance windows where downtime is acceptable and speed matters more than availability.

### PostgreSQL implementation
`CONCURRENTLY` cannot run inside a transaction block. If it fails partway, it leaves an invalid index — drop it and retry.

---

## Principle 7: Prefer SERIALIZABLE isolation only when required by correctness

### One-line rule
Use `READ COMMITTED` by default; escalate to `REPEATABLE READ` or `SERIALIZABLE` only when the application's correctness requires it.

### Rationale
Higher isolation levels have higher conflict rates and retry overhead. SERIALIZABLE prevents all anomalies (phantom reads, write skew, serialization anomalies) but causes more transaction aborts that your application must handle and retry.

### Example (correct)
```sql
-- Only use SERIALIZABLE when the business logic requires it
-- (e.g., "check balance, then deduct" — write skew risk)
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT balance FROM accounts WHERE id = $1 FOR SHARE;
UPDATE accounts SET balance = balance - $amount WHERE id = $1;
COMMIT;  -- May fail with serialization_failure — application must retry
```

### When to break it (with justification)
Financial systems, inventory allocation, and any "check-then-act" pattern that would produce wrong results under concurrent writes. Use SERIALIZABLE and retry on `ERROR 40001`.

---

## Principle 8: Use advisory locks for application-level mutex patterns

### One-line rule
When you need a distributed mutex (e.g., "only one worker runs this job"), use `pg_try_advisory_lock` instead of a lock table.

### Rationale
Advisory locks are cooperative (your code must release them), lightweight, and not tied to a specific table row. They are released automatically on session disconnect, which is a safety net lock tables do not have.

### Example (correct)
```sql
-- Only one process runs the nightly report
SELECT pg_try_advisory_lock(42);  -- Returns true if acquired, false if not
-- ... do work ...
SELECT pg_advisory_unlock(42);
```

### Counter-example (incorrect)
```sql
-- Lock table pattern: rows don't auto-release on disconnect
CREATE TABLE job_locks (job_name text PRIMARY KEY);
INSERT INTO job_locks VALUES ('nightly_report');  -- Blocks if another process holds it
-- If process crashes, row remains, deadlocking all future runs
```

---

## Principle 9: Monitor xid age and bloat proactively

### One-line rule
Set up alerts for `age(datfrozenxid)` approaching the vacuum freeze threshold and for tables with high dead tuple ratios.

### Rationale
PostgreSQL's transaction ID is a 32-bit counter. At 2 billion transactions, it wraps around and PostgreSQL will forcibly shut down to prevent data corruption (autovacuum forced freeze). This is preventable with monitoring.

### Example (correct)
```sql
-- Alert if any database's XID age exceeds 1.5 billion
SELECT datname, age(datfrozenxid) AS xid_age
FROM pg_database
WHERE age(datfrozenxid) > 1500000000;

-- Alert on bloated tables
SELECT relname,
       n_dead_tup::float / NULLIF(n_live_tup + n_dead_tup, 0) AS dead_ratio
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY dead_ratio DESC;
```

---

## Principle 10: Use generated columns and expression indexes to enforce derived data consistency

### One-line rule
Never store a value that can be computed from another column without using a generated column or expression index — computed values stored manually drift.

### Rationale
If `full_name = first_name || ' ' || last_name` is stored manually, it diverges whenever `first_name` or `last_name` changes and the application forgets to update `full_name`. Generated columns are updated automatically by the engine.

### Example (correct)
```sql
CREATE TABLE people (
    first_name text NOT NULL,
    last_name  text NOT NULL,
    full_name  text GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED
);

-- Expression index for case-insensitive search without a separate column:
CREATE INDEX ON users (lower(email));
```

### Counter-example (incorrect)
```sql
-- full_name can get out of sync with first_name/last_name
CREATE TABLE people (
    first_name text,
    last_name  text,
    full_name  text  -- application must remember to keep this in sync
);
```
