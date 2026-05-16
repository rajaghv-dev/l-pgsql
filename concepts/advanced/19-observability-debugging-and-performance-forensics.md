# Observability, Debugging, and Performance Forensics

Level: Advanced
PostgreSQL 16 | Container: `docker exec cfp_postgres psql -U cfp -d cfp`

## One-line intuition
Performance forensics is triangulation: CPU-bound, IO-bound, or lock-bound — each has a distinct fingerprint in the pg_stat_* views.

## Why this exists
Slow queries rarely announce their cause. Effective forensics requires knowing which catalog views expose which bottleneck and how to read the evidence without guessing.

## First-principles explanation
Every query consumes time in one of three categories: CPU (parsing, planning, sorting, hashing), IO (reading pages from disk into shared_buffers), or lock waits. Each maps to specific catalog views. The skill is reading them in combination to triangulate root cause.

## Micro-concepts
- **pg_stat_statements**: aggregated query stats — total_exec_time, calls, shared_blks_hit vs shared_blks_read
- **pg_stat_activity**: live backend states — active, idle in transaction, and what each is waiting for
- **pg_locks + pg_blocking_pids()**: blocking chains — who holds the lock, who is waiting
- **auto_explain**: logs slow query EXPLAIN plans automatically without manual intervention
- **pg_buffercache**: live view of shared buffer contents

## Beginner view
Run EXPLAIN ANALYZE and look at the worst node. Check if a seq scan should be an index scan.

## Intermediate view
Use pg_stat_statements for high total_exec_time or poor cache hit. Use pg_stat_activity to find idle-in-transaction sessions holding locks.

## Advanced view
Combine all three: pg_stat_statements for trends, pg_stat_activity for live state, pg_locks for the blocking chain. Configure auto_explain for production slow query logging.

## Mental model
The fire triangle of PostgreSQL performance: CPU + IO + Locks. Every performance problem involves one or more. Each vertex has a pg_stat view.

## PostgreSQL view
```sql
-- blocked: Docker not accessible; validate against cfp_postgres when available

-- Top 5 queries by total execution time
SELECT left(query, 80) AS q, calls, total_exec_time, shared_blks_hit, shared_blks_read
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 5;

-- Active queries running > 5 seconds
SELECT pid, state, wait_event_type, now() - query_start AS dur, left(query,60)
FROM pg_stat_activity WHERE state = 'active' AND query_start < now() - interval '5s';

-- Blocking chain
SELECT blocked.pid, left(blocked.query,60), blocking.pid AS blocker, left(blocking.query,60)
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE cardinality(pg_blocking_pids(blocked.pid)) > 0;
```

## SQL view
```sql
-- blocked: Docker not accessible

-- Cache hit rate per table
SELECT relname, heap_blks_hit::float / NULLIF(heap_blks_hit + heap_blks_read, 0) AS hit_rate
FROM pg_statio_user_tables ORDER BY hit_rate ASC NULLS LAST LIMIT 10;

-- Dead tuple ratio (candidates for VACUUM)
SELECT relname, n_live_tup, n_dead_tup,
    round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_pct
FROM pg_stat_user_tables WHERE n_dead_tup > 1000 ORDER BY dead_pct DESC LIMIT 10;

-- Unused indexes (remove to reduce write overhead)
SELECT relname, indexrelname, idx_scan
FROM pg_stat_user_indexes WHERE idx_scan = 0 ORDER BY relname;
```

## Non-SQL or hybrid view
pgBadger parses PostgreSQL log files (set `log_min_duration_statement`) and generates HTML reports of slow queries and lock events.

## Design principle
**Profile before optimizing**: verify with pg_stat_statements before adding indexes. An unused index costs write overhead for zero benefit.

## Critical thinking
Why might a query appear slow in pg_stat_statements but fast when run manually? (Plan cache, lock contention at peak hours, autovacuum running at the same time.)

## Creative thinking
How would you build a continuous performance anomaly detector using only PostgreSQL built-in views and a scheduled check?

## Systems thinking
How does a long-running idle-in-transaction session affect autovacuum, dead tuple accumulation, and query performance? (Autovacuum cannot clean dead tuples visible to the open transaction — bloat accumulates over time.)

## MCP and agent perspective
- Agents should NOT have SELECT on pg_stat_statements (reveals other tenants' queries)
- Provide a narrow MCP tool `get_my_connection_stats()` filtering by agent's own pid
- Monitor agent write volumes via pg_stat_user_tables.n_mod_since_analyze
- Set statement_timeout on all agent connections

## Ontology perspective
[[observability-ontology]] [[performance-ontology]] [[transaction-ontology]]

## Practice session
See `practice/intermediate/12-observability/` for hands-on exercises.

## References
- [pg_stat_statements](https://www.postgresql.org/docs/16/pgstatstatements.html) — official docs
- [Monitoring Statistics](https://www.postgresql.org/docs/16/monitoring-stats.html) — all pg_stat_* views
- [auto_explain](https://www.postgresql.org/docs/16/auto-explain.html) — automatic slow query logging
- [Use The Index, Luke](https://use-the-index-luke.com) — free execution plan guide
