# Planner, Executor, and Cost Model

Level: Advanced

## One-line intuition
The PostgreSQL query planner is a cost-based optimizer that estimates the cheapest plan by assigning numeric costs to every operation — and the executor blindly trusts whatever plan the planner produces.

## Why this exists
SQL is declarative: you describe *what* you want, not *how* to get it. The planner translates intent into a physical execution plan — choosing which indexes to use, which join algorithm to apply, in what order to join tables. A bad plan can make a query 1000x slower than the optimal one. Understanding the cost model lets you diagnose bad plans, provide hints, and write queries the planner can reason about.

## First-principles explanation

### Cost model fundamentals
Every node in a plan tree has two cost estimates:
- **startup cost**: cost to return the first row (important for `LIMIT` queries)
- **total cost**: cost to return all rows

Cost is unitless and relative. The base unit is one sequential page read, defined as `seq_page_cost = 1.0`. All other costs are multipliers:

| Parameter | Default | Meaning |
|---|---|---|
| `seq_page_cost` | 1.0 | Cost per sequential page read |
| `random_page_cost` | 4.0 | Cost per random page read (SSD: set to 1.1-2.0) |
| `cpu_tuple_cost` | 0.01 | Cost per row processed |
| `cpu_index_tuple_cost` | 0.005 | Cost per index entry scanned |
| `cpu_operator_cost` | 0.0025 | Cost per operator evaluation |
| `parallel_tuple_cost` | 0.1 | Extra cost per row for parallel workers |
| `parallel_setup_cost` | 1000.0 | Fixed cost to start parallel execution |

A sequential scan of a 10,000-page table: cost ≈ 10,000 × 1.0 = 10,000 units.
An index scan fetching 100 random pages: cost ≈ 100 × 4.0 + 100 × 0.005 = 400.5 units.

The planner generates all legal plans (within reason) and picks the lowest total cost. For complex queries with many join combinations, it uses dynamic programming and heuristics to avoid exponential search.

### Statistics (pg_statistic)
The planner estimates row counts using statistics collected by `ANALYZE`:
- **n_distinct**: estimated number of distinct values
- **most common values (MCVs)**: top-N values and their frequencies (stavalues, stanumbers)
- **histogram bounds**: equal-frequency buckets for range selectivity estimates
- **correlation**: how well physical order correlates with logical order (impacts index vs seq scan decision)

```sql
-- blocked: Docker not accessible
-- Inspect raw statistics for a column
SELECT attname, n_distinct, correlation
FROM pg_stats
WHERE tablename = 'orders' AND attname = 'status';
```

### Join algorithms
| Algorithm | Best when | Startup cost | Memory |
|---|---|---|---|
| Nested Loop | Small inner table or index on join key | Low | Low |
| Hash Join | Large unsorted inputs, equality joins | Medium (build hash table) | `work_mem` |
| Merge Join | Both inputs pre-sorted on join key | Medium (sort step) | `work_mem` for sort |

The planner considers all three for each join pair and picks the cheapest combination.

### Reading EXPLAIN output
```sql
-- blocked: Docker not accessible
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT * FROM orders WHERE status = 'pending';
```
Key fields:
- `cost=X..Y` — startup cost .. total cost
- `rows=N` — planner's row estimate
- `actual rows=M` — executor's actual count (with ANALYZE)
- `width=W` — estimated average row width in bytes
- `Buffers: shared hit=H read=R` — buffer cache hits vs disk reads
- `loops=L` — how many times this node executed (in a nested loop, inner node loops)

A large difference between `rows=N` and `actual rows=M` signals a statistics problem.

### Plan-shape knobs
These GUCs disable specific algorithms (useful for debugging, not production):
```
enable_seqscan = off      -- force index scans
enable_indexscan = off    -- force seq scan
enable_hashjoin = off     -- test merge or nested loop
enable_mergejoin = off
enable_nestloop = off
enable_parallel_query = off
```

## Micro-concepts
- **plan cache**: `PREPARE` + `EXECUTE` caches a plan. Generic plans are used after 5 executions. Generic plans may be suboptimal for skewed data.
- **effective_cache_size**: not actual memory — a hint to the planner about how much OS page cache is available. Affects index vs seq scan decisions.
- **work_mem**: memory per sort or hash table operation. Set too low → spill to disk. Set too high × many connections → OOM.
- **join_collapse_limit**: controls how aggressively the planner reorders explicit JOIN clauses (default 8).
- **geqo**: genetic query optimizer, kicks in for >8-way joins to avoid combinatorial explosion.
- **parallel workers**: the planner can generate parallel plans if `max_parallel_workers_per_gather` > 0 and the table is large enough.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: The database figures out how to run your query automatically.

**Intermediate view**: Use EXPLAIN to see the plan. High cost + many rows = potential index opportunity. Mismatched actual vs estimated rows signals stale statistics; run ANALYZE.

**Advanced view**: The planner's cost model is a linear regression over statistics that are sampled and bucketed — it is an approximation. Multi-column correlations are invisible to single-column statistics (solved by `CREATE STATISTICS`). The cost model is calibrated for spinning disks by default (`random_page_cost=4.0`); on NVMe, set it to 1.1. Plan caching for prepared statements can lock in a bad generic plan. Parallel plans introduce coordination overhead that can hurt short queries. The executor is not adaptive — it commits to the plan at execution start and cannot switch strategies mid-query (unlike some HTAP databases).

## Mental model
The planner is a real estate agent comparing neighborhoods by a scoring formula. The formula uses historical data (statistics) about property density (row counts), price per mile (page costs), and transport options (indexes). The executor is the moving truck — it follows the chosen route without question. If the historical data is wrong (stale statistics, unusual data distribution), the agent picks a bad neighborhood and the truck takes the slow road.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_stats`, `pg_statistic`, `pg_stat_user_tables` (for statistics age). The `EXPLAIN` command is the primary interface. `pg_prepared_statements` shows cached plan metadata.

**SQL view**:
```sql
-- blocked: Docker not accessible
-- See plan for a specific query
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) SELECT o.id, c.name
FROM orders o JOIN customers c ON o.customer_id = c.id
WHERE o.created_at > now() - interval '7 days';

-- Check statistics age
SELECT schemaname, relname, last_analyze, last_autoanalyze, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
ORDER BY last_analyze NULLS FIRST;

-- Force statistics refresh
ANALYZE orders;
```

**Non-SQL / hybrid view**: `pgBadger` parses PostgreSQL logs to surface slow queries. `explain.depesz.com` visualizes EXPLAIN output as a color-coded tree. `auto_explain` extension logs plans for queries exceeding a threshold (`log_min_duration`).

## Design principle
**Cost-based optimization with statistics as the ground truth**: The planner trusts statistics more than query structure. If your statistics are wrong, no amount of query rewriting will help — fix the statistics or the data distribution. Tuning `statistics_target` (default 100, max 10000) on skewed columns gives the planner more MCVs and histogram buckets to work with.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: The cost model has known blind spots: correlation between columns (fixed by `CREATE STATISTICS`), functions in WHERE clauses (planner assumes 0.5% selectivity for unknown functions), and partition pruning for dynamic values. The planner is also deterministic — given the same statistics, it always produces the same plan, so a bad plan will repeat indefinitely until statistics change.

**Creative**: You can use `EXPLAIN` as a unit test for query plans in CI. Run `EXPLAIN (FORMAT JSON)` and parse the JSON in a script. Assert that specific node types appear (e.g., "Index Scan" not "Seq Scan") for performance-critical queries. This catches regressions before production.

**Systems**: Plan quality degrades over time as data grows and distribution shifts. Autovacuum triggers ANALYZE based on tuple changes, but a table with a skewed hot column may need a scheduled `ANALYZE col_name` with a higher statistics_target. The planner is downstream of autovacuum: autovacuum health → statistics freshness → plan quality → query performance. Optimizing query performance without monitoring autovacuum is solving the symptom.

## MCP and agent perspective
AI agents that generate SQL dynamically face a compounded risk: not only may the generated SQL be logically incorrect, it may also be planned inefficiently. Agent-generated queries often use bind parameters (preventing the planner from seeing literals) or constructed JOINs in unusual order. Mitigation: agents should run `EXPLAIN` before executing expensive queries and abort if cost exceeds a threshold. A meta-agent that analyzes `EXPLAIN` output and rewrites the query is a practical pattern for self-healing agent SQL pipelines.

## Ontology perspective
The cost model is an epistemological artifact: it represents the planner's *belief* about data distribution, encoded in statistics. Like all beliefs derived from samples, it can be wrong — systematically, not randomly — when data is skewed or multi-modal. Extended statistics (`CREATE STATISTICS`) expand the planner's ontology to include multi-column correlations, moving it from univariate beliefs toward a richer joint distribution model.

## Practice session

**Exercise 1 — Read a plan**: Run EXPLAIN on a query with a join and find the join algorithm chosen.
```sql
-- blocked: Docker not accessible
EXPLAIN SELECT * FROM orders o JOIN customers c ON o.customer_id = c.id LIMIT 10;
```

**Exercise 2 — Statistics inspection**: Check selectivity for a column.
```sql
-- blocked: Docker not accessible
SELECT tablename, attname, n_distinct, most_common_vals, histogram_bounds
FROM pg_stats
WHERE tablename = 'orders';
```

**Exercise 3 — Tune random_page_cost**: If using SSDs, adjust and observe plan changes.
```sql
-- blocked: Docker not accessible
SET random_page_cost = 1.1;
EXPLAIN SELECT * FROM orders WHERE status = 'pending';
-- Compare with default 4.0
```

**Exercise 4 — Statistics target**: Increase statistics for a skewed column.
```sql
-- blocked: Docker not accessible
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500;
ANALYZE orders;
SELECT most_common_vals, most_common_freqs FROM pg_stats
WHERE tablename = 'orders' AND attname = 'status';
```

**Exercise 5 — Spot row estimate mismatch**: Run EXPLAIN ANALYZE and compare estimated vs actual rows on a WHERE clause.
```sql
-- blocked: Docker not accessible
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE customer_id = 42;
```

## References
- PostgreSQL Documentation: [Using EXPLAIN](https://www.postgresql.org/docs/16/using-explain.html)
- PostgreSQL Documentation: [Planner Cost Constants](https://www.postgresql.org/docs/16/runtime-config-query.html#RUNTIME-CONFIG-QUERY-CONSTANTS)
- PostgreSQL Documentation: [Row Estimation Examples](https://www.postgresql.org/docs/16/row-estimation-examples.html)
- PostgreSQL Documentation: [Extended Statistics](https://www.postgresql.org/docs/16/sql-createstatistics.html)
- Depesz EXPLAIN visualizer: https://explain.depesz.com/
- Hironobu Suzuki: [The Internals of PostgreSQL, Chapter 3 — Query Processing](https://www.interdb.jp/pg/pgsql03.html)
