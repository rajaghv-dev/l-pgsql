# Performance Ontology

Level: Advanced
Domain: PostgreSQL / Performance

## Definition
PostgreSQL query performance is determined by the interaction of the cost model, table statistics, available indexes, memory allocation, and I/O characteristics — tuning requires understanding all layers together.

## Why this concept matters
Performance problems compound: a slow query blocks connections, which starves the connection pool, which times out the application. Understanding the cost model, statistics pipeline, and scan strategies allows targeted fixes rather than cargo-cult tuning.

## Related concepts
- [[query-ontology]] — parent (the planner uses these concepts to build plans)
- [[index-ontology]] — parent (indexes are the primary performance lever)
- [[transaction-ontology]] — related (vacuum, dead tuples, MVCC overhead)
- [[observability-ontology]] — child (pg_stat_statements surfaces hot queries)
- [[schema-design-ontology]] — related (schema choices constrain performance options)

---

## Cost Model

One-line definition: The planner assigns a unit-less numeric cost to each execution plan and selects the minimum; costs are computed from page counts, row estimates, and configurable cost factors.

### Key GUC parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| `seq_page_cost` | 1.0 | Cost per sequentially read page |
| `random_page_cost` | 4.0 | Cost per randomly accessed page (set to 1.1 for SSD) |
| `cpu_tuple_cost` | 0.01 | Cost per row processed |
| `cpu_index_tuple_cost` | 0.005 | Cost per index entry examined |
| `work_mem` | 4MB | Memory per sort/hash operation; increase for complex queries |
| `effective_cache_size` | 4GB | Planner's estimate of OS cache; larger → more index scans |

```sql
-- blocked: Docker not accessible
SHOW random_page_cost;
SET random_page_cost = 1.1;  -- session-level for SSD
```

---

## Cardinality

One-line definition: The estimated number of rows a plan node will output; the single most consequential input to join ordering and access method selection.

A cardinality error of 10x can flip the join order, switching from a fast hash join to a slow nested loop over millions of rows.

---

## Selectivity

One-line definition: The fraction of rows a predicate is expected to pass (0.0–1.0), derived from column statistics; directly determines whether an index scan is cheaper than a seq scan.

The planner uses a seq scan when selectivity exceeds roughly `1 / random_page_cost` (≈ 25% of rows for default settings).

---

## Statistics and ANALYZE

One-line definition: Per-column summaries stored in `pg_statistic` (most-common values, histogram, null fraction, correlation) that the planner reads to estimate cardinality and selectivity.

```sql
-- blocked: Docker not accessible
-- Refresh statistics on a table
ANALYZE orders;

-- View statistics for a column
SELECT * FROM pg_stats
WHERE tablename = 'orders' AND attname = 'status';

-- Increase statistics target for a high-cardinality column
ALTER TABLE orders ALTER COLUMN customer_id
    SET STATISTICS 500;  -- default: 100; max: 10000
```

Key fields in `pg_stats`:
| Field | Meaning |
|-------|---------|
| `null_frac` | Fraction of NULLs |
| `n_distinct` | Estimated distinct values (negative = fraction of total) |
| `most_common_vals` | Array of most frequent values |
| `most_common_freqs` | Frequency of each MCV |
| `histogram_bounds` | Bucket boundaries for non-MCV values |
| `correlation` | Physical vs logical sort correlation (1.0 = perfectly sorted) |

### Extended Statistics
```sql
-- blocked: Docker not accessible
-- Capture correlation between two columns (avoids over/under estimation)
CREATE STATISTICS stat_orders_user_status
    (dependencies, ndistinct)
    ON user_id, status
    FROM orders;

ANALYZE orders;
```

---

## Seq Scan

One-line definition: Reads the entire table heap sequentially; optimal when most rows match, when the table is small enough to fit in buffer cache, or when no usable index exists.

Cost: `seq_page_cost × relpages + cpu_tuple_cost × reltuples`

Forced seq scan (for testing):
```sql
-- blocked: Docker not accessible
SET enable_indexscan = off;
```

---

## Index Scan

One-line definition: Traverses the index B-tree to find matching TIDs, then fetches heap pages in potentially random order; optimal for high-selectivity predicates.

Cost: `(index_pages × cpu_index_tuple_cost) + (matching_tuples × random_page_cost)`

---

## Sort

One-line definition: Orders rows by specified keys using in-memory quicksort (if within `work_mem`) or external merge sort (spilling to temporary disk files).

Avoiding sorts: A B-tree index on the ORDER BY columns can eliminate the sort node entirely. Check EXPLAIN for `Sort` nodes using `Sort Method: external merge Disk: N kB`.

---

## Hash Join

One-line definition: Builds an in-memory hash table from the smaller (inner) relation, then probes it for each row of the outer relation; best for large, unordered joins.

Memory: Each hash batch uses up to `work_mem`. If the hash table exceeds `work_mem`, PostgreSQL spills to disk in multiple batches. Monitor with:
```sql
-- blocked: Docker not accessible
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;
-- Look for: "Batches: N" (N > 1 means disk spill)
```

---

## Merge Join

One-line definition: Merges two pre-sorted relations by scanning them in parallel; efficient when both inputs are already sorted (e.g., from an index scan or a prior sort).

Requires: Both join sides ordered on the join key. If not sorted, PostgreSQL adds explicit Sort nodes — which may make Hash Join cheaper.

---

## pg_stat_statements

One-line definition: An extension that tracks per-query cumulative execution statistics (total time, calls, rows, I/O) across the entire database, enabling identification of slow or high-frequency queries.

```sql
-- blocked: Docker not accessible
-- Top 10 queries by total execution time
SELECT
    left(query, 80) AS query,
    calls,
    round(total_exec_time::numeric, 2) AS total_ms,
    round(mean_exec_time::numeric, 2) AS avg_ms,
    rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Reset statistics
SELECT pg_stat_statements_reset();
```

Enable: add `pg_stat_statements` to `shared_preload_libraries` in `postgresql.conf`, then `CREATE EXTENSION pg_stat_statements`.

Related: [[observability-ontology]], [[extension-ontology]]

---

## pg_buffercache

One-line definition: An extension that exposes the contents of PostgreSQL's shared buffer cache, showing which relations occupy the most cache and whether pages are dirty.

```sql
-- blocked: Docker not accessible
-- Top relations by buffer cache usage
SELECT c.relname,
       count(*) AS buffers,
       pg_size_pretty(count(*) * 8192) AS cache_size
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
WHERE b.reldatabase = (SELECT oid FROM pg_database WHERE datname = current_database())
GROUP BY c.relname
ORDER BY buffers DESC
LIMIT 20;
```

Related: [[observability-ontology]]

---

## System catalog reference
- `pg_stats` — per-column planner statistics
- `pg_statistic` — raw statistics backing `pg_stats`
- `pg_class.reltuples` / `pg_class.relpages` — table-level estimates
- `pg_stat_statements` — per-query cumulative stats (extension)
- `pg_buffercache` — shared buffer cache contents (extension)
- `pg_stat_user_tables` — table-level vacuum/analyze timestamps and dead tuple counts

---

## Beginner mental model
Performance comes down to: does PostgreSQL have to read every row (slow) or can it jump straight to the matching rows (fast)? Indexes help it jump. ANALYZE keeps the planner's estimates accurate so it makes good jumping decisions.

## Intermediate mental model
The planner estimates rows using statistics. When estimates are wrong, it picks bad plans. After INSERT/UPDATE/DELETE changes more than 10% of a table's rows, run ANALYZE to refresh stats. Increase `work_mem` for queries that sort or hash large datasets — but not globally, only per-session for heavy queries.

## Advanced mental model
Treat performance as a pipeline: statistics accuracy → cardinality → plan selection → execution resource usage. Extended statistics handle correlated columns. `pg_stat_statements` reveals the actual query workload; sort by `total_exec_time` to find the highest-impact targets, not just the slowest individual query. `effective_cache_size` tells the planner how much OS page cache is available — get this from `free -b` and set it correctly; a wrong value biases the planner toward seq scans or index scans incorrectly.

## MCP and agent perspective
An agent with SELECT on `pg_stat_statements` can produce a performance report without any write permissions. Before executing a complex query, an agent should run `EXPLAIN (ANALYZE false, COSTS true)` to estimate cost and flag queries exceeding a threshold for human review. Agents should never run `VACUUM FULL` autonomously — it acquires an exclusive lock and can cause extended downtime.

## Practical implication
| Situation | Implication |
|-----------|-------------|
| Seq scan on a large table for a narrow predicate | Missing index or stale statistics; ANALYZE + add index |
| Hash join spilling to disk (Batches > 1) | Increase `work_mem` for the session |
| Planner chooses nested loop over hash join for large tables | Wrong cardinality estimate; check pg_stats, run ANALYZE |
| Sort using external merge sort | `work_mem` too low; or add an index with matching sort order |
| `pg_stat_statements` not installed | Cannot identify slow queries; install and enable |
| `effective_cache_size` too low | Planner under-estimates available cache; prefers seq scans |

## Obsidian connections
[[query-ontology]] [[index-ontology]] [[transaction-ontology]] [[observability-ontology]] [[schema-design-ontology]]

## References
- PostgreSQL Planner Configuration: https://www.postgresql.org/docs/16/runtime-config-query.html
- pg_stat_statements: https://www.postgresql.org/docs/16/pgstatstatements.html
- pg_buffercache: https://www.postgresql.org/docs/16/pgbuffercache.html
- Extended Statistics: https://www.postgresql.org/docs/16/planner-stats.html#PLANNER-STATS-EXTENDED
