# Repo Memory

This repo teaches PostgreSQL as a database plus an agent-safe state, memory, retrieval, permission, and audit substrate.

## Environment (as of Stage 0, 2026-05-03)

- **Working directory**: `/mnt/d/wsl/l-pgsql/`
- **Learning repo root**: will be created at `/mnt/d/wsl/l-pgsql/` (not yet initialized)
- **Git**: not initialized — `git init` required before Stage 1
- **Docker**: available, version 29.4.1
- **PostgreSQL**: 16.13, via Docker container `cfp_postgres` (image: `pgvector/pgvector:pg16`)
  - User: `cfp` | DB: `cfp` | Password: `cfp` | Port: 5432 (host-exposed)
  - Connect: `docker exec cfp_postgres psql -U cfp -d cfp`
- **psql on host**: NOT available — all psql commands run inside the container
- **Available extensions (48)**: includes `vector`, `pgcrypto`, `pg_stat_statements`, `pg_trgm`, `hstore`, `ltree`, `uuid-ossp`, `btree_gist`, `btree_gin`, `citext`, `tablefunc`, `postgres_fdw`, `dblink`, `pageinspect`, `pg_buffercache`, `bloom`, `cube`, `earthdistance`, `fuzzystrmatch`, `isn`, `unaccent`, `sslinfo`, `pgrowlocks`, `pgstattuple`, `tcn`, and others
- **Notable absences**: no `pg_cron`, no `timescaledb`, no `postgis`
- **Other containers running**: ollama (port 11434), redis (port 6379), netdata (restarting)

## Rules

- Work stage by stage.
- Stop after each stage.
- Validate before completion.
- Use references instead of long content.
- Add ontology notes to practices.
- Add MCP/agent perspective where relevant.
- Use synthetic data for regulated-domain examples.
- Avoid professional advice logic.
- Run all psql via: `docker exec cfp_postgres psql -U cfp -d cfp -c "..."`
