# Reflection — MVCC and Locking

## Key takeaways
- PostgreSQL's heap is an append-only structure. Updates create new tuple versions; old versions become dead tuples. This is the cost of MVCC's non-blocking reads.
- Vacuum is not optional — tables with high update rates need appropriately tuned autovacuum to avoid table bloat and XID wraparound.
- Row locks are stored in tuple headers (via xmax), not in a separate lock table. This means PostgreSQL can hold millions of row locks with negligible overhead.
- SKIP LOCKED is the canonical pattern for work queues. It eliminates the thundering herd problem where all workers pile up on the same locked row.
- Deadlocks are always caused by inconsistent lock ordering. The fix is in the application code, not in PostgreSQL configuration.

## Common mistakes
1. Forgetting that `SELECT FOR UPDATE` sets xmax on the locked tuple — observable with `SELECT xmax FROM table WHERE ...`
2. Treating VACUUM as a one-time operation. High-churn tables need frequent vacuuming (tune `autovacuum_vacuum_scale_factor`)
3. Using FOR UPDATE without SKIP LOCKED in queue patterns — causes all workers to queue behind one lock
4. Not setting `lock_timeout` in application connections, allowing sessions to block indefinitely

## Deeper questions
1. What is the difference between `VACUUM` and `VACUUM FULL`? When is each appropriate?
2. How does XID wraparound occur and how does `VACUUM FREEZE` prevent it?
3. What is a `MultiXact` and when is it used?
4. How does the Hot Update Optimization avoid index updates for non-indexed column changes?

## Connection to monitoring
These exercises connect directly to:
- `pg_stat_user_tables` — `n_dead_tup`, `n_live_tup`, `last_autovacuum`
- `pg_locks` — lock mode, granted status, relation
- `pg_stat_activity` — `state`, `wait_event_type`, `wait_event`
- `pageinspect` — raw tuple-level visibility

The combination of `pg_locks` and `pg_stat_activity` joined on `pid` is the essential diagnostic tool for any lock contention incident in production.

## What to explore next
- Stage 10: JSONB modeling, full-text search, pgvector
- Stage 11: pg_stat_statements for query-level observability
- `concepts/advanced/` (future): WAL, replication, connection pooling
