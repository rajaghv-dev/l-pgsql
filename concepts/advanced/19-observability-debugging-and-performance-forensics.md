# Observability, Debugging, and Performance Forensics

Level: Advanced

## One-line intuition
Every PostgreSQL performance problem is one of three things: too much CPU (bad plans, complex queries), too much IO (missing indexes, bloat, cache misses), or too much waiting (lock contention, replication lag) — and the system views tell you exactly which one, if you know where to look.

## Why this exists
Production performance problems require forensic investigation: you often can't reproduce them in development, the symptoms are transient (a 5-second spike at 3am), and the root cause may be multiple layers removed from the symptom. PostgreSQL's system views, stats collector, and extension ecosystem provide the evidence — but only if you know which view answers which question.

## First-principles explanation

### The performance fire triangle
Every PostgreSQL performance problem falls into one category:
```
          CPU
         /   \
        /     \
    IO --------- Locks/Waits
```

- **CPU-bound**: expensive expressions, sorts, hash joins, bad plans with high cost
- **IO-bound**: sequential scans, cache misses, checkpoint IO spikes, temp file spills
- **Lock/wait-bound**: blocked queries, lock queue storms, replication apply lag

### pg_stat_statements — the top queries view

Requires `shared_preload_libraries = 'pg_stat_statements'` and `CREATE EXTENSION pg_stat_statements`.

```sql
-- blocked: Docker not accessible
-- Top 10 queries by total execution time
SELECT
    left(query, 80) AS query,
    calls,
    round(total_exec_time::numeric, 2) AS total_ms,
    round(mean_exec_time::numeric, 2) AS mean_ms,
    round(stddev_exec_time::numeric, 2) AS stddev_ms,
    rows,
    round(total_exec_time / sum(total_exec_time) OVER () * 100, 1) AS pct_total
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Queries with high variance (lock waits or plan instability)
SELECT left(query, 60), calls, mean_exec_time, stddev_exec_time,
       round(stddev_exec_time / nullif(mean_exec_time, 0) * 100) AS cv_pct
FROM pg_stat_statements
WHERE calls > 10
ORDER BY stddev_exec_time DESC LIMIT 10;

-- Queries causing most IO
SELECT left(query, 60), calls, shared_blks_hit, shared_blks_read,
       round(shared_blks_read::numeric / nullif(calls, 0), 0) AS reads_per_call
FROM pg_stat_statements
ORDER BY shared_blks_read DESC LIMIT 10;
```

### pg_stat_activity — the live session monitor

```sql
-- blocked: Docker not accessible
-- Active queries (not idle)
SELECT pid, usename, application_name, state, wait_event_type, wait_event,
       now() - query_start AS duration,
       left(query, 100) AS query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;

-- Blocking chains (who is blocking whom)
SELECT blocked.pid, blocked.query, blocking.pid AS blocking_pid, blocking.query AS blocking_query
FROM pg_stat_activity AS blocked
JOIN pg_stat_activity AS blocking
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE cardinality(pg_blocking_pids(blocked.pid)) > 0;

-- Idle in transaction (dangerous — holds locks and xmin)
SELECT pid, usename, now() - query_start AS idle_duration, left(query, 80)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY query_start;
```

### pg_locks — lock forensics

```sql
-- blocked: Docker not accessible
-- All granted and pending locks
SELECT pid, locktype, relation::regclass, mode, granted
FROM pg_locks
WHERE relation IS NOT NULL
ORDER BY relation, granted;

-- Simple blocker/blocked query
SELECT pid, pg_blocking_pids(pid) AS blocked_by, query, state
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
```

### auto_explain — logging slow query plans

Configure in postgresql.conf:
```conf
shared_preload_libraries = 'pg_stat_statements,auto_explain'
auto_explain.log_min_duration = 1000    # log queries > 1 second
auto_explain.log_analyze = on
auto_explain.log_buffers = on
auto_explain.log_verbose = on
```

Session-level test (no restart needed):
```sql
-- blocked: Docker not accessible
LOAD 'auto_explain';
SET auto_explain.log_min_duration = 0;
SET auto_explain.log_analyze = on;
-- Run your query — plan appears in log
```

### IO forensics

```sql
-- blocked: Docker not accessible
-- Which tables are causing the most IO?
SELECT relname,
       heap_blks_hit, heap_blks_read,
       round(heap_blks_hit::numeric / nullif(heap_blks_hit + heap_blks_read, 0) * 100, 1) AS hit_pct
FROM pg_statio_user_tables
ORDER BY heap_blks_read + idx_blks_read DESC LIMIT 10;

-- Temp file spills (sort or hash overflow)
SELECT datname, temp_files, pg_size_pretty(temp_bytes) AS spill_size
FROM pg_stat_database ORDER BY temp_bytes DESC;

-- Checkpoint IO
SELECT buffers_checkpoint, buffers_clean, buffers_backend, checkpoints_timed, checkpoints_req
FROM pg_stat_bgwriter;
```

### Diagnostic queries by symptom

| Symptom | View to check | Action |
|---|---|---|
| Slow queries, high CPU | `pg_stat_statements` by `total_exec_time` | EXPLAIN ANALYZE top queries |
| High disk IO | `pg_statio_user_tables` by `heap_blks_read` | Check bloat, cache size, work_mem |
| Queries queued/blocked | `pg_stat_activity` wait_event_type = 'Lock' | `pg_blocking_pids()` → terminate |
| Latency spikes at intervals | `log_checkpoints = on` + pgBadger | Tune `max_wal_size`, `checkpoint_completion_target` |
| Database grows fast | `pg_stat_user_tables` `n_dead_tup` | Tune autovacuum |
| Query was fast yesterday | `pg_stat_statements` variance | EXPLAIN, check statistics freshness |

### pageinspect — page-level forensics

```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS pageinspect;

-- Inspect a heap page's tuples
SELECT lp, lp_flags, t_xmin, t_xmax, t_infomask
FROM heap_page_items(get_raw_page('orders', 0));
```

## Micro-concepts
- **wait_event_type**: `Lock` (lock wait), `IO` (disk IO), `LWLock` (internal lock), `Client` (waiting for client), `CPU` (actively computing).
- **pg_stat_statements.queryid**: hash of normalized query. Same query with different literals has same queryid.
- **stddev_exec_time**: high standard deviation = lock waits hiding in mean times.
- **`EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)`**: machine-parseable output for CI assertions.
- **`pg_stat_statements_reset()`**: resets all stats. Run before/after a change to measure improvement.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Check `pg_stat_activity` for what's running. Use EXPLAIN to see the plan.

**Intermediate view**: `pg_stat_statements` shows aggregate query stats. Sort by `total_exec_time` for top offenders. `pg_blocking_pids` shows lock chains. Use `auto_explain` to log plans for slow queries automatically.

**Advanced view**: Performance forensics requires pre-built monitoring: pg_stat_statements continuously collecting, `log_min_duration_statement` capturing slow queries, `log_lock_waits` capturing lock events. Point-in-time diagnosis of a past incident requires having collected snapshots of these views stored in a monitoring table or external TSDB. The fire triangle framework (CPU / IO / Locks) provides the taxonomy for diagnosis. Standard deviation in `pg_stat_statements` is a canary for lock waits hiding in mean times — a query with `mean=50ms, stddev=500ms` is almost certainly experiencing intermittent lock waits.

## Mental model
Observability is a medical examination of the database: pg_stat_activity is the pulse monitor (what is happening right now), pg_stat_statements is the blood test (what has been happening over time), pg_locks is the X-ray (where are the blockages), and EXPLAIN ANALYZE is the MRI (exactly how is the query executing). pgBadger is the retrospective medical record — reviewing history to find when things went wrong.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_stat_statements`, `pg_stat_activity`, `pg_locks`, `pg_stat_bgwriter`, `pg_statio_user_tables`, `pg_stat_user_tables`, `pg_stat_database`.

**SQL view**: See all queries above.

**Non-SQL / hybrid view**:
- pgBadger: https://pgbadger.darold.net/
- explain.depesz.com: paste EXPLAIN output, get color-coded analysis
- Prometheus + postgres_exporter: metric collection from system views
- pganalyze: SaaS monitoring for PostgreSQL (commercial)

## Design principle
**Observe before you tune**: never adjust `shared_buffers`, `work_mem`, or add indexes without first measuring the current state via the system views. Tuning without measurement is guessing. The system views give you the evidence; the fire triangle gives you the diagnostic framework.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: `pg_stat_statements` accumulates statistics since the last reset. On a server running for months, `total_exec_time` is dominated by old data. Compare two snapshots (before/after a change) by taking the diff, not absolute values. Alternatively, reset stats before a measurement window.

**Creative**: Build a performance snapshot table that captures top-N queries every hour from pg_stat_statements:
```sql
-- blocked: Docker not accessible
CREATE TABLE perf_snapshots AS SELECT now() AS captured_at, * FROM pg_stat_statements LIMIT 0;
-- Insert hourly via cron:
INSERT INTO perf_snapshots SELECT now(), * FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 100;
```

**Systems**: The fire triangle maps to organizational responsibilities: CPU → query optimization (developer); IO → index strategy, autovacuum (DBA); Locks → schema design, transaction management (shared). Effective forensics routes the diagnosis to the right team. Dashboards that clearly indicate which vertex is the problem save organizational time.

## MCP and agent perspective
AI agents should be observable using the same PostgreSQL tooling. Include `application_name = 'agent_<agent_id>'` in the connection string — this makes agent queries identifiable in `pg_stat_activity` and `pg_stat_statements`. Build a monitoring agent that periodically queries `pg_stat_statements` for queries where `application_name LIKE 'agent_%'` and alerts when mean execution time exceeds a threshold. This treats agent query performance as a first-class operational concern.

## Ontology perspective
Observability is an epistemological practice: the system views are the database's self-model, its introspective representation of its own behavior. The quality of observability determines the quality of reasoning about performance. PostgreSQL's rich system views reflect its design philosophy of transparency — the database exposes its internals as first-class queryable data. Performance is knowable and explicable, not opaque.

## Practice session

**Exercise 1 — Find top CPU queries**:
```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SELECT left(query, 80), calls, round(mean_exec_time::numeric, 2) AS mean_ms
FROM pg_stat_statements
ORDER BY total_exec_time DESC LIMIT 10;
```

**Exercise 2 — Detect idle-in-transaction**:
```sql
-- blocked: Docker not accessible
SELECT pid, usename, state, now() - query_start AS idle_duration, left(query, 80)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY query_start;
```

**Exercise 3 — IO per table**:
```sql
-- blocked: Docker not accessible
SELECT relname, heap_blks_read,
       round(heap_blks_hit::numeric / nullif(heap_blks_hit + heap_blks_read, 0) * 100, 1) AS cache_hit_pct
FROM pg_statio_user_tables
WHERE heap_blks_read > 0
ORDER BY heap_blks_read DESC LIMIT 10;
```

**Exercise 4 — Lock chain query**:
```sql
-- blocked: Docker not accessible
SELECT pid, pg_blocking_pids(pid) AS blocking_pids, state, wait_event, left(query, 80)
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
```

**Exercise 5 — Checkpoint health**:
```sql
-- blocked: Docker not accessible
SELECT checkpoints_timed, checkpoints_req,
       round(checkpoints_req::numeric / nullif(checkpoints_timed + checkpoints_req, 0) * 100, 1) AS forced_pct
FROM pg_stat_bgwriter;
-- forced_pct > 10% means max_wal_size is too small
```

## References
- PostgreSQL Documentation: [pg_stat_statements](https://www.postgresql.org/docs/16/pgstatstatements.html)
- PostgreSQL Documentation: [pg_stat_activity](https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW)
- PostgreSQL Documentation: [auto_explain](https://www.postgresql.org/docs/16/auto-explain.html)
- PostgreSQL Documentation: [pageinspect](https://www.postgresql.org/docs/16/pageinspect.html)
- pgBadger: https://pgbadger.darold.net/
- explain.depesz.com: https://explain.depesz.com/
- Christophe Pettus: [PostgreSQL Diagnostics](https://www.pgexperts.com/)
- Laurenz Albe: [PostgreSQL wait events](https://www.cybertec-postgresql.com/en/waiting-in-postgres/)
