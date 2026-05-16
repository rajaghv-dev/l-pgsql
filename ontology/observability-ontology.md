# Observability Ontology

Level: Intermediate → Advanced
Domain: PostgreSQL / Observability

## Definition
PostgreSQL observability is the ability to understand the internal state, performance, and behavior of a running database instance through its built-in statistics views, extensions, and external monitoring tools.

## Why this concept matters
You cannot optimize what you cannot measure. PostgreSQL exposes rich telemetry through the `pg_stat_*` family of views — but that data is only useful if you know what each view means, how to query it, and how to correlate signals across views to diagnose problems. Connecting PostgreSQL to Prometheus and Grafana turns this into proactive alerting.

## Related concepts
- [[performance-ontology]] — parent (observability data drives performance tuning)
- [[query-ontology]] — related (EXPLAIN produces per-query telemetry)
- [[transaction-ontology]] — related (pg_stat_activity, pg_locks reveal transaction state)
- [[security-ontology]] — related (audit logs, monitoring privilege grants)
- [[extension-ontology]] — related (pg_stat_statements, pg_buffercache are extensions)

---

## pg_stat_statements

One-line definition: An extension that tracks cumulative execution statistics per normalized query across all databases, enabling identification of the most expensive query shapes.

```sql
-- blocked: Docker not accessible
-- Enable (requires shared_preload_libraries = 'pg_stat_statements' in postgresql.conf)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Top 10 by total execution time
SELECT
    left(query, 100)            AS query,
    calls,
    round(total_exec_time::numeric, 1) AS total_ms,
    round(mean_exec_time::numeric, 2)  AS avg_ms,
    round(stddev_exec_time::numeric, 2) AS stddev_ms,
    rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Top by I/O time
SELECT left(query, 100), blk_read_time + blk_write_time AS io_ms
FROM pg_stat_statements
ORDER BY io_ms DESC LIMIT 10;

-- Reset
SELECT pg_stat_statements_reset();
```

Key columns: `query`, `calls`, `total_exec_time`, `mean_exec_time`, `stddev_exec_time`, `rows`, `shared_blks_hit`, `shared_blks_read`, `blk_read_time`, `blk_write_time`.

Related: [[performance-ontology]], [[extension-ontology]]

---

## pg_stat_activity

One-line definition: A built-in view showing one row per server process with its current state, query text, wait event, client, and transaction start time.

```sql
-- blocked: Docker not accessible
-- All active (non-idle) sessions
SELECT pid, usename, application_name, client_addr,
       state, wait_event_type, wait_event,
       now() - query_start AS query_age,
       left(query, 80) AS query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;

-- Long-running queries (> 30 seconds)
SELECT pid, now() - query_start AS age, state, query
FROM pg_stat_activity
WHERE state = 'active'
  AND query_start < now() - interval '30 seconds';

-- Terminate a specific backend
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = 12345;
```

States: `active`, `idle`, `idle in transaction`, `idle in transaction (aborted)`, `fastpath function call`, `disabled`.

Wait event types: `Lock`, `LWLock`, `IO`, `Client`, `IPC`, `Timeout`, `Activity`.

---

## pg_stat_user_tables

One-line definition: A view showing per-table access statistics including sequential and index scans, row-level inserts/updates/deletes, dead tuple counts, and vacuum/analyze timestamps.

```sql
-- blocked: Docker not accessible
SELECT schemaname, relname,
       seq_scan, idx_scan,
       n_live_tup, n_dead_tup,
       last_vacuum, last_autovacuum,
       last_analyze, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Tables with more seq scans than index scans (potential missing indexes)
SELECT relname, seq_scan, idx_scan
FROM pg_stat_user_tables
WHERE seq_scan > idx_scan AND n_live_tup > 10000
ORDER BY seq_scan DESC;
```

Related: [[transaction-ontology]] (dead tuples, vacuum), [[index-ontology]] (seq vs index scan ratio)

---

## pg_stat_user_indexes

One-line definition: A view showing per-index access statistics including the number of index scans, tuples read, and tuples fetched.

```sql
-- blocked: Docker not accessible
-- Unused indexes (candidates for removal)
SELECT schemaname, relname, indexrelname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY relname;

-- Most-used indexes
SELECT schemaname, relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC
LIMIT 20;
```

Related: [[index-ontology]]

---

## pg_locks

One-line definition: A view showing all currently held and awaited locks in the database, including the relation, lock mode, granted status, and holding PID.

```sql
-- blocked: Docker not accessible
-- Lock contention: show blocking and blocked sessions
SELECT
    blocked.pid           AS blocked_pid,
    blocked.query         AS blocked_query,
    blocking.pid          AS blocking_pid,
    blocking.query        AS blocking_query,
    blocked.wait_event
FROM pg_stat_activity AS blocked
JOIN pg_stat_activity AS blocking
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.cardinality(pg_blocking_pids(blocked.pid)) > 0;

-- All locks on a specific table
SELECT pid, mode, granted
FROM pg_locks
WHERE relation = 'orders'::regclass;
```

Lock modes (ascending strength): `AccessShareLock`, `RowShareLock`, `RowExclusiveLock`, `ShareUpdateExclusiveLock`, `ShareLock`, `ShareRowExclusiveLock`, `ExclusiveLock`, `AccessExclusiveLock`.

Related: [[transaction-ontology]]

---

## pg_buffercache

One-line definition: An extension that exposes the in-memory shared buffer cache, showing which table/index pages are cached and their dirty status.

```sql
-- blocked: Docker not accessible
CREATE EXTENSION pg_buffercache;

-- Cache usage by relation
SELECT c.relname,
       count(*)                     AS buffers,
       pg_size_pretty(count(*) * 8192) AS cached_size,
       round(100.0 * count(*) / (SELECT count(*) FROM pg_buffercache), 2) AS pct
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
WHERE b.reldatabase = (SELECT oid FROM pg_database WHERE datname = current_database())
  AND b.usagecount IS NOT NULL
GROUP BY c.relname
ORDER BY buffers DESC
LIMIT 20;
```

Related: [[performance-ontology]]

---

## auto_explain

One-line definition: A module that automatically logs the execution plan of slow queries (those exceeding `log_min_duration`) to the PostgreSQL log, without requiring manual EXPLAIN.

```ini
# postgresql.conf
shared_preload_libraries = 'auto_explain'
auto_explain.log_min_duration = '1s'    # log plans for queries > 1 second
auto_explain.log_analyze = on           # include actual row counts and timing
auto_explain.log_buffers = on           # include buffer usage
```

Related: [[query-ontology]], [[performance-ontology]]

---

## Prometheus + postgres_exporter

One-line definition: `postgres_exporter` is an open-source Prometheus exporter that exposes PostgreSQL metrics (from `pg_stat_*` views) as Prometheus-formatted time series for alerting and dashboards.

Key metrics exposed:
| Metric | Source view |
|--------|------------|
| `pg_stat_user_tables_seq_scan` | `pg_stat_user_tables` |
| `pg_stat_user_tables_n_dead_tup` | `pg_stat_user_tables` |
| `pg_stat_statements_total_time_seconds` | `pg_stat_statements` |
| `pg_locks_count` | `pg_locks` |
| `pg_database_size_bytes` | `pg_database_size()` |
| `pg_replication_lag` | `pg_stat_replication` |

Configuration: custom queries via `--extend.query-path=queries.yaml` allow exporting any SQL query as a metric.

---

## Grafana

One-line definition: An open-source visualization platform that queries Prometheus (and other data sources) to display PostgreSQL metrics on customizable dashboards with alerting.

Community dashboards:
- Grafana dashboard ID 9628 — PostgreSQL Database (by postgres_exporter)
- Grafana dashboard ID 12485 — PostgreSQL Statistics

Related: prometheus_exporter connects to Prometheus, Grafana queries Prometheus.

---

## System catalog reference
- `pg_stat_activity` — live session and query state
- `pg_stat_user_tables` — per-table I/O and maintenance stats
- `pg_stat_user_indexes` — per-index scan stats
- `pg_stat_bgwriter` — background writer stats (checkpoint frequency, buffers written)
- `pg_stat_replication` — streaming replication state and lag
- `pg_locks` — lock state
- `pg_stat_statements` — per-query cumulative stats (extension)
- `pg_buffercache` — shared buffer contents (extension)

---

## Beginner mental model
PostgreSQL keeps a running scorecard of everything happening in the database — how often each query runs, how many rows each table scans, which sessions are blocked. The `pg_stat_*` views are that scorecard. postgres_exporter reads the scorecard, Prometheus stores it over time, and Grafana displays it as a dashboard.

## Intermediate mental model
Correlate: high `seq_scan` in `pg_stat_user_tables` → check `pg_stat_user_indexes` for unused indexes → check `pg_stats` for stale statistics. High `n_dead_tup` → autovacuum is not keeping up → check `pg_stat_activity` for long-running transactions blocking vacuum. Lock waits → `pg_locks` joined to `pg_stat_activity` to find the blocking PID.

## Advanced mental model
Statistics counters reset on server restart and can be reset manually per-object. For time-series trending, use `postgres_exporter` to scrape into Prometheus at 15-second intervals. `pg_stat_statements.queryid` is a stable identifier for normalized query shapes — use it to track a query's performance over time across deploys. `auto_explain` with `log_analyze = on` adds execution overhead to every slow query — use `sample_rate < 1.0` in production.

## MCP and agent perspective
An agent with `pg_monitor` role membership (granted in PostgreSQL 10+) can read all `pg_stat_*` views without superuser. Agents should query `pg_stat_activity` before submitting a long-running query to check for active locks. Agents performing schema migrations should check `pg_locks` for conflicts and wait for the lock queue to clear. Automated agents should never call `pg_terminate_backend` without human approval.

## Practical implication
| Situation | Implication |
|-----------|-------------|
| `pg_stat_statements` shows high `stddev_exec_time` | Query has inconsistent performance; check for lock waits or cache misses |
| `pg_stat_user_tables.seq_scan` rising | New query pattern, missing index, or stats-driven plan change |
| `pg_locks` shows `granted = false` for many PIDs | Lock contention; identify holder and investigate long-running transaction |
| `n_dead_tup` growing unchecked | Autovacuum not keeping up; long-running transactions or vacuum throttled too much |
| `pg_buffercache` shows index fully cached | Good; index-only scans will be fast |
| `pg_stat_activity` shows `idle in transaction` sessions | Connection not committed; holds locks and blocks vacuum |

## Obsidian connections
[[performance-ontology]] [[query-ontology]] [[transaction-ontology]] [[security-ontology]] [[extension-ontology]] [[index-ontology]]

## References
- pg_stat_statements: https://www.postgresql.org/docs/16/pgstatstatements.html
- pg_stat_activity: https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW
- postgres_exporter: https://github.com/prometheus-community/postgres_exporter
- auto_explain: https://www.postgresql.org/docs/16/auto-explain.html
