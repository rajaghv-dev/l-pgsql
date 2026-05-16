# Practice Session: Observability with pg_stat_statements

Level: Intermediate  
Prerequisites: `concepts/intermediate/19-observability-with-pg-stat-statements.md`

## Goal

Query pg_stat_* views to understand database activity: active connections, top queries by time, table scan patterns, and cache hit rates. Note: pg_stat_statements requires one-time setup.

## Quick start

```bash
# Step 1: enable pg_stat_statements (one time, restarts container)
bash scripts/dashboards/enable-pg-stat-statements.sh

# Step 2: connect
# blocked: Docker not accessible; validate when Docker Desktop WSL2 integration is enabled
docker exec cfp_postgres psql -U cfp -d cfp -f practice/intermediate/12-observability/setup.sql
```

## Files

| File | Purpose |
|------|---------|
| setup.sql | Validation queries for pg_stat_* views; sample observation queries |
| exercises.md | Query pg_stat_activity, pg_stat_user_tables, pg_stat_statements top-5 |
| solutions.md | Full queries with column explanations |
| reflection.md | Questions on cache hit rate, bloat indicators, agent monitoring |
| ontology-notes.md | [[observability-ontology]] [[performance-ontology]] |
| troubleshooting.md | pg_stat_statements not found, missing shared_preload_libraries |
| references.md | pg_stat_statements docs, Grafana PG dashboard |

## What you'll learn

- `pg_stat_activity` — active queries and connections
- `pg_stat_user_tables` — seq scans, live/dead tuples, vacuum stats
- `pg_stat_user_indexes` — index usage
- `pg_stat_statements` — top queries by total time (requires setup)
- Cache hit rate formula: `heap_blks_hit / (heap_blks_hit + heap_blks_read)`

## MCP and agent perspective

Agents should not have SELECT on pg_stat_statements directly (it reveals other tenants' queries). Instead, expose a narrow MCP tool `get_my_agent_query_stats()` that filters by the agent's own queries.
