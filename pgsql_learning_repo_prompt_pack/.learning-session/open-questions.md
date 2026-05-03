# Open Questions

## Resolved (Stage 0)

- **Which PostgreSQL version?** → 16.13 (pgvector/pgvector:pg16 Docker image)
- **Is Docker available?** → Yes, version 29.4.1
- **Is psql available?** → Not on host PATH; available inside `cfp_postgres` container
- **Which extensions are available locally?** → 48 extensions; key ones: `vector`, `pgcrypto`, `pg_stat_statements`, `pg_trgm`, `hstore`, `ltree`, `uuid-ossp`, `btree_gist`, `btree_gin`, `citext`; missing: `pg_cron`, `timescaledb`, `postgis`

## Open

- Should the learning repo be a new separate repo or live alongside the prompt pack at `/mnt/d/wsl/l-pgsql/`?
- Should a dedicated learning database/schema be created in the `cfp` Postgres instance, or should a separate DB be created?
- Is there a preferred naming convention for the learning DB/schema?
