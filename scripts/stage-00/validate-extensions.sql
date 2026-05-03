-- Stage 0: Validate extensions are available and can be created.
-- Run: docker exec cfp_postgres psql -U cfp -d cfp -f /path/to/validate-extensions.sql
-- Or:  docker exec -i cfp_postgres psql -U cfp -d cfp < scripts/stage-00/validate-extensions.sql

\echo '=== PostgreSQL version ==='
SELECT version();

\echo ''
\echo '=== Current user and DB ==='
SELECT current_user, current_database(), current_schema();

\echo ''
\echo '=== Superuser status ==='
SELECT usesuper AS is_superuser FROM pg_user WHERE usename = current_user;

\echo ''
\echo '=== All available extensions (count) ==='
SELECT count(*) AS total_available_extensions FROM pg_available_extensions;

\echo ''
\echo '=== Required extensions — availability check ==='
SELECT
    name,
    CASE WHEN installed_version IS NOT NULL THEN 'INSTALLED' ELSE 'available (not installed)' END AS status,
    comment
FROM pg_available_extensions
WHERE name IN (
    'vector',
    'pgcrypto',
    'pg_stat_statements',
    'pg_trgm',
    'uuid-ossp',
    'hstore',
    'ltree',
    'citext',
    'btree_gin',
    'btree_gist',
    'unaccent',
    'tablefunc',
    'postgres_fdw',
    'pageinspect',
    'pg_buffercache',
    'bloom',
    'plpgsql'
)
ORDER BY name;

\echo ''
\echo '=== Optional extensions — availability check ==='
SELECT
    name,
    CASE WHEN installed_version IS NOT NULL THEN 'INSTALLED' ELSE 'NOT available' END AS status,
    comment
FROM (
    SELECT name, installed_version, comment FROM pg_available_extensions
    WHERE name IN ('pg_cron', 'timescaledb', 'postgis', 'pgaudit')
    UNION ALL
    -- Include rows for extensions that don't appear at all
    SELECT e.name, NULL, 'not available in this build'
    FROM (VALUES ('pg_cron'), ('timescaledb'), ('postgis'), ('pgaudit')) AS e(name)
    WHERE e.name NOT IN (SELECT name FROM pg_available_extensions)
) sub
ORDER BY name;

\echo ''
\echo '=== Test: install vector extension (pgvector) ==='
CREATE EXTENSION IF NOT EXISTS vector;
SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';

\echo ''
\echo '=== Test: install pgcrypto ==='
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SELECT gen_random_uuid() AS sample_uuid;

\echo ''
\echo '=== Test: install uuid-ossp ==='
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
SELECT uuid_generate_v4() AS sample_uuid_v4;

\echo ''
\echo '=== Test: install pg_trgm ==='
CREATE EXTENSION IF NOT EXISTS pg_trgm;
SELECT similarity('hello', 'helo') AS trgm_similarity;

\echo ''
\echo '=== Test: install hstore ==='
CREATE EXTENSION IF NOT EXISTS hstore;
SELECT 'a=>1, b=>2'::hstore AS sample_hstore;

\echo ''
\echo '=== Test: install ltree ==='
CREATE EXTENSION IF NOT EXISTS ltree;
SELECT 'a.b.c'::ltree AS sample_ltree;

\echo ''
\echo '=== Test: install citext ==='
CREATE EXTENSION IF NOT EXISTS citext;
SELECT 'Hello'::citext = 'hello' AS citext_case_insensitive;

\echo ''
\echo '=== Test: install unaccent ==='
CREATE EXTENSION IF NOT EXISTS unaccent;
SELECT unaccent('café') AS unaccented;

\echo ''
\echo '=== Test: install pg_stat_statements ==='
-- NOTE: pg_stat_statements requires shared_preload_libraries = 'pg_stat_statements'
-- in postgresql.conf. CREATE EXTENSION works, but querying the view requires a restart.
-- To enable: add POSTGRES_INITDB_ARGS or mount a custom postgresql.conf with the setting.
-- For now: CREATE EXTENSION only — querying the view is documented as a known blocker.
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
-- SKIP: SELECT count(*) FROM pg_stat_statements -- requires shared_preload_libraries

\echo ''
\echo '=== Test: vector basic operation ==='
SELECT '[1,2,3]'::vector AS sample_vector,
       '[1,2,3]'::vector <-> '[4,5,6]'::vector AS l2_distance;

\echo ''
\echo '=== Currently installed extensions ==='
SELECT extname, extversion FROM pg_extension ORDER BY extname;

\echo ''
\echo '=== DONE: Stage 0 extension validation complete ==='
