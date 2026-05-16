# Reflection — Observability

## Key takeaways
- `pg_stat_statements` is the starting point for every query performance investigation.
- Sort by `total_exec_time` (not mean) to find the highest-impact optimization targets.
- `pg_stat_activity` is for real-time debugging; `pg_stat_statements` is for trend analysis.
- Cache hit ratio below 90% is a signal to investigate `shared_buffers` and index coverage.
- Never `pg_stat_statements_reset()` without snapshotting first.

## The observability stack
```
pg_stat_statements  → which queries are expensive
EXPLAIN ANALYZE     → why a specific query is expensive
pg_stat_activity    → what is happening right now
pg_locks            → who is blocking whom
pg_stat_user_tables → which tables are bloated or missing indexes
```

## Monitoring checklist
- [ ] pg_stat_statements installed and collecting data
- [ ] Alert when `mean_exec_time` for key queries increases >20% week-over-week
- [ ] Alert when `dead_pct` exceeds 20% for any table
- [ ] Alert when cache hit ratio drops below 90%
- [ ] Alert when any session has been in 'idle in transaction' > 5 minutes
- [ ] Snapshot pg_stat_statements before each deploy for regression detection

## What to explore next
- Concept 20: Migrations — measure migration lock duration with pg_locks + pg_stat_activity
- Practice 13: Ontology modeling — measure ontology query patterns
- Dashboards: `scripts/dashboards/` — pre-built queries for Grafana/DataDog
