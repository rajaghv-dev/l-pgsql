# PostgreSQL Observability Example

Level: Intermediate
Domain: Querying system catalog views for performance monitoring and bloat detection
Synthetic data: Yes (queries read real pg_ views; example output is illustrative)

## Overview

This example shows how to observe a running PostgreSQL instance using built-in
system catalog views. No custom tables are required — the data source is PostgreSQL's
own instrumentation. Covers:

- `pg_stat_user_tables` — table-level access and dead-tuple statistics
- `pg_stat_user_indexes` — index usage and scan counts
- `pg_stat_activity` — active connections and currently running queries
- `pg_stat_statements` — top slow queries (requires separate setup)

These queries are read-only and safe to run on any live PostgreSQL instance.

## Prerequisites

The views used here require:
- `pg_stat_statements` loaded in `shared_preload_libraries` (see setup note below)
- The standard statistics collector, which is enabled by default in PostgreSQL 16

### pg_stat_statements setup

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- Step 1: add to postgresql.conf
-- shared_preload_libraries = 'pg_stat_statements'
-- pg_stat_statements.track = all

-- Step 2: restart PostgreSQL, then:
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Step 3: verify
SELECT * FROM pg_stat_statements LIMIT 1;
```

In the cfp_postgres container, pg_stat_statements is pre-configured via the
`scripts/01-setup-pg-stat-statements.sql` setup script in this repo.

## Schema

No custom tables. All queries run against built-in system views.

## Seed data

No seed data required. Run `pgbench` or execute normal queries to populate
statistics. Example to generate activity:

```sql
-- Run this a few times to populate pg_stat_user_tables for the target database:
-- pgbench -i -s 10 mydb      (initialise)
-- pgbench -c 5 -T 30 mydb   (30 seconds of load)
```

## Example queries

### Table access statistics

```sql
-- Shows sequential vs index scans, rows read, and dead tuples
SELECT relname                    AS table_name,
       seq_scan,
       seq_tup_read,
       idx_scan,
       idx_tup_fetch,
       n_live_tup,
       n_dead_tup,
       ROUND(
         n_dead_tup::NUMERIC /
         NULLIF(n_live_tup + n_dead_tup, 0) * 100, 1
       )                          AS dead_pct
FROM   pg_stat_user_tables
ORDER  BY n_dead_tup DESC;
```

### Tables with high bloat (dead tuple ratio > 10%)

```sql
SELECT relname          AS table_name,
       n_live_tup,
       n_dead_tup,
       ROUND(
         n_dead_tup::NUMERIC /
         NULLIF(n_live_tup + n_dead_tup, 0) * 100, 1
       )                AS dead_pct,
       last_autovacuum,
       last_autoanalyze
FROM   pg_stat_user_tables
WHERE  n_dead_tup > 0
  AND  n_dead_tup::NUMERIC /
       NULLIF(n_live_tup + n_dead_tup, 0) > 0.10
ORDER  BY dead_pct DESC;
```

### Index usage — find unused indexes

```sql
-- Indexes that have never been scanned (candidates for removal)
SELECT schemaname,
       relname       AS table_name,
       indexrelname  AS index_name,
       idx_scan,
       idx_tup_read,
       idx_tup_fetch
FROM   pg_stat_user_indexes
WHERE  idx_scan = 0
ORDER  BY relname, indexrelname;
```

### Most-used indexes

```sql
SELECT relname      AS table_name,
       indexrelname AS index_name,
       idx_scan,
       idx_tup_read,
       idx_tup_fetch
FROM   pg_stat_user_indexes
ORDER  BY idx_scan DESC
LIMIT  10;
```

### Active connections and queries

```sql
-- Current sessions: who is connected and what are they doing?
SELECT pid,
       usename,
       application_name,
       state,
       wait_event_type,
       wait_event,
       ROUND(EXTRACT(EPOCH FROM (NOW() - query_start))::NUMERIC, 1) AS running_secs,
       LEFT(query, 80)                                              AS query_snippet
FROM   pg_stat_activity
WHERE  state <> 'idle'
ORDER  BY running_secs DESC NULLS LAST;
```

### Long-running queries (over 30 seconds)

```sql
SELECT pid,
       usename,
       state,
       ROUND(EXTRACT(EPOCH FROM (NOW() - query_start))::NUMERIC, 1) AS running_secs,
       query
FROM   pg_stat_activity
WHERE  state = 'active'
  AND  query_start < NOW() - INTERVAL '30 seconds'
ORDER  BY running_secs DESC;
```

### Terminate a specific long-running query (use with caution)

```sql
-- SELECT pg_terminate_backend(<pid>);
-- Only terminate queries you own unless you are a superuser.
```

### Top 5 slowest queries via pg_stat_statements

```sql
-- Requires pg_stat_statements extension
SELECT
    LEFT(query, 100)                         AS query_snippet,
    calls,
    ROUND(mean_exec_time::NUMERIC, 2)        AS avg_ms,
    ROUND(total_exec_time::NUMERIC, 2)       AS total_ms,
    ROUND(stddev_exec_time::NUMERIC, 2)      AS stddev_ms,
    rows
FROM   pg_stat_statements
ORDER  BY mean_exec_time DESC
LIMIT  5;
```

### Queries with highest total execution time

```sql
SELECT
    LEFT(query, 100)                         AS query_snippet,
    calls,
    ROUND(total_exec_time::NUMERIC, 2)       AS total_ms,
    ROUND(mean_exec_time::NUMERIC, 2)        AS avg_ms
FROM   pg_stat_statements
ORDER  BY total_exec_time DESC
LIMIT  10;
```

### Cache hit ratio per table

```sql
-- A ratio below 0.95 may indicate the shared_buffers setting is too small
SELECT relname AS table_name,
       heap_blks_read,
       heap_blks_hit,
       ROUND(
         heap_blks_hit::NUMERIC /
         NULLIF(heap_blks_hit + heap_blks_read, 0), 4
       ) AS cache_hit_ratio
FROM   pg_statio_user_tables
ORDER  BY heap_blks_read DESC;
```

### Database-level size and connection count

```sql
SELECT datname,
       pg_size_pretty(pg_database_size(datname)) AS db_size,
       numbackends                               AS connections
FROM   pg_stat_database
WHERE  datname NOT IN ('template0','template1','postgres')
ORDER  BY pg_database_size(datname) DESC;
```

### Table sizes (including indexes and toast)

```sql
SELECT relname          AS table_name,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
       pg_size_pretty(pg_relation_size(relid))       AS table_only_size,
       pg_size_pretty(
         pg_total_relation_size(relid) - pg_relation_size(relid)
       )                                             AS index_toast_size
FROM   pg_stat_user_tables
ORDER  BY pg_total_relation_size(relid) DESC
LIMIT  20;
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- 1. pg_stat_user_tables is accessible
SELECT COUNT(*) FROM pg_stat_user_tables;

-- 2. pg_stat_activity works
SELECT COUNT(*) FROM pg_stat_activity;

-- 3. pg_stat_statements is available (will error if extension not created)
SELECT COUNT(*) FROM pg_stat_statements;

-- 4. Current database shows in pg_stat_database
SELECT datname FROM pg_stat_database WHERE datname = current_database();
```

## Practice tasks

1. **Bloat simulation.** On a test table, run 1000 UPDATEs without VACUUM. Observe
   `n_dead_tup` in `pg_stat_user_tables`. Run `VACUUM` and watch the count drop.

2. **Index audit.** After running the schema from another example (e.g. library-catalog),
   list all indexes using `pg_stat_user_indexes`. Identify any that have `idx_scan = 0`.
   What does that tell you?

3. **Long query detection.** Open a second psql session and run
   `SELECT pg_sleep(60)`. In your primary session, run the long-running query
   detection query. Can you see it? Then terminate it with `pg_terminate_backend`.

4. **Cache hit ratio.** Load the ecommerce example seed data, run several SELECT
   queries, then check `pg_statio_user_tables`. Is the cache hit ratio close to 1.0?
   What would a low ratio indicate?

5. **pg_stat_statements reset.** Run `SELECT pg_stat_statements_reset()`. Then run
   10 queries against any table. Check `pg_stat_statements` to see your queries
   accumulate. Why is `calls` useful alongside `mean_exec_time`?

## MCP and agent perspective

An observability agent using this schema via MCP would:

- **Monitor automatically** — poll `pg_stat_activity` every minute to detect
  long-running or blocked queries without human intervention.
- **Alert on bloat** — run the dead-tuple query and alert when any table exceeds
  a 15% dead-tuple ratio, triggering a VACUUM recommendation.
- **Identify slow queries** — query `pg_stat_statements` after load tests to
  surface the top-5 slowest queries for optimization.
- **Track unused indexes** — weekly audit of `pg_stat_user_indexes` finds
  indexes that add write overhead without benefiting reads.
- **Report database health** — cache hit ratio + connection count + bloat
  percentage give a concise daily health summary.

An agent has read-only access to all `pg_stat_*` views without special privileges
beyond `pg_monitor` role membership (PostgreSQL 10+).

## Teardown

No teardown needed — this example creates no tables. To reset pg_stat_statements:

```sql
SELECT pg_stat_statements_reset();
```

## References

- pg_stat_user_tables: https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ALL-TABLES-VIEW
- pg_stat_activity: https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW
- pg_stat_statements: https://www.postgresql.org/docs/current/pgstatstatements.html
- pg_statio_user_tables: https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STATIO-ALL-TABLES-VIEW
- Routine Vacuuming: https://www.postgresql.org/docs/current/routine-vacuuming.html
