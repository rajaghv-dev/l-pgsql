# Troubleshooting — Query Planning with EXPLAIN

---

## EXPLAIN shows "Seq Scan" but I created an index

**Cause 1: ANALYZE not run** — statistics are stale; planner doesn't know how selective the index is.
```sql
ANALYZE <table>;
```

**Cause 2: Low selectivity** — the query returns a large fraction of rows. PostgreSQL correctly prefers seq scan.
```sql
-- Force index use to compare (diagnostic only):
SET enable_seqscan = off;
EXPLAIN (ANALYZE, BUFFERS) <your query>;
SET enable_seqscan = on;
```

**Cause 3: random_page_cost too high** — the planner overestimates random I/O cost, making index scans appear more expensive.
```sql
-- For SSD storage:
SET random_page_cost = 1.1;
EXPLAIN <your query>;
-- Reset:
RESET random_page_cost;
```

---

## "Index Only Scan" shows high Heap Fetches

**Cause**: The visibility map is not current — VACUUM hasn't run since last update.
```sql
VACUUM <table>;
EXPLAIN (ANALYZE, BUFFERS) <your query>;
-- Heap Fetches should now be 0 (if visibility map is fully current)
```

---

## pg_stat_statements is empty or not found

**Cause 1**: Extension not installed.
```sql
CREATE EXTENSION pg_stat_statements;
```

**Cause 2**: `shared_preload_libraries` does not include `pg_stat_statements`. Requires a PostgreSQL restart:
```bash
# Add to postgresql.conf:
shared_preload_libraries = 'pg_stat_statements'
# Then restart:
docker restart cfp_postgres
```

**Cause 3**: Stats were reset. Queries run before `pg_stat_statements_reset()` are gone.

---

## Hash Join shows Batches > 1

**Cause**: Hash table spilled to disk because `work_mem` is too low.
```sql
-- Temporarily increase for this session:
SET work_mem = '64MB';
EXPLAIN (ANALYZE, BUFFERS) <your query>;
-- Check if Batches drops to 1
```
Do not increase `work_mem` globally without understanding memory implications: each concurrent query can use up to `work_mem` per hash/sort node.

---

## Estimated rows wildly wrong for a low-cardinality column

**Cause**: Statistics resolution (default 100 samples) is too coarse for a column with a heavily skewed distribution (e.g., 95% 'processed', 5% other values).
```sql
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500;
ANALYZE orders;
EXPLAIN <your query>;
-- Compare estimated vs. actual rows again
```

---

## EXPLAIN ANALYZE is slow (query actually runs)

**Cause**: EXPLAIN ANALYZE executes the query. For a long-running query, this can take minutes.

**Workaround**: Use `EXPLAIN` (no ANALYZE) to see the plan without executing. Or wrap in a transaction and rollback:
```sql
BEGIN;
EXPLAIN ANALYZE <your destructive/slow query>;
ROLLBACK;
```
The ROLLBACK undoes any DML effects but the EXPLAIN output is still produced.

---

## Plan changes unexpectedly between runs

**Cause**: The planner's choice depends on statistics, table size, and `work_mem`. After a large INSERT or UPDATE, statistics may be stale, causing a plan flip.

**Fix**: Run `ANALYZE` consistently after bulk changes. Use `pg_stat_statements` to track mean_exec_time over time and alert on sudden increases.

---

## "Filter" vs. "Index Cond" in the plan

- `Index Cond: (col = value)` — condition applied in the index itself; only matching rows are returned from the index
- `Filter: (col = value)` — condition applied after index retrieval or seq scan; rows that fail the filter are discarded

If you see `Filter:` in a plan node where you expected an `Index Cond:`, it means the index does not cover that condition — typically because the WHERE clause column is not in the index, or uses an expression that doesn't match the index.
