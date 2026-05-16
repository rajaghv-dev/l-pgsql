# pg_stat_statements (pg_stat_statements)

Level: Intermediate
Available locally: Yes (requires setup — see below)

## One-line purpose

Track cumulative execution statistics for every distinct SQL query that runs in the database, enabling identification of slow, frequent, or high-variance queries.

## Why this exists

Without pg_stat_statements, diagnosing performance requires either reading slow query logs (which only capture queries above a threshold and don't aggregate) or running `EXPLAIN ANALYZE` manually. pg_stat_statements maintains a ring-buffer of per-query statistics in shared memory, persisting across connections, giving a cumulative view of query cost across all sessions.

## Setup

pg_stat_statements must be loaded before PostgreSQL starts. Run the setup script first:

```bash
# blocked: Docker not accessible
bash scripts/dashboards/enable-pg-stat-statements.sh
```

That script sets `shared_preload_libraries = 'pg_stat_statements'` in `postgresql.conf` and restarts the container.

Then create the extension:

```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
```

Verify it is active:

```sql
-- blocked: Docker not accessible
SELECT pg_stat_statements_reset();  -- clears stats (use carefully in production)
SELECT count(*) FROM pg_stat_statements;
```

## Core operations

### Key columns in `pg_stat_statements`

| Column | Type | Meaning |
|--------|------|---------|
| `query` | text | Normalized query text (literals replaced with `$1`, `$2`) |
| `calls` | bigint | Total number of times this query was executed |
| `total_exec_time` | float8 | Total wall-clock time (ms) across all calls |
| `mean_exec_time` | float8 | Average time per call (ms) |
| `stddev_exec_time` | float8 | Variance; high stddev = inconsistent performance |
| `rows` | bigint | Total rows returned or affected |
| `shared_blks_hit` | bigint | Buffer cache hits (fast) |
| `shared_blks_read` | bigint | Blocks read from disk (slow) |
| `shared_blks_written` | bigint | Blocks written (dirty) |
| `temp_blks_written` | bigint | Temp file writes (sort/hash spills) |
| `wal_bytes` | bigint | WAL bytes generated (write amplification) |
| `dbid` | oid | Database OID |
| `userid` | oid | User OID |

### Find the slowest queries by total time

```sql
-- blocked: Docker not accessible
SELECT
    left(query, 80)                           AS query_snippet,
    calls,
    round(total_exec_time::numeric, 2)        AS total_ms,
    round(mean_exec_time::numeric, 2)         AS mean_ms,
    round(stddev_exec_time::numeric, 2)       AS stddev_ms,
    rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

### Find queries with highest cache miss ratio (I/O pressure)

```sql
-- blocked: Docker not accessible
SELECT
    left(query, 80)                                        AS query_snippet,
    calls,
    shared_blks_hit,
    shared_blks_read,
    round(100.0 * shared_blks_hit /
        NULLIF(shared_blks_hit + shared_blks_read, 0), 1) AS cache_hit_pct
FROM pg_stat_statements
WHERE shared_blks_hit + shared_blks_read > 0
ORDER BY shared_blks_read DESC
LIMIT 20;
```

### Find queries causing temp file spills (sorts/hash joins)

```sql
-- blocked: Docker not accessible
SELECT
    left(query, 80) AS query_snippet,
    calls,
    temp_blks_written,
    round(mean_exec_time::numeric, 2) AS mean_ms
FROM pg_stat_statements
WHERE temp_blks_written > 0
ORDER BY temp_blks_written DESC
LIMIT 10;
```

### Find high-volume write queries (WAL pressure)

```sql
-- blocked: Docker not accessible
SELECT
    left(query, 80)                   AS query_snippet,
    calls,
    wal_bytes,
    round(wal_bytes / 1024.0 / 1024, 2) AS wal_mb
FROM pg_stat_statements
WHERE wal_bytes > 0
ORDER BY wal_bytes DESC
LIMIT 10;
```

### Reset statistics

```sql
-- blocked: Docker not accessible
-- Reset all stats (global reset — use in dev only)
SELECT pg_stat_statements_reset();

-- Reset stats for a specific query (PG 14+)
SELECT pg_stat_statements_reset(
    userid  => (SELECT usesysid FROM pg_user WHERE usename = 'cfp'),
    dbid    => (SELECT oid FROM pg_database WHERE datname = 'cfp'),
    queryid => 12345678  -- from pg_stat_statements.queryid
);
```

### GUC parameters

```sql
-- blocked: Docker not accessible
-- Check current settings
SHOW pg_stat_statements.max;           -- max queries tracked (default 5000)
SHOW pg_stat_statements.track;         -- all | top | none
SHOW pg_stat_statements.track_utility; -- track non-SELECT statements (COPY, VACUUM...)
SHOW pg_stat_statements.save;          -- persist across restarts
```

## Performance characteristics

- Overhead: ~2–5% CPU overhead on write-heavy workloads; negligible on read-heavy
- Memory: `pg_stat_statements.max` × ~5 KB per query slot in shared memory
- Normalization: literals are replaced with `$n` — multiple queries with different literals map to the same entry
- PG 14+ adds `wal_bytes` and per-call planning statistics (`total_plan_time`, `min_plan_time`, `max_plan_time`)
- `queryid` is stable within a major version but may change across upgrades

## When to use

- Baseline query profiling after a schema change or release
- Identifying which queries drive the most I/O before adding indexes
- Monitoring agent write volumes — find unexpected high-frequency INSERTs or UPDATEs
- Pre-`EXPLAIN` triage: sort by `total_exec_time` to decide where to focus optimization effort
- Dashboard: integrate with pgBadger, pganalyze, or Grafana for ongoing visibility

## When NOT to use

- Individual query timing during development — use `EXPLAIN (ANALYZE, BUFFERS)` directly
- Real-time query tracing — use `pg_stat_activity` for currently running queries
- Very high-throughput systems where even 2% CPU overhead matters — consider sampling
- Identifying row-level lock contention — use `pgrowlocks` or `pg_locks` instead

## Alternatives

| Alternative | When to prefer |
|-------------|---------------|
| `auto_explain` | Log full execution plans for slow queries automatically |
| `pg_stat_activity` | See currently executing queries (real-time) |
| pgBadger | Parse PostgreSQL log files for historical analysis |
| pganalyze | SaaS query monitoring with explain plan history |
| Grafana + postgres_exporter | Dashboard-level metrics including statement stats |

## MCP and agent perspective

- **Monitor agent write volumes**: query `pg_stat_statements` filtered by `query ILIKE 'INSERT%'` or `'UPDATE%'` to see if an agent loop is generating unexpected write amplification
- **Query budget**: in multi-agent systems, assign each agent a unique `application_name` (set via `SET application_name = 'agent-x'`) — combine with `pg_stat_activity` to attribute query cost per agent
- **Slow query triage**: after an agent run, check if `mean_exec_time` increased for any query normalized form — signals a missing index or bad plan
- **Safety**: `pg_stat_statements_reset()` should be gated — agents must not be allowed to call it; it destroys baseline data

## Ontology connection

- Lives under `extensions/observability/` — the visibility pillar
- Connects to: `pg_buffercache` (buffer-level detail), `pageinspect` (page-level detail), `pgrowlocks` (lock detail), `auto_explain` (plan detail)
- Concept map: pg_stat_statements → query normalization → queryid → cost aggregation → index tuning decisions

## References

- [PostgreSQL pg_stat_statements docs](https://www.postgresql.org/docs/16/pgstatstatements.html)
- [pganalyze: Using pg_stat_statements](https://pganalyze.com/docs/log-insights/setup/pg-stat-statements)
- [Postgres performance tuning guide](https://www.postgresql.org/docs/16/performance-tips.html)
