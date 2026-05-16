# Query Ontology

Level: Intermediate
Domain: PostgreSQL / Performance

## Definition
The query lifecycle in PostgreSQL progresses through four phases — parsing, rewriting, planning, and execution — transforming a SQL string into an optimized physical execution plan that retrieves or modifies data.

## Why this concept matters
Every performance problem in PostgreSQL ultimately traces back to one or more query lifecycle phases. Understanding what the planner sees, how it estimates costs, and how the executor materializes results is the prerequisite for effective query tuning and index design.

## Related concepts
- [[sql-ontology]] — parent (SQL statements are the input)
- [[index-ontology]] — child (indexes are the planner's primary tool)
- [[performance-ontology]] — child (cost model, statistics, ANALYZE)
- [[transaction-ontology]] — related (execution occurs inside a transaction snapshot)

---

## Phase 1: Parse

The parser converts the SQL string into an **abstract syntax tree (AST)**, then validates it against the catalog (table names, column names, types).

- Syntax errors are caught here.
- Outputs a **parse tree** (raw AST) and then a **query tree** (after semantic analysis).

---

## Phase 2: Rewrite

The **rule system** applies any `CREATE RULE` rules to the query tree. Views are rewritten here — a query against a view is expanded into a query against the underlying tables.

---

## Phase 3: Plan (Optimize)

The **planner (optimizer)** generates candidate execution plans and selects the one with the lowest estimated cost.

### Planner
One-line definition: The component that converts a query tree into an optimal physical execution plan using cost estimates based on table statistics.

The planner:
1. Enumerates join orderings (for N tables, there are N! orderings; genetic algorithm kicks in above `join_collapse_limit`).
2. Assigns a **cost** to each plan node (startup cost + run cost).
3. Selects the minimum total cost plan.

### Cost model
One-line definition: A unit-less scoring system where sequential page reads cost `seq_page_cost = 1.0` and random page reads cost `random_page_cost = 4.0` by default; these are configurable.

Key cost parameters:
| Parameter | Default | Meaning |
|-----------|---------|---------|
| `seq_page_cost` | 1.0 | Cost per sequential disk page |
| `random_page_cost` | 4.0 | Cost per random disk page |
| `cpu_tuple_cost` | 0.01 | Cost per row processed |
| `cpu_index_tuple_cost` | 0.005 | Cost per index entry touched |
| `cpu_operator_cost` | 0.0025 | Cost per operator evaluation |

For SSDs, set `random_page_cost = 1.1` (nearly equal to sequential).

### Cardinality
One-line definition: The estimated number of rows a plan node will produce; the most impactful single factor in plan quality.

Poor cardinality estimates cascade — a wrong row count at one node skews join order, join method, and memory allocation for the rest of the plan.

### Selectivity
One-line definition: The fraction of rows a predicate is expected to pass; 0.0 (no rows) to 1.0 (all rows); derived from column statistics.

### Statistics
One-line definition: Per-column histogram, most-common values (MCV), and null fraction stored in `pg_statistic`, refreshed by ANALYZE.

```sql
-- blocked: Docker not accessible
-- View column statistics
SELECT * FROM pg_stats WHERE tablename = 'orders' AND attname = 'status';
```

Key fields in `pg_stats`: `n_distinct`, `null_frac`, `most_common_vals`, `most_common_freqs`, `histogram_bounds`, `correlation`.

Related: [[performance-ontology]]

---

## Phase 4: Execute

The **executor** walks the plan tree top-down, pulling rows from child nodes on demand (iterator/volcano model).

### Sequential Scan (Seq Scan)
One-line definition: Reads every page of the table heap in order; chosen when the planner estimates that a large fraction of rows will be returned or no usable index exists.

### Index Scan
One-line definition: Follows the index B-tree to find matching TIDs (tuple identifiers), then fetches the corresponding heap pages — may be non-sequential (random I/O).

### Bitmap Index Scan → Bitmap Heap Scan
One-line definition: Collects all matching TIDs from the index into a bitmap, then fetches heap pages in physical order — better than index scan for medium selectivity.

### Index-Only Scan
One-line definition: Retrieves all needed column values directly from the index without visiting the heap, provided the visibility map shows pages are all-visible.

Related: [[index-ontology]]

---

## Join types (executor level)

### Nested Loop Join
One-line definition: For each row in the outer relation, scans the inner relation for matches; optimal when the inner relation is small or indexed on the join key.

Cost: O(outer × inner) in the worst case.

### Hash Join
One-line definition: Builds an in-memory hash table from the smaller (inner) relation, then probes it for each row of the outer relation; optimal for large, unsorted inputs.

Memory: Controlled by `work_mem`; spills to disk if exceeded.

### Merge Join
One-line definition: Merges two pre-sorted relations side-by-side; efficient when both sides arrive sorted (e.g., from an index scan or explicit sort).

---

## Sort

One-line definition: Orders rows by one or more keys; may use in-memory quicksort or external disk sort depending on `work_mem`.

An index with matching sort order can eliminate a sort node entirely.

---

## Aggregate

One-line definition: Computes aggregate functions (COUNT, SUM, AVG) over groups; can use plain aggregate (sort + group) or hash aggregate (in-memory hash map).

---

## EXPLAIN / EXPLAIN ANALYZE

```sql
-- blocked: Docker not accessible
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT ...;
```

Key fields in output: `cost=startup..total`, `rows=N`, `width=bytes`, `actual time`, `loops`, `Buffers: shared hit/read`.

Related: [[performance-ontology]], [[observability-ontology]]

---

## System catalog reference
- `pg_stats` — per-column statistics used by the planner
- `pg_statistic` — raw statistics (use `pg_stats` view instead)
- `pg_class.reltuples` — estimated row count per table
- `pg_class.relpages` — estimated page count per table
- `pg_am` — index access methods (btree, hash, gin, gist, brin, spgist)

---

## Beginner mental model
When you run a SELECT, PostgreSQL first checks that it's valid SQL, then figures out the best way to get the data (the plan), then actually fetches it. EXPLAIN shows you what plan PostgreSQL chose.

## Intermediate mental model
The planner picks the cheapest plan based on statistics. If statistics are stale (ANALYZE not run recently), cardinality estimates will be wrong and the plan will be suboptimal. EXPLAIN ANALYZE shows both planned and actual row counts — a large difference means stale stats or a skewed distribution.

## Advanced mental model
Planner decisions are deterministic given the same statistics and configuration. To tune, first identify the node with the worst estimate:actual divergence in EXPLAIN ANALYZE. Then: update stats (ANALYZE), increase `default_statistics_target` for the column, use extended statistics (`CREATE STATISTICS`) for correlated columns, or rewrite the query to give the planner better hints (CTEs with MATERIALIZED as optimization fences, `enable_*` GUCs as last resort).

## MCP and agent perspective
An agent can call EXPLAIN on any query it is about to execute to anticipate cost. For production queries, agents should check `EXPLAIN (ANALYZE false)` (no execution, just plan) before submitting expensive mutations. Agents with observability access can query `pg_stat_statements` to find the highest-impact queries and report them for human review.

## Practical implication
| Situation | Implication |
|-----------|-------------|
| Planner chooses seq scan despite index existing | Index is not selective enough, or stats show most rows match |
| Hash join spills to disk | `work_mem` too low; increase per-session or globally |
| Merge join appears on unsorted data | PostgreSQL adds an explicit Sort node above — may cost more than Hash Join |
| Correlated columns not in stats | Planner over-estimates selectivity; use `CREATE STATISTICS` |
| EXPLAIN rows vs actual rows diverge > 10x | Run ANALYZE; increase `default_statistics_target` |

## Obsidian connections
[[sql-ontology]] [[index-ontology]] [[performance-ontology]] [[transaction-ontology]] [[observability-ontology]]

## References
- PostgreSQL Planner: https://www.postgresql.org/docs/16/planner-optimizer.html
- EXPLAIN documentation: https://www.postgresql.org/docs/16/sql-explain.html
- pg_stats view: https://www.postgresql.org/docs/16/view-pg-stats.html
