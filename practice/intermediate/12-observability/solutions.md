# Solutions — Observability

**Status: blocked — Docker not accessible in this session**

## Exercise 1 solution
Top queries by `total_exec_time` shows which query shapes consume the most cumulative CPU time. A query with `calls=10000` and `mean_ms=0.5` contributes 5000ms total — the same as a query with `calls=1` and `mean_ms=5000`. Total time is the right metric for prioritizing optimization work.

The `pct_total` column shows each query's share of all tracked time. If one query accounts for >20% of total time, it is an optimization priority regardless of its mean latency.

## Exercise 2 solution
The "multiplication effect": `calls * mean_exec_time` = total impact. A fast query (0.5ms mean) that runs 100,000 times/day contributes 50 seconds of cumulative latency. Optimizing it by 50% saves 25 seconds of daily database time. This is often more valuable than optimizing a slow query (5000ms) that runs once/day.

## Exercise 3 solution
`shared_blks_read` = blocks read from disk (cache miss). `shared_blks_hit` = blocks served from shared_buffers (cache hit). Cache hit ratio = `hits / (hits + reads)`.

A ratio below 90% means >10% of data reads go to disk — often a sign that:
- `shared_buffers` is too small
- Working set exceeds available memory
- Missing indexes causing full table scans
- A single large table scan is polluting the buffer cache

## Exercise 4 solution
`pg_stat_activity` shows LIVE session state — what each backend is currently doing. Useful for:
- Finding long-running queries (`query_duration > threshold`)
- Finding blocked sessions (`wait_event_type = 'Lock'`)
- Identifying idle-in-transaction sessions (`state = 'idle in transaction'`)
- Spotting unexpected connections from unknown applications

## Exercise 5 solution
`pg_blocking_pids(pid)` returns an array of PIDs that are blocking the given session. JOIN with `pg_stat_activity` to get the blocking query. This is the essential production debugging query for lock contention incidents. Save it as a runnable script and include it in your runbook.

## Exercise 6 solution
`pg_stat_user_tables` tracks per-table DML statistics. Key signals:
- High `n_dead_tup` → table needs VACUUM (autovacuum may be lagging)
- High `seq_scan` with low `idx_scan` → missing index on a frequently-filtered column
- Stale `last_autovacuum` → autovacuum not running on this table (may be blocked by long transactions)

Alert thresholds (adjust to your workload):
- `dead_pct > 20%` → run manual VACUUM
- `seq_scan / (seq_scan + idx_scan) > 0.3` on large tables → investigate missing indexes
- `last_autovacuum` older than 1 hour on high-churn tables → investigate autovacuum config

## Exercise 7 solution
`pg_stat_statements_reset()` clears all data. Use cases:
- Before a benchmark run (baseline)
- After a major optimization to start fresh
- During investigation when old data obscures current patterns

Never run in production without authorization — it destroys the evidence baseline for ongoing investigations. Consider snapshotting before resetting: `INSERT INTO query_snapshots SELECT now(), * FROM pg_stat_statements;`

## Reflection answers
1. `total_exec_time` = impact * frequency. A fast query run millions of times can cost more than a slow query run once. Optimizing by total time maximizes the performance ROI.
2. Cache hit ratio < 90% suggests the working set doesn't fit in `shared_buffers`. Solutions: increase shared_buffers (up to 25% of RAM), add indexes to reduce scan size, partition large tables so hot partitions fit in cache.
3. `pg_stat_activity` = live view (current instant). `pg_stat_statements` = historical aggregate (all past queries). Use activity for real-time debugging; use statements for trend analysis, optimization prioritization, and baseline comparisons.
4. After reset, all prior statistics are lost. Any "before" measurements become unrecoverable. If you need before/after comparison, snapshot first: `SELECT * INTO query_snapshot_before FROM pg_stat_statements;`.
