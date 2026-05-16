# Indexing Design Principles

Principles for creating, maintaining, and removing indexes correctly.

---

## Principle 1: Index what you query, not what looks important

### One-line rule
Create an index only when you have a specific query that will use it — verify with EXPLAIN.

### Rationale
Indexes are not free. Every index adds overhead to INSERT, UPDATE, and DELETE operations, consumes storage, and adds planning complexity. An index that no query uses is pure cost with no benefit.

### Example (correct)
```sql
-- Step 1: Identify the slow query
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE user_id = 42 AND status = 'pending';

-- Step 2: See "Seq Scan" on large table → add index
CREATE INDEX CONCURRENTLY idx_orders_user_status
    ON orders (user_id, status)
    WHERE status = 'pending';  -- Partial if most queries filter this way

-- Step 3: Re-run EXPLAIN to confirm "Index Scan" is now chosen
```

### Counter-example (incorrect)
```sql
-- Indexing every column "just in case"
CREATE INDEX ON orders (user_id);
CREATE INDEX ON orders (status);
CREATE INDEX ON orders (created_at);
CREATE INDEX ON orders (total);
CREATE INDEX ON orders (updated_at);
-- 5 indexes to maintain on every write, many possibly unused
```

### When this principle applies
All index creation decisions.

### When to break it (with justification)
Primary keys and unique constraints automatically create indexes — this is correct and mandatory.

### Related principles
[[query-design-principles]]

---

## Principle 2: Always verify index usage with EXPLAIN ANALYZE

### One-line rule
After creating an index, run `EXPLAIN (ANALYZE, BUFFERS)` to confirm the planner chose it.

### Rationale
An index can be created and valid but still not used by the planner if: the table is too small, the column selectivity is too low, the statistics are stale, or `random_page_cost` is set too high. EXPLAIN is the only way to know.

### Example (correct)
```sql
CREATE INDEX idx_orders_user_id ON orders (user_id);
ANALYZE orders;  -- Refresh statistics

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE user_id = 42;
-- Confirm output contains: "Index Scan using idx_orders_user_id"
```

### PostgreSQL implementation
If the planner uses a Seq Scan despite an index:
1. Run `ANALYZE orders` — stale stats may cause underestimation.
2. Check `pg_stat_user_indexes` to confirm the index is not already being used differently.
3. Test with `SET enable_seqscan = off` to see the index-forced plan cost.
4. If the table has < ~1000 rows, a seq scan is often genuinely faster — the index is unnecessary.

---

## Principle 3: Create all indexes CONCURRENTLY in production

### One-line rule
Use `CREATE INDEX CONCURRENTLY` and `DROP INDEX CONCURRENTLY` on production tables — never block writes.

### Rationale
Standard `CREATE INDEX` acquires a `ShareLock` that blocks all writes on the table for the duration of the build. On a busy table with millions of rows, this can take minutes and cause cascading timeouts for application requests.

### Example (correct)
```sql
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders (user_id);
```

### Counter-example (incorrect)
```sql
CREATE INDEX ON orders (user_id);  -- Blocks all INSERTs/UPDATEs/DELETEs during build
```

### When to break it (with justification)
During a migration run before traffic starts (initial deployment), or inside a transaction that requires the index to be built atomically (CONCURRENTLY cannot run inside a transaction).

### PostgreSQL implementation
If CONCURRENTLY fails partway, it leaves an invalid index marked with `indisvalid = false` in `pg_index`. Clean it up:
```sql
SELECT indexrelname FROM pg_stat_user_indexes WHERE idx_scan = 0;
DROP INDEX CONCURRENTLY idx_orders_user_id;  -- Try again
```

---

## Principle 4: Index FK columns on the referencing table

### One-line rule
After every `REFERENCES` clause, immediately create an index on the referencing column — PostgreSQL does not do this automatically.

### Rationale
Without an index on the FK column, every `DELETE` from the parent table causes a full sequential scan of the child table to find referencing rows. For a child table with millions of rows, this causes severe performance degradation on parent deletes.

### Example (correct)
```sql
CREATE TABLE order_items (
    id       bigserial PRIMARY KEY,
    order_id bigint NOT NULL REFERENCES orders(id) ON DELETE CASCADE
);
CREATE INDEX ON order_items (order_id);  -- Required — not automatic
```

### PostgreSQL implementation
Script to find FK columns without indexes (see [[intermediate-design-principles]] Principle 3 for the query).

---

## Principle 5: Monitor index bloat and reindex when necessary

### One-line rule
Periodically check index bloat and use `REINDEX CONCURRENTLY` to rebuild bloated indexes.

### Rationale
Indexes accumulate bloat from updates and deletes just like tables do — VACUUM marks dead index entries but does not compact the index structure. A bloated index is larger than necessary and slower to scan.

### Example (correct)
```sql
-- Estimate index bloat (requires pgstattuple extension)
CREATE EXTENSION IF NOT EXISTS pgstattuple;

SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
       leaf_fragmentation
FROM pg_stat_user_indexes
CROSS JOIN LATERAL pgstatindex(indexrelid::regclass) AS s
WHERE relname = 'orders'
ORDER BY leaf_fragmentation DESC;

-- Rebuild without locking (PostgreSQL 12+)
REINDEX INDEX CONCURRENTLY idx_orders_user_id;
```

### When to break it (with justification)
Small tables where index size is insignificant. Focus bloat monitoring on large, high-write tables.

---

## Principle 6: Remove unused indexes

### One-line rule
Drop any index with zero or near-zero `idx_scan` in `pg_stat_user_indexes` after confirming it is not required for FK checks or unique constraints.

### Rationale
Unused indexes have all the costs (write overhead, storage, vacuum maintenance) with none of the benefits (faster reads). In write-heavy systems, unused indexes can account for 20-30% of write time.

### Example (correct)
```sql
-- Find unused indexes (stats reset when server restarts — compare over time)
SELECT schemaname, relname, indexrelname, idx_scan,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan < 10
  AND NOT EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conindid = indexrelid
  )
ORDER BY pg_relation_size(indexrelid) DESC;

-- After confirming safe to remove:
DROP INDEX CONCURRENTLY idx_orders_old_status;
```

### When to break it (with justification)
Indexes used for periodic reporting queries (run once a week) will show low `idx_scan` counts. Check query logs alongside `pg_stat_user_indexes`.

---

## Principle 7: Prefer composite indexes ordered by selectivity and query pattern

### One-line rule
In a composite index, put the highest-cardinality (most selective) columns first, ordered by your most common query filter.

### Rationale
A composite index on `(a, b)` can be used for queries that filter on `a` alone, or `a AND b`, but NOT for queries that filter on `b` alone. Put the column you always filter on first.

### Example (correct)
```sql
-- Query: WHERE tenant_id = $1 AND status = 'pending' ORDER BY created_at
-- tenant_id is always present; status narrows further
CREATE INDEX ON orders (tenant_id, status, created_at);
-- Supports: WHERE tenant_id = X
-- Supports: WHERE tenant_id = X AND status = Y
-- Supports: WHERE tenant_id = X AND status = Y ORDER BY created_at
```

### Counter-example (incorrect)
```sql
-- Wrong order: queries filtering only on tenant_id cannot use this index
CREATE INDEX ON orders (status, tenant_id, created_at);
```
