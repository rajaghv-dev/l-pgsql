# Agent Handoff

Read:
1. AGENT_BOOTSTRAP.md
2. CURRENT_STAGE.md
3. STAGES.md
4. DONE_CRITERIA.md
5. Matching STAGE_PROMPTS file
6. `.learning-session/repo-memory.md` (contains env details)

## Current state (as of 2026-05-03)

- Current stage: **Stage 2 — Templates and Validation Scripts** (Stage 1 completed with validation)
- Status: waiting for user permission to proceed to Stage 2

## Key environment facts

- Postgres: `docker exec cfp_postgres psql -U cfp -d cfp -c "..."`
- PostgreSQL 16.13, pgvector/pgvector:pg16 image
- psql NOT on host PATH — always use docker exec
- Git initialized at `/mnt/d/wsl/l-pgsql/`
- 48 extensions available including: `vector`, `pgcrypto`, `pg_stat_statements`, `pg_trgm`, `hstore`, `ltree`, `uuid-ossp`
- No `pg_cron`, no `timescaledb`, no `postgis`

## Rules

- Do not generate future stages without permission.
- Do not generate unsafe professional advice logic.
- Do not use real sensitive data.
- Validate before declaring completion.
- Stop after each stage and ask permission.
