# Architecture

Generated: 2026-05-16  
Phase: 5  
Source of truth: `arch.md` (authoritative full doc)

This file is a concise summary for the `docs/` directory. For complete diagrams, infrastructure details, and code examples, read `arch.md`.

---

## High-level purpose

A staged, first-principles PostgreSQL learning lab. Teaches PostgreSQL as a relational database engine AND as an agent-safe state/memory/retrieval/audit substrate. Built in 30 stages (0–29), each validated before the next begins.

---

## Main components

```
┌─────────────────────────────────────────────────────┐
│  Orchestration layer (pgsql_learning_repo_prompt_pack/)  │
│  Controls what gets built, when, and validates completion│
│  MASTER_SPEC → STAGES → CURRENT_STAGE → STAGE_PROMPTS   │
│  .learning-session/ = resumable session memory          │
└─────────────────────┬───────────────────────────────┘
                      │ generates
                      ▼
┌─────────────────────────────────────────────────────┐
│  Content layer (repo root)                          │
│  concepts/ practice/ examples/ extensions/          │
│  ontology/ diagrams/ design-principles/ reflections/│
│  scripts/ tools/                                    │
└─────────────────────────────────────────────────────┘
                      │ connects to
                      ▼
┌─────────────────────────────────────────────────────┐
│  Infrastructure (Docker)                            │
│  cfp_postgres (PG 16.13) + cfp_redis + cfp_ollama   │
│  Dashboard stack: pgAdmin/Adminer/Grafana/Prometheus │
└─────────────────────────────────────────────────────┘
```

---

## Data flow

```
User/Agent
  → reads AGENT_GUIDE.md + memory.md + sessions.md
  → reads CURRENT_STAGE + matching STAGE_PROMPTS file
  → works on current stage (creates lessons, SQL, docs)
  → validates via scripts/stage-00/ or future stage scripts
  → updates .learning-session/
  → stops and reports
  → waits for permission before next stage
```

---

## Control flow

Defined by `STAGES.md`. Each stage:
1. Has a prompt file (`STAGE_PROMPTS/stage-NN-*.md`)
2. Has completion criteria (`DONE_CRITERIA.md`)
3. Must pass validation before the next stage
4. Stores state in `.learning-session/`

---

## External dependencies

| Dependency | Role | Required? |
|---|---|---|
| Docker | Runs PostgreSQL + dashboards | Yes |
| PostgreSQL 16.13 (`cfp_postgres`) | Learning database | Yes |
| Redis 7 (`cfp_redis`) | Side service for queue/cache lessons | Optional |
| Ollama (`cfp_ollama`) | LLM for AI/vector lessons | Optional |
| Grafana/Prometheus stack | Observability learning | Optional |

---

## Configuration model

- PostgreSQL credentials: `cfp/cfp` (local dev only, hardcoded in scripts and compose)
- Dashboard credentials: `admin/admin` for pgAdmin/Grafana (local dev only)
- All config lives in `tools/dashboards/docker-compose.yml` and `scripts/`
- No environment variable injection needed for basic use

---

## Error handling model

- Bash scripts use `set -euo pipefail` + pass/fail/warn counters
- SQL scripts use `CREATE EXTENSION IF NOT EXISTS` (idempotent)
- Stage validation must show 0 FAIL before a stage is marked complete

---

## Observability model

See `docs/observability.md` for the full breakdown.

- Grafana dashboard: `pg-learning-overview` (pre-provisioned)
- Prometheus scrapes postgres_exporter and redis_exporter
- `pg_stat_statements` requires one-time setup script

---

## Security model

- Local dev environment only — not intended for production deployment
- Default credentials are known and documented
- No secrets, API keys, or production data anywhere in the repo
- RLS, pgcrypto, audit tables taught as subject matter in lessons

---

## Extension points

- New stages added by creating files in `STAGE_PROMPTS/` and extending `STAGES.md`
- New lessons follow the template in `MASTER_SPEC.md`
- New dashboard panels added to `tools/dashboards/grafana/dashboards/`

---

## Known limitations

- No `pg_cron`, `timescaledb`, `postgis`, `pgaudit` in the local container
- `pg_stat_statements` requires one-time setup (see `scripts/dashboards/enable-pg-stat-statements.sh`)
- RedisInsight requires manually adding `cfp_redis` host on first open
- Ollama has no models pulled by default (`docker exec cfp_ollama ollama pull llama3.2:3b`)
- Content directories are placeholders until Stages 3–29 run
