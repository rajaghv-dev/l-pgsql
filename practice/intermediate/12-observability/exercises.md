# Exercises — Observability

**Status: blocked — Docker not accessible in this session**

## Exercise 1: Top queries by cumulative time

```sql
-- blocked: Docker not accessible

SELECT * FROM v_top_queries LIMIT 10;

-- Manual version:
SELECT
    calls,
    ROUND(total_exec_time::numeric, 2) AS total_ms,
    ROUND(mean_exec_time::numeric, 2)  AS mean_ms,
    ROUND((100 * total_exec_time / SUM(total_exec_time) OVER ())::numeric, 1) AS pct,
    rows,
    LEFT(query, 100) AS snippet
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

## Exercise 2: High-frequency moderate-latency queries (multiplication effect)

```sql
-- blocked: Docker not accessible

-- Queries that run often and would benefit most from optimization
SELECT
    calls,
    ROUND(mean_exec_time::numeric, 2) AS mean_ms,
    ROUND((calls * mean_exec_time)::numeric, 0) AS impact_ms,
    LEFT(query, 100) AS snippet
FROM pg_stat_statements
WHERE calls > 100
ORDER BY calls * mean_exec_time DESC
LIMIT 10;
```

## Exercise 3: I/O-heavy queries — cache hit ratio

```sql
-- blocked: Docker not accessible

SELECT
    calls,
    shared_blks_read AS disk_reads,
    shared_blks_hit  AS cache_hits,
    ROUND(100.0 * shared_blks_hit / NULLIF(shared_blks_hit + shared_blks_read, 0), 1) AS hit_pct,
    LEFT(query, 100) AS snippet
FROM pg_stat_statements
WHERE shared_blks_read > 0
ORDER BY shared_blks_read DESC
LIMIT 10;

-- Overall cache hit rate
SELECT
    SUM(shared_blks_hit) AS total_hits,
    SUM(shared_blks_read) AS total_reads,
    ROUND(100.0 * SUM(shared_blks_hit) / NULLIF(SUM(shared_blks_hit + shared_blks_read), 0), 1) AS overall_hit_pct
FROM pg_stat_statements;
```

## Exercise 4: Active sessions — pg_stat_activity

```sql
-- blocked: Docker not accessible

-- What is each session doing right now?
SELECT
    pid,
    usename AS user,
    application_name,
    state,
    wait_event_type,
    wait_event,
    NOW() - query_start AS query_duration,
    LEFT(query, 80) AS current_query
FROM pg_stat_activity
WHERE state != 'idle'
  AND pid != pg_backend_pid()
ORDER BY query_duration DESC NULLS LAST;
```

## Exercise 5: Lock waits

```sql
-- blocked: Docker not accessible

SELECT
    blocked.pid AS blocked_pid,
    blocked.query AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.query AS blocking_query,
    pg_blocking_pids(blocked.pid) AS blocking_pids
FROM pg_stat_activity blocked
CROSS JOIN LATERAL UNNEST(pg_blocking_pids(blocked.pid)) AS blocking_pid_val
JOIN pg_stat_activity blocking ON blocking.pid = blocking_pid_val
WHERE blocked.wait_event_type = 'Lock'
ORDER BY blocked.pid;
```

## Exercise 6: Table health — sequential scans and dead tuples

```sql
-- blocked: Docker not accessible

SELECT * FROM v_table_health;

-- Manual version:
SELECT
    relname,
    n_live_tup,
    n_dead_tup,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
    seq_scan,
    idx_scan,
    last_autovacuum::date,
    last_autoanalyze::date
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Alert: tables with >20% dead tuples (need vacuum)
SELECT relname, dead_pct
FROM v_table_health
WHERE dead_pct > 20
ORDER BY dead_pct DESC;
```

## Exercise 7: Reset statistics and re-measure

```sql
-- blocked: Docker not accessible

-- CAUTION: This destroys all accumulated query statistics
-- Only run in non-production or test environments
SELECT pg_stat_statements_reset();

-- Now run a workload:
-- SELECT * FROM orders WHERE status = 'pending' LIMIT 10;
-- (run 5 times to build stats)

-- Then re-check:
SELECT calls, mean_exec_time, query FROM pg_stat_statements
WHERE query ILIKE '%orders%'
ORDER BY calls DESC;
```

## Reflection questions
1. Why sort by `total_exec_time` instead of `mean_exec_time` when prioritizing optimizations?
2. What does a cache hit ratio below 90% indicate?
3. When would you use `pg_stat_activity` vs `pg_stat_statements`?
4. How does `pg_stat_statements_reset()` interact with ongoing performance investigations?
