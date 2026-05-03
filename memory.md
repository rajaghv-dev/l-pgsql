# memory.md

Minimum-read reference for a new agent session. Read this + `sessions.md` before anything else.

---

## Environment (verified 2026-05-03)

| Item | Value |
|------|-------|
| Repo root | `/mnt/d/wsl/l-pgsql/` |
| Git remote | https://github.com/rajaghv-dev/l-pgsql.git (main branch) |
| PostgreSQL | 16.13 via container `cfp_postgres` (image: `pgvector/pgvector:pg16`) |
| PG connect | `docker exec cfp_postgres psql -U cfp -d cfp -c "..."` |
| PG creds | user: cfp, db: cfp, pass: cfp, port: 5432 |
| psql on host | NOT available — always use docker exec |
| Redis | `cfp_redis`, port 6379 |
| Ollama | `cfp_ollama`, port 11434 |
| Docker network | all above containers on `cfp_default` (172.18.0.0/16) |
| pg_stat_statements | NOT enabled — run `bash scripts/dashboards/enable-pg-stat-statements.sh` first |

## Extensions available (48 total)

Installed: `vector`, `pgcrypto`, `pg_trgm`, `hstore`, `ltree`, `uuid-ossp`, `btree_gist`, `btree_gin`, `citext`, `tablefunc`, `postgres_fdw`, `dblink`, `pageinspect`, `pg_buffercache`, `bloom`, `cube`, `earthdistance`, `fuzzystrmatch`, `isn`, `unaccent`, `sslinfo`, `pgrowlocks`, `pgstattuple`, `tcn`

NOT available: `pg_cron`, `timescaledb`, `postgis`, `pgaudit`

`pg_stat_statements` available but requires `ALTER SYSTEM SET shared_preload_libraries` + container restart.

## Dashboard stack

Start: `docker compose -f tools/dashboards/docker-compose.yml up -d`

| Service | Port | Notes |
|---------|------|-------|
| pgAdmin 4 | 5050 | pre-wired to cfp_postgres (admin/admin) |
| Adminer | 8082 | server: cfp_postgres, user/pass: cfp |
| Grafana | 3000 | pg-learning-overview dashboard pre-loaded |
| Prometheus | 9090 | scrapes postgres + redis exporters |
| postgres_exporter | 9187 | PG → Prometheus |
| redis_exporter | 9121 | Redis → Prometheus |
| RedisInsight | 5540 | add cfp_redis host manually on first open |
| Open WebUI | 8080 | connects to cfp_ollama automatically |

## Key file locations

| File | Purpose |
|------|---------|
| `arch.md` | Full repo architecture, infra diagram, code examples |
| `sessions.md` | Session log and current stage status |
| `memory.md` | This file — env facts, rules, layout |
| `AGENT_GUIDE.md` | Bootstrap sequence for coding agents |
| `learning-roadmap.md` | Stage map overview |
| `pgsql_learning_repo_prompt_pack/CURRENT_STAGE.md` | Active stage |
| `pgsql_learning_repo_prompt_pack/STAGES.md` | Full 0–29 stage roadmap |
| `pgsql_learning_repo_prompt_pack/DONE_CRITERIA.md` | Completion rules |
| `pgsql_learning_repo_prompt_pack/.learning-session/` | All session memory files |

## Rules (non-negotiable)

- Work one stage at a time. Stop after each stage. Ask permission before continuing.
- Never mark complete without validation. Use: `completed with validation` / `partially completed; validation blocked because...` / `incomplete; requires repair`
- All SQL runs via `docker exec cfp_postgres psql -U cfp -d cfp -c "..."`
- Use synthetic data for all regulated-domain examples (legal, medical, financial, pharma)
- Never add professional advice logic
- Use references instead of long content dumps
- Stop condition: after each stage, output the standard stage report from `STAGES.md` and ask permission

## Obsidian

`.obsidian/` is present — open this folder as a vault to use graph view for ontology visualization.
