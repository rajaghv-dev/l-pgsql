# Cardinality, Selectivity, and Statistics

Level: Advanced

## One-line intuition
The planner's row estimates are only as good as the statistics that feed them — understanding how those statistics are built, when they lie, and how to extend them is the difference between a self-tuning database and one that progressively degrades.

## Why this exists
Wrong row estimates cascade: a 10x overestimate of rows from one scan can cause the planner to choose a hash join over a nested loop, spill to disk, or abandon a perfect index. Statistics are the ground truth the planner reasons from. Knowing how they are built, what they cannot capture, and how to extend them is a core advanced skill.

## First-principles explanation

### Cardinality vs selectivity
- **Cardinality**: the number of distinct values in a column, or the estimated number of rows a node returns.
- **Selectivity**: the fraction of rows that satisfy a predicate. Selectivity ∈ [0, 1]. Estimated rows = table rows × selectivity.

For an equality predicate `WHERE col = X`:
- If X is in the MCV list → selectivity = frequency of X in MCV list
- Otherwise → selectivity = (1 - sum_of_mcv_frequencies) / (n_distinct - count_of_mcv_values)

For a range predicate `WHERE col BETWEEN A AND B`:
- Planner uses histogram bounds to estimate fraction of histogram between A and B

### What ANALYZE collects
`ANALYZE` samples a configurable number of rows (`statistics_target`, default 100 → ~300 sample rows per target value) and builds:

| Statistic | Column in pg_stats | Purpose |
|---|---|---|
| n_distinct | `n_distinct` | Positive = absolute count. Negative = fraction of rows (e.g., -0.5 = 50% distinct) |
| Most common values | `most_common_vals` | Array of top-N values by frequency |
| Most common frequencies | `most_common_freqs` | Frequencies matching MCVs |
| Histogram bounds | `histogram_bounds` | Equal-frequency bucket boundaries for range estimation |
| Correlation | `correlation` | Pearson correlation of physical vs logical order. 1.0 = perfectly sorted. Near 0 = random order (index scans expensive) |
| Null fraction | `null_frac` | Fraction of rows where column IS NULL |

### When statistics mislead the planner

**1. Multi-column correlation**: Two columns are correlated (e.g., `city` and `zip_code`), but the planner treats predicates on each as independent. It multiplies selectivities, underestimating the result.
```
Estimated: 0.01 × 0.01 = 0.0001 (100 rows)
Actual: 0.01 (10,000 rows) — because city=X implies zip=Y
```

**2. Data skew past MCV list**: A value outside the top-N MCVs is assigned the uniform "other" selectivity, even if it is actually very common. Raise statistics_target to include it.

**3. Functional dependencies**: `WHERE country = 'US' AND state = 'CA'` — state already implies country, but planner doesn't know this.

**4. Stale statistics**: High insert/delete rate between ANALYZE runs. `n_live_tup` in `pg_stat_user_tables` drifts from reality.

**5. Expressions**: `WHERE lower(email) = 'foo@bar.com'` — the planner has no statistics on the expression result (unless you create an expression index, which triggers statistics on the index itself).

### Extended statistics (CREATE STATISTICS)
PostgreSQL 10+ allows defining multi-column statistics that the planner can use:

```sql
-- blocked: Docker not accessible
-- Functional dependency statistics
CREATE STATISTICS orders_city_zip (dependencies) ON city, zip FROM customers;

-- MCV list for column combination
CREATE STATISTICS orders_status_type (mcv) ON status, order_type FROM orders;

-- N-distinct estimate for combined column
CREATE STATISTICS orders_ndistinct (ndistinct) ON customer_id, product_id FROM order_items;

ANALYZE customers;
ANALYZE orders;
```

After creating extended statistics and running ANALYZE, the planner uses them automatically.

### The statistics_target parameter
Default: 100. Affects:
- MCV list size: ~statistics_target entries
- Histogram buckets: ~statistics_target buckets
- Sample size for ANALYZE: `300 × statistics_target` rows

Set per-column for selective tuning:
```sql
-- blocked: Docker not accessible
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500;
ANALYZE orders (status);
```

Set globally: `default_statistics_target = 200` (good starting point for analytical workloads).

## Micro-concepts
- **n_distinct = -1**: every row has a unique value (e.g., primary key). Estimated by sampling.
- **correlation near 1.0**: data is physically sorted → index scans are cheap (sequential IO pattern). Near 0 → random IO → planner prefers seq scan for large result sets.
- **pg_stats**: the human-readable view over `pg_statistic`. Each row = one (table, column) pair.
- **ANALYZE table (col1, col2)**: analyze only specific columns (fast, targeted).
- **stattarget = -1**: reset to default.
- **row estimate vs actual**: visible in `EXPLAIN (ANALYZE)`. Deviation > 10x warrants investigation.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Run ANALYZE occasionally to keep queries fast.

**Intermediate view**: When a query is slow and EXPLAIN shows a bad plan, check if estimated rows match actual. If not, run ANALYZE or raise statistics_target.

**Advanced view**: Statistics are a lossy compression of data distribution. MCV lists and histograms are finite approximations. Multi-column predicates require extended statistics (`CREATE STATISTICS`) because the planner's independence assumption is almost always wrong for real-world schemas. Correlation impacts physical IO patterns, not just plan selection — a table with correlation=0 on an indexed column requires random IO per index lookup, making seq scan competitive even for 5% selectivity. Stale statistics from delayed autovacuum is a common root cause of production plan regressions.

## Mental model
Imagine the planner as a navigator using a paper map (statistics) that was printed last month. If the roads (data distribution) haven't changed, the map is accurate. If new neighborhoods (values) appeared, the map has blank spots and the navigator will estimate distances wrong. `ANALYZE` reprints the map. `statistics_target` determines how many streets the map shows. `CREATE STATISTICS` adds a layer of the map that shows how neighborhoods relate to each other.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_stats`, `pg_statistic`, `pg_statistic_ext` (extended stats), `pg_stat_user_tables` (analyze timestamps).

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Check statistics for a table
SELECT attname, null_frac, n_distinct, correlation,
       array_length(most_common_vals::text[], 1) AS mcv_count
FROM pg_stats
WHERE tablename = 'orders'
ORDER BY attname;

-- Check when table was last analyzed
SELECT relname, last_analyze, last_autoanalyze, n_live_tup, n_dead_tup,
       n_mod_since_analyze
FROM pg_stat_user_tables
WHERE relname = 'orders';

-- List extended statistics
SELECT stxname, stxkeys, stxkind FROM pg_statistic_ext;
```

**Non-SQL / hybrid view**: `auto_explain` logs `EXPLAIN ANALYZE` for slow queries — collect rows estimates vs actual over time to build a regression model. Prometheus + PostgreSQL exporter can track `pg_stat_user_tables.n_mod_since_analyze` as a staleness signal.

## Design principle
**Statistics are a contract between the schema designer and the planner**: when you design a schema, you are implicitly committing to a data distribution the planner will model. Schemas with high cardinality uniform columns (UUIDs, timestamps) work well out of the box. Schemas with multi-column dependencies, temporal clustering, or high-skew categorical columns need explicit statistics management — extended statistics, higher targets, and more frequent ANALYZE.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: `CREATE STATISTICS` only helps for the specific column combinations you define. You cannot define statistics for all possible combinations, so coverage is always incomplete. The planner also cannot use extended statistics for subquery results, CTEs, or dynamically generated predicates from function calls.

**Creative**: Expression indexes are a backdoor for expression statistics. `CREATE INDEX ON orders (lower(email))` causes PostgreSQL to collect statistics on `lower(email)` as part of index creation and maintenance. The planner then uses these statistics for predicates `WHERE lower(email) = ...`. This is a useful pattern when you cannot use extended statistics.

**Systems**: Autovacuum's ANALYZE trigger (`autovacuum_analyze_threshold + autovacuum_analyze_scale_factor × n_live_tup` changed rows) is designed for general workloads, not analytical columns with extreme skew. Tables with billions of rows and 0.01% change threshold need custom autovacuum settings per-table. A monitoring alert on `n_mod_since_analyze / n_live_tup > 0.1` (10% of table changed since last analyze) catches this before plan degradation.

## MCP and agent perspective
Agents that store embeddings or structured metadata in PostgreSQL create new data distributions that autovacuum and default statistics are not tuned for. An agent session that inserts 10,000 rows in a burst may invalidate the statistics on columns the planner uses for embedding search predicates. A self-optimizing agent can call `ANALYZE <table>` after bulk inserts, log the estimated vs actual row counts from EXPLAIN output, and escalate to a DBA when deviation exceeds a threshold.

## Ontology perspective
Statistics encode a probabilistic model of data distribution. The planner is a reasoner operating under uncertainty — its plan is the maximum-likelihood action given the model. Extended statistics extend the model's expressivity from independent marginals to joint distributions (for selected column pairs). This is an instance of the general trade-off between model complexity and tractability: richer models give better estimates but require more data and computation to maintain.

## Practice session

**Exercise 1 — Inspect multi-column statistics**: Look for tables where extended statistics would help.
```sql
-- blocked: Docker not accessible
-- Find columns with possible correlation (narrow cardinality)
SELECT tablename, attname, n_distinct, correlation
FROM pg_stats
WHERE tablename IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public')
ORDER BY abs(correlation) DESC NULLS LAST;
```

**Exercise 2 — Create extended statistics**: For a table with correlated columns.
```sql
-- blocked: Docker not accessible
CREATE STATISTICS IF NOT EXISTS stat_orders_status_customer
  (dependencies, mcv)
  ON status, customer_id
  FROM orders;
ANALYZE orders;
```

**Exercise 3 — Trigger stale statistics**: Insert many rows and watch n_mod_since_analyze.
```sql
-- blocked: Docker not accessible
SELECT relname, n_mod_since_analyze, n_live_tup FROM pg_stat_user_tables WHERE relname = 'orders';
-- Insert 1000 rows
INSERT INTO orders SELECT ... ;
SELECT relname, n_mod_since_analyze, n_live_tup FROM pg_stat_user_tables WHERE relname = 'orders';
```

**Exercise 4 — Compare plans before/after higher statistics target**:
```sql
-- blocked: Docker not accessible
EXPLAIN SELECT * FROM orders WHERE status = 'pending';
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500;
ANALYZE orders (status);
EXPLAIN SELECT * FROM orders WHERE status = 'pending';
```

**Exercise 5 — Expression statistics via index**:
```sql
-- blocked: Docker not accessible
CREATE INDEX idx_orders_lower_email ON customers (lower(email));
ANALYZE customers;
SELECT most_common_vals FROM pg_stats
WHERE tablename = 'idx_orders_lower_email';
```

## References
- PostgreSQL Documentation: [pg_stats](https://www.postgresql.org/docs/16/view-pg-stats.html)
- PostgreSQL Documentation: [CREATE STATISTICS](https://www.postgresql.org/docs/16/sql-createstatistics.html)
- PostgreSQL Documentation: [Row Estimation Examples](https://www.postgresql.org/docs/16/row-estimation-examples.html)
- PostgreSQL Documentation: [Planner Statistics](https://www.postgresql.org/docs/16/planner-stats.html)
- Laurenz Albe: [PostgreSQL Statistics and the Query Planner](https://www.cybertec-postgresql.com/en/postgresql-statistics-and-the-query-planner/)
- Hironobu Suzuki: [The Internals of PostgreSQL, Chapter 3](https://www.interdb.jp/pg/pgsql03.html)
