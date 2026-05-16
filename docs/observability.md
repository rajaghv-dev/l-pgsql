# Observability

Generated: 2026-05-16  
Phase: 12

---

## Overview

This repo ships a full observability dashboard stack for learning PostgreSQL internals. The dashboards are teaching tools, not production monitoring.

---

## Logs

| Source | How to access |
|---|---|
| PostgreSQL logs | `docker logs cfp_postgres` |
| Grafana logs | `docker compose -f tools/dashboards/docker-compose.yml logs grafana` |
| postgres_exporter | `docker compose -f tools/dashboards/docker-compose.yml logs postgres-exporter` |
| Any dashboard service | `docker compose -f tools/dashboards/docker-compose.yml logs -f <service>` |

---

## Metrics

| Metric source | Collected by | Visible in |
|---|---|---|
| PostgreSQL internals (`pg_stat_*`) | postgres_exporter (port 9187) | Prometheus → Grafana |
| Redis internals | redis_exporter (port 9121) | Prometheus → Grafana |
| Raw PromQL queries | Prometheus UI (port 9090) | http://localhost:9090 |

Key PostgreSQL metrics tracked:
- Active connections (`pg_stat_activity`)
- Cache hit rate (`pg_statio_user_tables`)
- Table scan and index usage (`pg_stat_user_tables`, `pg_stat_user_indexes`)
- Live/dead row counts (bloat indicator)
- Lock waits (`pg_locks`)
- Query statistics (requires `pg_stat_statements` — see setup below)

---

## Traces

No distributed tracing. Not applicable for a single-node learning environment.

---

## Debugging

| Tool | Purpose | Access |
|---|---|---|
| pgAdmin 4 | EXPLAIN ANALYZE, schema browser, table stats | http://localhost:5050 |
| Adminer | Quick SQL execution, multi-DB | http://localhost:8082 |
| Grafana `pg-learning-overview` | Pre-built dashboard: connections, cache, queries, locks, indexes | http://localhost:3000 |
| Prometheus | Raw metrics exploration, PromQL | http://localhost:9090 |
| `pg_stat_statements` | Top queries by time/calls | Requires setup (see below) |
| `pg_buffercache` | Buffer cache inspection | Extension available; used in advanced lessons |

---

## Health checks

No automated health checks configured. Manual check:

```bash
docker exec cfp_postgres pg_isready -U cfp -d cfp
```

---

## Audit events

Audit table patterns are taught as lesson content (Stage 11). The repo itself does not implement audit logging — it teaches how to build it in PostgreSQL.

---

## pg_stat_statements setup (one-time)

Required before Grafana query stats panels work:

```bash
bash scripts/dashboards/enable-pg-stat-statements.sh
```

This runs `ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements'`, restarts the container, and creates the extension.

**Status:** Not yet run (recorded blocker in `memory.md`).

---

## Grafana dashboard: pg-learning-overview

Pre-provisioned at `tools/dashboards/grafana/dashboards/pg-learning-overview.json`.

Panels:
- Active connections (stat)
- Cache hit rate % (stat)
- Installed extensions (stat)
- User tables (stat)
- Table statistics: seq scans, idx scans, live/dead rows (table)
- Active queries from `pg_stat_activity` (table)
- Index usage: idx_scan, tuple reads (table)
- Blocked locks from `pg_locks` (table)

---

## Gaps

| Gap | Priority | Notes |
|---|---|---|
| `pg_stat_statements` not enabled | P1 | Run setup script once to unlock query stats panels |
| RedisInsight not pre-configured | P3 | Manual step: add cfp_redis host on first open |
| No Ollama model pulled | P3 | Run: `docker exec cfp_ollama ollama pull llama3.2:3b` |
| No alerting | P3 | Not needed for a learning environment |

---

## Recommended minimal improvements

1. Run `enable-pg-stat-statements.sh` to unlock query stats.
2. Add a health check step to `validate-env.sh` (ping each dashboard port).
3. When Stage 6 (observability) lessons are created, add panel-specific learning exercises.
