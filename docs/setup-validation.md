# Setup Validation

Generated: 2026-05-16  
Phase: 7

---

## Clean-user setup steps

| Step | Command | Expected | Actual | Status | Fix |
|---|---|---|---|---|---|
| Clone repo | `git clone https://github.com/rajaghv-dev/l-pgsql.git` | Repo clones cleanly | Not tested in this session | Assumed OK | — |
| Start PostgreSQL | `docker run ...` (cfp_postgres already running) | Container running | Confirmed via prior sessions | OK (from memory.md) | — |
| Start dashboard stack | `docker compose -f tools/dashboards/docker-compose.yml up -d` | 8 services start | Confirmed running (Session 1) | OK | — |
| Enable pg_stat_statements | `bash scripts/dashboards/enable-pg-stat-statements.sh` | Extension created; container restarted | NOT run in this session | Pending | Run once before Grafana query panels |
| Validate environment | `bash scripts/stage-00/validate-env.sh` | 45 PASS, 5 WARN, 0 FAIL | Last result: 45 PASS, 5 WARN, 0 FAIL (2026-05-03) | OK | Re-run to confirm current state |
| Validate session files | `bash scripts/stage-00/validate-session-files.sh` | 26 PASS, 0 FAIL | Last result: 26 PASS, 0 FAIL (2026-05-03) | OK | — |
| Validate extensions | `docker exec -i cfp_postgres psql -U cfp -d cfp < scripts/stage-00/validate-extensions.sql` | All required extensions available | Last validated 2026-05-03 | OK | Re-run after any container changes |
| Connect to pgAdmin | http://localhost:5050 | Login with admin/admin; cfp_postgres pre-wired | Confirmed (Session 1) | OK | — |
| Connect to Grafana | http://localhost:3000 | pg-learning-overview dashboard visible | Confirmed (Session 1) | OK | — |
| Run a learning SQL | `docker exec cfp_postgres psql -U cfp -d cfp -c "SELECT version();"` | PostgreSQL 16.13 | Not re-run this session | Assumed OK | — |

---

## Known blockers

| Blocker | Status | Workaround |
|---|---|---|
| `pg_stat_statements` not enabled | Persists after container restart unless setup script is run | `bash scripts/dashboards/enable-pg-stat-statements.sh` |
| psql not on host PATH | Known limitation | Always use `docker exec cfp_postgres psql ...` |
| RedisInsight: cfp_redis not pre-wired | First open requires manual host entry | Add host: `cfp_redis`, port: `6379` |
| Ollama: no models pulled | Container runs but has no models | `docker exec cfp_ollama ollama pull llama3.2:3b` |
| `pg_cron`, `timescaledb`, `postgis`, `pgaudit` not available | Not in `pgvector/pgvector:pg16` image | Lessons using these are marked TODO |

---

## Environment-specific notes

- All validation was last run on: 2026-05-03
- Working directory: `/mnt/d/wsl/l-pgsql/` (WSL2 on Windows)
- Shell: bash (WSL2)
- Docker: 29.4.1
- This repo does not have a `Makefile` or `package.json` — no build step exists
