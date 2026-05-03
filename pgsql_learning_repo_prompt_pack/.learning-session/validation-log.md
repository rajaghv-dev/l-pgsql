# Validation Log

## Stage 0 — 2026-05-03

### Script: validate-session-files.sh
Result: **26 PASS, 0 FAIL**

| Check | Result | Notes |
|-------|--------|-------|
| All 11 `.learning-session/` files exist and non-empty | PASS | |
| All 7 control files exist and non-empty | PASS | |
| Stage prompt files spot-check | PASS | |
| Validation scripts exist | PASS | |
| `current-stage.md` contains `Stage: 0` | PASS | |
| `current-stage.md` contains `completed` | PASS | |
| `stage-history.md` has Stage 0 entry | PASS | |
| `validation-log.md` has Stage 0 entry | PASS | |

### Script: validate-env.sh
Result: **45 PASS, 5 WARN, 0 FAIL**

| Check | Result | Notes |
|-------|--------|-------|
| Git initialized | PASS | `main` branch |
| Git available | PASS | v2.43.0 |
| Docker available | PASS | v29.4.1 |
| Docker daemon running | PASS | |
| Container `cfp_postgres` running | PASS | |
| psql on host PATH | WARN | Not in PATH — use `docker exec` |
| psql in container | PASS | PostgreSQL 16.13 |
| Postgres connection | PASS | `cfp` user, `cfp` DB, `public` schema |
| User is superuser | PASS | Can CREATE EXTENSION |
| All 16 required extensions available | PASS | vector, pgcrypto, pg_stat_statements, pg_trgm, uuid-ossp, hstore, ltree, citext, btree_gin, btree_gist, unaccent, tablefunc, postgres_fdw, pageinspect, pg_buffercache, bloom |
| `pg_cron` optional | WARN | Not available in this build |
| `timescaledb` optional | WARN | Not available in this build |
| `postgis` optional | WARN | Not available in this build |
| `pgaudit` optional | WARN | Not available in this build |

### Script: validate-extensions.sql (run via docker exec)
Result: **all install tests passed; 1 known blocker**

| Extension | Install | Functional test | Notes |
|-----------|---------|-----------------|-------|
| vector (pgvector) | PASS (already installed, v0.8.2) | PASS — `[1,2,3] <-> [4,5,6]` = 5.196 | |
| pgcrypto | PASS | PASS — `gen_random_uuid()` works | |
| uuid-ossp | PASS | PASS — `uuid_generate_v4()` works | |
| pg_trgm | PASS | PASS — `similarity('hello','helo')` = 0.571 | |
| hstore | PASS | PASS — `'a=>1,b=>2'::hstore` works | |
| ltree | PASS | PASS — `'a.b.c'::ltree` works | |
| citext | PASS | PASS — `'Hello'::citext = 'hello'` = true | |
| unaccent | PASS | PASS — `unaccent('café')` = 'cafe' | |
| pg_stat_statements | PASS (CREATE EXTENSION) | **BLOCKED** — requires `shared_preload_libraries = 'pg_stat_statements'` in postgresql.conf; container restart required | |
| plpgsql | pre-installed | pre-installed | |

### Known blockers

- `pg_stat_statements` view is unusable until `shared_preload_libraries` is set and the container is restarted. Extension installs fine; querying the view fails with `must be loaded via shared_preload_libraries`. Workaround: mount a custom `postgresql.conf` or pass `-c shared_preload_libraries=pg_stat_statements` to the container.
- `pg_cron`, `timescaledb`, `postgis`, `pgaudit` are not available in the `pgvector/pgvector:pg16` image. Lessons for these will be marked TODO and use conceptual-only explanations.
- `psql` not on host PATH — all SQL execution uses `docker exec cfp_postgres psql -U cfp -d cfp`.
