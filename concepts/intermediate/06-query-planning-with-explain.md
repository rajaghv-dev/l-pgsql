# Query Planning with EXPLAIN
Level: Intermediate

## One-line intuition
`EXPLAIN` shows you PostgreSQL's plan for your query; `EXPLAIN ANALYZE` shows the plan plus what actually happened — and the gap between them reveals why queries are slow.

## Why this exists
PostgreSQL's query planner generates an execution plan for every query. The plan determines whether a query uses an index or scans the full table, which join algorithm it chooses, and in what order it processes tables. Without `EXPLAIN`, these decisions are invisible. With it, you can diagnose performance problems, verify index usage, and understand cost tradeoffs.

## First-principles explanation
The planner works in steps:
1. **Parse** the SQL into a query tree
2. **Rewrite** (apply rules, expand views)
3. **Plan** — enumerate possible plans, estimate cost of each, pick the cheapest
4. **Execute** — run the chosen plan

`EXPLAIN` shows the plan chosen in step 3 with cost estimates. `EXPLAIN ANALYZE` runs the plan (step 4) and overlays actual timing and row counts.

Costs are in abstract **page I/O units** (not milliseconds). They are estimates based on table statistics maintained by `ANALYZE`.

## Micro-concepts
| Term | Meaning |
|---|---|
| `cost=X..Y` | Startup cost X (to return first row), total cost Y (to return all rows) |
| `rows=N` | Estimated row count; compare to actual rows in ANALYZE mode |
| `width=N` | Estimated average row width in bytes |
| Seq Scan | Full table scan — reads every row |
| Index Scan | Uses index to find matching TIDs, fetches each row from heap |
| Index Only Scan | Uses index alone — no heap fetch (requires visible pages) |
| Bitmap Heap Scan | Collects TIDs from index(es) into a bitmap, reads heap in page order |
| Hash Join | Builds a hash table from the smaller relation; probes with the larger |
| Nested Loop | For each row in outer relation, look up matching rows in inner relation |
| Merge Join | Merge two sorted streams; requires sorted inputs |
| `actual time=X..Y` | ANALYZE only: real startup and total time in milliseconds |
| `actual rows=N` | ANALYZE only: real row count produced |
| `Buffers` | ANALYZE BUFFERS: shared/local cache hits and misses |

## Beginner view
```sql
-- Read the plan (no execution)
EXPLAIN SELECT * FROM orders WHERE customer_id = 1;

-- Read the plan AND execute (shows real timings)
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1;

-- Full detail: real timings + buffer usage
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM orders WHERE customer_id = 1;
```

Output is a tree read **from bottom to top** (innermost node executes first, result flows upward to the root). The root node is the last operation and produces the final result.

```
Seq Scan on orders  (cost=0.00..1.05 rows=5 width=48)
  Filter: (customer_id = 1)
```
This means: scan all rows of `orders`, filter where `customer_id = 1`. No index used.

## Intermediate view
**Reading a plan**:
```
Gather  (cost=1000.00..2345.67 rows=50 width=48)
  ->  Parallel Seq Scan on orders  (cost=0.00..1245.67 rows=50 width=48)
        Filter: (status = 'pending')
```
- Gather = collect from parallel workers
- Arrow → = "feeds into" (reads bottom to top)
- `cost=0.00..1245.67` = startup cost 0, total 1245.67

**Seq Scan vs Index Scan decision**: The planner chooses seq scan when the estimated fraction of rows returned is large (e.g., > ~5–15% of the table). Returning 15% of a 1M-row table via index scan means 150k random I/Os — potentially slower than a sequential read of the whole table.

```sql
-- After adding an index on customer_id and ANALYZE:
EXPLAIN SELECT * FROM orders WHERE customer_id = 1;
-- May show: Index Scan using orders_customer_id_idx on orders
```

**Bitmap Heap Scan**: A compromise between Seq Scan and Index Scan. Gathers many matching TIDs from the index into a bitmap, then reads the heap in page order (more sequential than individual Index Scans for medium selectivity queries).
```
Bitmap Heap Scan on orders  (cost=5.00..20.00 rows=100 width=48)
  Recheck Cond: (customer_id = 5)
  ->  Bitmap Index Scan on orders_customer_id_idx
        Index Cond: (customer_id = 5)
```

**Index Only Scan**: The planner uses this when all required columns are in the index (as key or INCLUDE). Shows `Heap Fetches: 0` if the visibility map is fully up-to-date.

**Cost model**: `cost = pages * seq_page_cost + rows * cpu_tuple_cost` (simplified). Parameters like `seq_page_cost=1.0`, `random_page_cost=4.0` (default, SSD should be 1.1–2.0) influence choices. On SSD, random I/O is cheaper — lower `random_page_cost`:
```sql
SET random_page_cost = 1.1;  -- For SSD storage; encourages index scans
```

**When estimates are wrong** — compare `rows=` estimate vs `actual rows=`:
```
Seq Scan on orders  (cost=0.00..5000.00 rows=100 width=48)
                    (actual time=0.05..45.23 rows=85432 loops=1)
```
Estimate: 100 rows. Actual: 85,432 rows. The planner chose a bad plan because it severely underestimated. Fix:
```sql
ANALYZE orders;
-- Or increase statistics target for that column:
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500;
ANALYZE orders;
```

## Advanced view
**`pg_stat_statements`**: Identifies slow queries by aggregate runtime across all executions — essential for finding real bottlenecks:
```sql
-- Top 10 queries by total execution time
SELECT query,
       calls,
       total_exec_time,
       mean_exec_time,
       rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

**`pg_stat_user_tables`**: Shows scan type counts:
```sql
SELECT relname, seq_scan, idx_scan, n_live_tup
FROM pg_stat_user_tables
WHERE relname = 'orders';
-- High seq_scan with large n_live_tup → missing index
```

**Join algorithms**: Hash Join is best when both sides fit in memory (`work_mem`). Nested Loop is best when the inner side has a fast index lookup and the outer side is small. Merge Join is best when both sides are already sorted.

**`EXPLAIN (FORMAT JSON)`**: Machine-parseable output for tooling. Tools like `explain.depesz.com` and `pev2` (Postgres Explain Visualizer 2) render JSON plans graphically.

## Mental model
`EXPLAIN` is an X-ray of your query. Without it, you see only the result — the query either returns rows quickly or slowly. With it, you see the skeleton: which operations are expensive, which estimates are wrong, and which index was (or wasn't) used. `EXPLAIN ANALYZE` is an X-ray taken while the patient is running — it shows what actually happened, not just what was planned.

## PostgreSQL view
```sql
-- Standard (no execution)
EXPLAIN SELECT ...;

-- With execution stats
EXPLAIN ANALYZE SELECT ...;

-- Full diagnostics
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT TEXT) SELECT ...;

-- Machine-readable
EXPLAIN (ANALYZE, FORMAT JSON) SELECT ...;

-- Reset stats for fresh measurement
SELECT pg_stat_reset();

-- Statistics target (how much detail ANALYZE collects)
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500;
-- Default is 100; increase for low-cardinality columns with skewed distributions

-- Check existing statistics
SELECT * FROM pg_stats WHERE tablename = 'orders' AND attname = 'status';
```

## SQL view
```sql
-- Before adding an index: observe seq scan
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE status = 'pending';

-- Add index, re-analyze, observe plan change
CREATE INDEX ON orders (status);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE status = 'pending';

-- Find slow queries with pg_stat_statements
SELECT LEFT(query, 80) AS query_snippet,
       calls,
       ROUND(mean_exec_time::numeric, 2) AS avg_ms,
       ROUND(total_exec_time::numeric, 2) AS total_ms
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 5;

-- validation: blocked — Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled
```

## Non-SQL or hybrid view
- **MySQL**: `EXPLAIN` and `EXPLAIN ANALYZE` (since 8.0). Format and node types differ but concept is the same. No `pg_stat_statements` equivalent without plugins (Performance Schema).
- **SQL Server**: Execution plan viewer (graphical in SSMS); `SET STATISTICS IO ON` for I/O detail.
- **MongoDB**: `db.collection.explain("executionStats")` — equivalent to EXPLAIN ANALYZE. Shows whether an index was used and how many documents were examined.

## Design principle
**Never guess at a performance problem.** Always measure with EXPLAIN ANALYZE before adding an index or rewriting a query. A seq scan on a 100-row table is fine; the same scan on a 50M-row table is a disaster. EXPLAIN shows the difference.

## Critical thinking
- EXPLAIN (without ANALYZE) is the plan PostgreSQL *would* execute — not what it *did* execute. Estimates can be wildly wrong. Always use ANALYZE for diagnosis.
- `rows=` estimates are only as good as the statistics. Run `ANALYZE` after bulk loads or large updates, or enable `autovacuum` (it runs ANALYZE automatically for tables with significant changes).
- A plan that looks good on a small table may look different at scale. Test with production-representative data sizes.

## Creative thinking
- What if you ran EXPLAIN ANALYZE automatically in CI for every query that runs in integration tests and saved the plan? You'd catch index regressions before they reach production.
- `pev2` (https://explain.dalibo.com/) renders EXPLAIN JSON output as an interactive tree — paste your JSON plan there to visualize it.

## Systems thinking
Query planning interacts with:
- **Table statistics**: `ANALYZE` quality determines plan quality
- **`work_mem`**: Higher value enables in-memory hash joins and sorts, avoiding disk spills
- **`random_page_cost`**: Must reflect actual storage (lower for SSD, default 4.0 for spinning disk)
- **Parallel workers**: `max_parallel_workers_per_gather` controls parallelism for seq scans and joins

Poor plans are rarely the query's fault — they are usually a symptom of stale statistics, wrong cost parameters, or missing indexes.

## MCP and agent perspective
Agents that issue SQL queries should log EXPLAIN output for any query that takes more than a threshold (e.g., 100ms). This creates a feedback loop: slow agent queries are surfaced, diagnosed, and fixed with indexes or query rewrites. Without EXPLAIN visibility, agent-generated slow queries are invisible until they cause user-facing latency.

## Ontology perspective
EXPLAIN exposes the **proof structure** of a query execution. Just as a logical proof has inference steps, a query plan has execution steps, each consuming and producing relations. The cost model is an approximation of the computational cost of each inference step. When the planner's world model (statistics) diverges from reality, its proof structure (plan) becomes suboptimal — analogous to reasoning from false premises.

## Practice session
See `practice/intermediate/03-query-planning/` for exercises reading EXPLAIN output, identifying bad plans, and fixing them with indexes and statistics updates.

## References
- PostgreSQL docs — EXPLAIN: https://www.postgresql.org/docs/16/sql-explain.html
- PostgreSQL docs — Query planner: https://www.postgresql.org/docs/16/planner-optimizer.html
- PostgreSQL docs — Cost parameters: https://www.postgresql.org/docs/16/runtime-config-query.html#RUNTIME-CONFIG-QUERY-CONSTANTS
- PostgreSQL docs — pg_stat_statements: https://www.postgresql.org/docs/16/pgstatstatements.html
- PostgreSQL docs — pg_stat_user_tables: https://www.postgresql.org/docs/16/monitoring-stats.html
- Use The Index, Luke — Execution plans: https://use-the-index-luke.com/sql/explain-plan
- pev2 (plan visualizer): https://explain.dalibo.com/
- depesz.com plan analyzer: https://explain.depesz.com/
