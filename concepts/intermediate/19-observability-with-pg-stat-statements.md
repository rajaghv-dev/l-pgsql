# Observability with pg_stat_statements

Level: Intermediate

## One-line intuition
`pg_stat_statements` is PostgreSQL's built-in query profiler — it tells you exactly which queries are slow, how often they run, and where your database is spending its time.

## Why this exists
Without query-level metrics, database performance problems are invisible. You might know the database is slow, but not which query is responsible, how many times it runs per second, or whether it has improved after an index change. `pg_stat_statements` provides a continuously updated, low-overhead performance ledger for every query shape that has executed.

## First-principles explanation
`pg_stat_statements` is a PostgreSQL extension that hooks into the query executor. Every time a query finishes, it records statistics against a normalized query fingerprint — identical queries differing only in literal values (`WHERE id = 1` vs `WHERE id = 2`) are grouped together. It tracks: total execution time, mean time, call count, rows returned, shared block hits/reads/writes, and more. It survives across sessions but is reset on PostgreSQL restart (unless `pg_stat_statements.save` is on). Normalizing literals is key: it prevents an explosion of entries and lets you see "this query shape ran 10,000 times today."

## Micro-concepts
- **Query normalization** — literal values replaced with `$1`, `$2`; same query shape = same entry regardless of literal values
- **`total_exec_time`** — cumulative wall-clock milliseconds for all calls to this query shape
- **`calls`** — total number of executions
- **`mean_exec_time`** — `total_exec_time / calls` — average latency per call
- **`shared_blks_hit` vs `shared_blks_read`** — buffer cache hits vs disk reads; key for I/O diagnosis
- **`shared_blks_written`** — dirty blocks written; indicates write-heavy queries
- **`wal_bytes`** — WAL bytes generated per query (PG 13+); shows write amplification
- **`queryid`** — integer hash of the normalized query; use to JOIN with pg_stat_activity
- **`toplevel`** — boolean (PG 14+); true if this query was called directly, false if called from a function
- **`pg_stat_statements_reset()`** — clears all accumulated statistics; never run in production without authorization
- **`pg_stat_statements.max`** — GUC for the maximum number of distinct query entries (default 5000)
- **setup script** — requires `shared_preload_libraries = 'pg_stat_statements'` in postgresql.conf; see `scripts/dashboards/enable-pg-stat-statements.sh`

## Beginner view
Think of it like a phone bill that lists every call you made, how long each one lasted, and what it cost — but automatically groups calls to the same number together.

## Intermediate view
The most useful workflow: sort by `total_exec_time DESC` to find the queries consuming the most cumulative database time (not just the slowest individual queries). Then look at `mean_exec_time` for queries with high call counts but moderate mean time — these are high-frequency queries where even small improvements multiply across thousands of calls. Also check `shared_blks_read` to find queries causing heavy disk I/O.

## Advanced view
`pg_stat_statements` uses a fixed-size hash table (`pg_stat_statements.max` entries, default 5000). When full, new query shapes evict old ones — on very diverse workloads you may lose visibility. The `queryid` column is a hash — use it to JOIN with `pg_stat_activity` for live query correlation. In PostgreSQL 14+, `toplevel` column distinguishes top-level calls from calls nested inside functions. `wal_bytes` (PG 13+) shows write amplification per query shape — essential for understanding replication lag sources.

## Mental model
`pg_stat_statements` is a flight data recorder for your database: it continuously logs what happened, and you read it after the fact to diagnose what went wrong — or to prove what you optimized.

## PostgreSQL view
```sql
-- Check if loaded
SELECT * FROM pg_extension WHERE extname = 'pg_stat_statements';

-- View the raw catalog
SELECT queryid, calls, total_exec_time, mean_exec_time, rows, query
FROM pg_stat_statements
LIMIT 5;

-- Reset statistics
SELECT pg_stat_statements_reset();
```

## SQL view
```sql
-- Top 10 queries by total time consumed
SELECT
  calls,
  round(total_exec_time::numeric, 2) AS total_ms,
  round(mean_exec_time::numeric, 2)  AS mean_ms,
  round((100 * total_exec_time / sum(total_exec_time) OVER ())::numeric, 1) AS pct,
  rows,
  left(query, 80) AS query_snippet
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- High-frequency, moderate-latency queries (multiplication effect)
SELECT
  calls,
  round(mean_exec_time::numeric, 2) AS mean_ms,
  round(total_exec_time::numeric, 2) AS total_ms,
  left(query, 80) AS query_snippet
FROM pg_stat_statements
WHERE calls > 1000
ORDER BY calls * mean_exec_time DESC
LIMIT 10;

-- I/O-heavy queries
SELECT
  calls,
  shared_blks_read,
  shared_blks_hit,
  round(100.0 * shared_blks_hit / NULLIF(shared_blks_hit + shared_blks_read, 0), 1) AS hit_pct,
  left(query, 80) AS query_snippet
FROM pg_stat_statements
WHERE shared_blks_read > 0
ORDER BY shared_blks_read DESC
LIMIT 10;

-- blocked: Docker not accessible; validate against cfp_postgres when available
```

## Non-SQL or hybrid view
`pg_stat_statements` works on all query types including those against JSONB columns. If your application uses JSONB document queries, the normalized form will show you `WHERE metadata @> $1` — helping you identify which JSONB operators are most expensive and whether a GIN index would help.

## Design principle
Always install `pg_stat_statements` in production before you need it — retrospective diagnosis is impossible without baseline data, and the overhead (1-5%) is negligible compared to the visibility it provides.

## Critical thinking
`pg_stat_statements` groups queries by normalized text — but two queries with identical text can have wildly different plans depending on bind parameter values (parameter sniffing). How do you detect plan instability that the average metrics hide?

## Creative thinking
Could you build an automated "query regression detector" that compares `pg_stat_statements` snapshots before and after a deployment, alerting when mean execution time for any query increases by more than 20%?

## Systems thinking
`pg_stat_statements` interacts with `pg_stat_activity` (live query correlation), `auto_explain` (getting execution plans for slow queries), `EXPLAIN ANALYZE` (validating individual query plans), and external monitoring tools (pganalyze, pgBadger, Datadog). It is the starting point for every performance investigation — the map before you dig.

## MCP and agent perspective
An AI agent performing database optimization should query `pg_stat_statements` first to prioritize work by impact, not by intuition. Agents must never run `pg_stat_statements_reset()` in production without explicit human approval — resetting baseline data makes before/after comparisons impossible and destroys evidence of ongoing issues.

## Ontology perspective
`pg_stat_statements` is the observability layer of the database ontology. It does not describe what the database IS (schema, tables, types) — it describes how the database BEHAVES (query patterns, resource consumption, frequency). This is the behavioral dimension of the database's self-knowledge.

Each normalized query in `pg_stat_statements` is an ontological event type: "a query of this shape occurs". The statistics are properties of that event type: frequency (calls), cost (total_exec_time), efficiency (hit_pct). Monitoring is the practice of querying the database's ontology of its own behavior.

`pg_stat_statements` answers "what" and "how much" before `EXPLAIN ANALYZE` answers "why". The combination gives a complete observability stack: aggregate patterns → specific query plan → optimization → verification.

## Practice session
See `practice/intermediate/12-observability/` for hands-on exercises analyzing query patterns and pg_stat_activity.

## References
- PostgreSQL docs — pg_stat_statements: https://www.postgresql.org/docs/16/pgstatstatements.html
- PostgreSQL docs — pg_stat_activity: https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW
- PostgreSQL docs — pg_stat_user_tables: https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ALL-TABLES-VIEW
- "Using pg_stat_statements to find slow queries": https://www.citusdata.com/blog/2019/02/08/the-most-useful-postgres-extension-pg-stat-statements/
- pganalyze (managed pg_stat_statements UI): https://pganalyze.com/
- Setup script: `scripts/dashboards/enable-pg-stat-statements.sh` (in this repo)
