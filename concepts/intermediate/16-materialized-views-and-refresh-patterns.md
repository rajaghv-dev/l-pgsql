# Materialized Views and Refresh Patterns
Level: Intermediate

## One-line intuition
A materialized view stores the result of a query on disk, giving instant read performance for expensive aggregations at the cost of staleness and manual refresh.

## Why this exists
Some queries are expensive to compute on every request: multi-table aggregations, complex window functions, heavy joins over millions of rows. Materialized views let you pre-compute and cache the result, refreshing on a schedule or trigger rather than re-running the query every time.

## First-principles explanation
A regular view is a named SQL query — every time you SELECT from it, PostgreSQL runs the underlying query. A materialized view (MATVIEW) is different: it runs the query once, stores the result rows physically on disk, and subsequent SELECTs hit those stored rows directly. You can index a materialized view just like a table. The trade-off is that the data can become stale. You control staleness by calling `REFRESH MATERIALIZED VIEW`, either manually, via a cron job, via pg_cron, or triggered by application logic. `REFRESH MATERIALIZED VIEW CONCURRENTLY` allows reads during refresh but requires a unique index on the view.

## Micro-concepts
- **MATVIEW storage**: rows stored in heap pages, just like a table
- **REFRESH**: full recompute; replaces all data atomically (or concurrently with a unique index)
- **CONCURRENTLY**: computes new data alongside old, swaps in diff — no read lock, but slower and requires a unique index
- **Staleness window**: the lag between real data and the cached result
- **Incremental refresh**: not built-in; must be implemented manually or via triggers
- **pg_matviews**: system catalog showing all matviews and their `ispopulated` status
- **ANALYZE after REFRESH**: matview statistics are stale after a refresh; run ANALYZE to update planner stats
- **refresh scheduling**: use external cron, application scheduler, or event-driven logic (pg_cron not available locally)

## Beginner view
Think of it like a spreadsheet you pre-calculated and saved. You don't recalculate every time someone opens it — but you do need to hit "refresh" to pick up new data.

## Intermediate view
Choose between `REFRESH` (fast, locks reads momentarily) and `REFRESH CONCURRENTLY` (no lock, but needs a unique index and is slower). Schedule refreshes based on acceptable staleness — a dashboard showing yesterday's stats can refresh nightly; a near-real-time leaderboard may need pg_cron every minute. Consider whether the cost of refresh (CPU, I/O) is lower than the cost of running the raw query on every request.

## Advanced view
`REFRESH MATERIALIZED VIEW` is not transactional with the source tables — you can get inconsistency between multiple MATVIEWs refreshed separately. The planner sees MATVIEW statistics as a regular table, so stale stats after refresh require `ANALYZE`. Storage bloat is possible if the underlying query grows; `VACUUM` applies. For true incremental refresh, maintain a delta table and merge manually, or use logical decoding to detect changes.

## Mental model
A materialized view is like a printed report: accurate as of print time, fast to read, but must be reprinted to reflect new data.

## PostgreSQL view
```sql
SELECT schemaname, matviewname, ispopulated, definition
FROM pg_matviews;

-- Check last refresh (no built-in timestamp; track via a log table or pg_stat_user_tables)
SELECT relname, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
WHERE relname = 'my_matview';
```

## SQL view
```sql
-- Create
CREATE MATERIALIZED VIEW sales_summary AS
SELECT
  date_trunc('day', created_at) AS day,
  product_id,
  SUM(amount) AS total_amount,
  COUNT(*) AS order_count
FROM orders
GROUP BY 1, 2;

-- Index for CONCURRENTLY refresh
CREATE UNIQUE INDEX ON sales_summary (day, product_id);

-- Refresh blocking reads briefly
REFRESH MATERIALIZED VIEW sales_summary;

-- Refresh without blocking reads (requires unique index)
REFRESH MATERIALIZED VIEW CONCURRENTLY sales_summary;

-- blocked: Docker not accessible; validate against cfp_postgres when available
```

## Non-SQL or hybrid view
Materialized views can store JSONB aggregations, making them useful as a pre-built document cache for API responses. A MATVIEW of `jsonb_agg(row_to_json(t))` grouped by entity type is a cheap read-through cache that the application can query without JSON assembly overhead.

## Design principle
Always create a unique index on any materialized view you intend to refresh concurrently — without it, `REFRESH CONCURRENTLY` is unavailable and you will block reads during refresh in production.

## Critical thinking
If your materialized view refresh takes 30 seconds and runs every 60 seconds, you effectively have 50% of your time in a refresh cycle — is that sustainable, and what happens during refresh failures?

## Creative thinking
Could you chain materialized views — a MATVIEW that selects from another MATVIEW — to build a multi-stage data pipeline inside PostgreSQL? What are the ordering and consistency implications?

## Systems thinking
Materialized views interact with autovacuum (they need vacuuming), the query planner (statistics must be fresh), pg_cron or external schedulers (refresh timing), and connection pooling (refresh is a long-running query that holds a connection).

## MCP and agent perspective
An AI agent querying a materialized view for reporting must understand that results may be stale. Agents should check a `last_refreshed` metadata table before surfacing data to users. Agents must never trigger `REFRESH MATERIALIZED VIEW` without understanding the lock impact and duration on production systems.

## Ontology perspective
A materialized view is a reified query — a query made into an entity. In ontological terms, it materializes a relation (the query's conceptual relationship between entities) into an extension (the physical set of tuples that satisfy it). The refresh cycle is the ontology's "update horizon": how often the materialized world-model is synchronized with the source of truth. Stale matviews represent a known lag in ontological currency — acceptable if the lag is within the domain's change rate.

Materialized views sit between pure views (no storage, queries always current) and tables (full write path, always current). They occupy the "cached projection" niche in the ontology architecture.

## Practice session
See `practice/intermediate/12-observability/` for exercises connecting materialized views with pg_stat_statements for dashboard observability patterns.

## References
- PostgreSQL docs — CREATE MATERIALIZED VIEW: https://www.postgresql.org/docs/16/sql-creatematerializedview.html
- PostgreSQL docs — REFRESH MATERIALIZED VIEW: https://www.postgresql.org/docs/16/sql-refreshmaterializedview.html
- PostgreSQL docs — pg_matviews: https://www.postgresql.org/docs/16/view-pg-matviews.html
- "Materialized Views in PostgreSQL" (2ndQuadrant): https://www.2ndquadrant.com/en/blog/postgresql-materialized-views/
- dbt (data build tool): https://www.getdbt.com/
