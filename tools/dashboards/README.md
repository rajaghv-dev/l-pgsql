# Dashboard Stack

Observability and management dashboards for the PostgreSQL learning repo.
All services run on the `cfp_default` Docker network so they reach `cfp_postgres`, `cfp_redis`, and `cfp_ollama` by container name.

---

## Quick start

```bash
# Step 1 — enable pg_stat_statements (one time, restarts the container)
bash scripts/dashboards/enable-pg-stat-statements.sh

# Step 2 — start all dashboards
docker compose -f tools/dashboards/docker-compose.yml up -d

# Step 3 — open them (see URLs below)
```

---

## Dashboard map

| Dashboard | URL | Credentials | What it teaches |
|-----------|-----|-------------|-----------------|
| pgAdmin 4 | http://localhost:5050 | admin / admin | Schema, EXPLAIN, table stats |
| Adminer | http://localhost:8082 | server: cfp_postgres, user: cfp, pass: cfp, db: cfp | Quick SQL, multi-DB browser |
| Grafana | http://localhost:3000 | admin / admin | Metrics, query stats, cache, locks |
| Prometheus | http://localhost:9090 | — | Raw metrics, PromQL |
| RedisInsight | http://localhost:5540 | — | Redis keys, memory, commands |
| Open WebUI | http://localhost:8080 | — | Ollama chat and embeddings |

---

## pgAdmin 4 — PostgreSQL management

**What it teaches:** visual schema browser, query editor, EXPLAIN plan viewer, server statistics.

### First use
1. Open http://localhost:5050
2. Login: admin@local.dev / admin
3. `cfp_postgres` server is pre-configured — expand it in the left panel.

### Learning path inside pgAdmin
| Task | Where |
|------|-------|
| Browse tables and columns | Left panel → Databases → cfp → Schemas → public → Tables |
| Run SQL | Tools → Query Tool |
| See visual EXPLAIN | Run `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) <your query>;` in Query Tool, then click the Explain tab |
| Check table size and bloat | Right-click table → Properties → Statistics |
| Monitor connections | Dashboard tab on the server node |
| View server activity | Tools → Server Activity |

### Practice SQL to run in pgAdmin
```sql
-- What tables exist?
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables WHERE schemaname = 'public' ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- What indexes exist?
SELECT tablename, indexname, indexdef FROM pg_indexes WHERE schemaname = 'public';

-- What extensions are installed?
SELECT name, default_version, installed_version, comment FROM pg_available_extensions WHERE installed_version IS NOT NULL ORDER BY name;

-- Cache hit rate
SELECT round(100.0 * blks_hit / nullif(blks_hit + blks_read, 0), 2) AS cache_hit_pct FROM pg_stat_database WHERE datname = 'cfp';
```

---

## Adminer — lightweight SQL browser

**What it teaches:** fast SQL execution, table inspection, works across PG and other databases.

### First use
1. Open http://localhost:8082
2. System: PostgreSQL, Server: cfp_postgres, Username: cfp, Password: cfp, Database: cfp

### Learning uses
- Run ad-hoc SQL during practice sessions
- Browse table data visually
- Export query results as CSV

---

## Grafana — metrics and dashboards

**What it teaches:** time-series data, query performance over time, cache stats, lock monitoring.

### Pre-provisioned resources
- **Datasource: PostgreSQL** (uid: `cfp-postgres`) — direct SQL queries
- **Datasource: Prometheus** (uid: `cfp-prometheus`) — time-series metrics
- **Dashboard: PostgreSQL Learning Overview** — connections, cache hit rate, table stats, active queries, locks, index usage

### Find the pre-built dashboard
Dashboards → Browse → Learning folder → "PostgreSQL Learning Overview"

### What each panel teaches
| Panel | PostgreSQL concept |
|-------|--------------------|
| Active connections | `pg_stat_activity` — who is connected |
| Buffer cache hit rate | `pg_stat_database` — shared buffer efficiency |
| Table statistics | `pg_stat_user_tables` — seq vs index scans, live/dead rows |
| Active queries | `pg_stat_activity` — runtime query inspection |
| Index usage | `pg_stat_user_indexes` — which indexes are being used |
| Locks | `pg_locks` — blocked queries |

### Adding pg_stat_statements panel (after enabling it)
1. Edit the PostgreSQL Learning Overview dashboard
2. Add panel → PostgreSQL datasource
3. SQL:
```sql
SELECT query, calls, round(total_exec_time::numeric, 2) AS total_ms,
       round(mean_exec_time::numeric, 2) AS mean_ms, rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

### Community dashboard IDs (import via Grafana → Dashboards → Import)
| ID | Name | What it shows |
|----|------|---------------|
| 9628 | PostgreSQL Database | Full postgres_exporter dashboard |
| 11835 | Redis Dashboard | Redis memory, ops, keys |
| 1860 | Node Exporter Full | System CPU, memory, disk |

---

## Prometheus — metrics collection

**What it teaches:** scraping, PromQL, time-series metrics for PostgreSQL and Redis.

### Useful PromQL queries in Prometheus UI
```promql
# PostgreSQL connections
pg_stat_activity_count

# PostgreSQL database size
pg_database_size_bytes{datname="cfp"}

# Redis connected clients
redis_connected_clients

# Redis memory used
redis_memory_used_bytes
```

### Targets check
Open http://localhost:9090/targets — both `postgres` and `redis` should show UP.

---

## RedisInsight — Redis GUI

**What it teaches:** Redis data structures, key inspection, memory analysis, command profiling.

### First use
1. Open http://localhost:5540
2. Add database: host `cfp_redis`, port `6379`

### Learning uses
| Task | Where |
|------|-------|
| Browse keys | Browser tab |
| Run Redis commands | Workbench tab |
| Monitor commands in real time | Profiler tab |
| Memory analysis | Analysis Tools tab |

### Practice commands
```redis
PING
SET learning:session "started"
GET learning:session
KEYS learning:*
INFO server
INFO memory
```

---

## Open WebUI — Ollama chat and embedding UI

**What it teaches:** using local LLMs, prompt engineering, embedding concepts.

### First use
1. Open http://localhost:8080
2. No login required (auth disabled for local use)
3. Select a model from the top dropdown (pulled models from cfp_ollama appear automatically)

### Learning uses for PostgreSQL context
- Ask the LLM to explain PostgreSQL concepts
- Generate test SQL queries
- Discuss query optimization strategies
- Explore how vector embeddings relate to pgvector

---

## Obsidian — ontology and knowledge graph

**What it teaches:** concept mapping, ontology visualization, mental model building.

### Already configured
The `.obsidian/` directory is present — open this repo as an Obsidian vault.

### How to use for learning
1. Open Obsidian → Open folder as vault → select `/mnt/d/wsl/l-pgsql/` (or the Windows path equivalent)
2. Use **Graph View** (left sidebar) to see connections between linked markdown files
3. Each concept lesson links to related concepts using `[[concept-name]]` links
4. The `ontology/` folder contains concept maps — view them in Graph View

### Link conventions used in this repo
- `[[index-types]]` links to the index-types lesson
- `[[btree]]`, `[[gin]]`, `[[gist]]` link to index sub-concepts
- `[[mvcc]]` links to the MVCC concept
- Graph view will show clusters: beginner → intermediate → advanced

---

## Troubleshooting

### pgAdmin shows no server
Check that `tools/dashboards/pgadmin/pgpass` has permissions 600 inside the container:
```bash
docker exec dash_pgadmin chmod 600 /pgadmin4/pgpass
docker restart dash_pgadmin
```

### Grafana shows "no data" on pg_stat_statements panels
Run `scripts/dashboards/enable-pg-stat-statements.sh` first, then restart the dashboard stack.

### Prometheus targets DOWN
Check container names match: `dash_postgres_exporter` and `dash_redis_exporter` must be running.
```bash
docker compose -f tools/dashboards/docker-compose.yml ps
```

### Open WebUI shows no models
Pull a model into Ollama first:
```bash
docker exec cfp_ollama ollama pull llama3.2:3b
```

### Port conflict
Edit port mappings in `tools/dashboards/docker-compose.yml` if a port is already in use.
