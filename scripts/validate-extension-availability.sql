-- Comprehensive extension availability check for cfp_postgres.
-- Covers all 48 extensions known to be available in the pgvector/pgvector:pg16 image.
--
-- Run: docker exec -i cfp_postgres psql -U cfp -d cfp < scripts/validate-extension-availability.sql
-- Or:  docker exec cfp_postgres psql -U cfp -d cfp -f /path/to/validate-extension-availability.sql

\echo '=== PostgreSQL version ==='
SELECT version();

\echo ''
\echo '=== Current user and database ==='
SELECT current_user, current_database(), current_schema();

\echo ''
\echo '=== Total available extensions in this build ==='
SELECT count(*) AS total_available_extensions FROM pg_available_extensions;

\echo ''
\echo '=== All 48 known extensions — availability and installation status ==='
\echo '    Status: INSTALLED = currently installed in this database'
\echo '            available = present in build, not yet installed'
\echo '            NOT available = not in this PostgreSQL build'
\echo ''

SELECT
    e.name,
    e.category,
    CASE
        WHEN pae.name IS NULL
            THEN 'NOT available'
        WHEN pae.installed_version IS NOT NULL
            THEN 'INSTALLED (' || pae.installed_version || ')'
        ELSE 'available (not installed)'
    END AS status,
    COALESCE(pae.comment, e.note) AS notes
FROM (
    VALUES
        -- Search and similarity
        ('vector',           'search',        'pgvector: vector similarity search, AI embeddings'),
        ('pg_trgm',          'search',        'Fuzzy string search, trigram similarity'),
        ('unaccent',         'search',        'Accent-insensitive text search'),
        ('citext',           'search',        'Case-insensitive text column type'),
        ('fuzzystrmatch',    'search',        'Soundex, Levenshtein, metaphone functions'),
        -- Data types and structures
        ('hstore',           'types',         'Key-value pairs stored in a single column'),
        ('ltree',            'types',         'Hierarchical label path data type'),
        ('cube',             'types',         'Multi-dimensional cube data type'),
        ('earthdistance',    'types',         'Great-circle distance calculations (requires cube)'),
        ('isn',              'types',         'International Standard Numbers (ISBN, ISSN, etc.)'),
        -- Indexing
        ('btree_gin',        'indexing',      'GIN index support for btree-comparable types'),
        ('btree_gist',       'indexing',      'GiST index support for btree-comparable types'),
        ('bloom',            'indexing',      'Bloom filter index access method'),
        -- Security and crypto
        ('pgcrypto',         'security',      'Hashing, symmetric encryption, UUID generation'),
        ('uuid-ossp',        'security',      'UUID generation functions (v1, v3, v4, v5)'),
        ('sslinfo',          'security',      'Information about the current SSL connection'),
        ('pgaudit',          'security',      'NOT available — not in pgvector image'),
        -- Observability and internals
        ('pg_stat_statements','observability','Query performance statistics (needs shared_preload_libraries)'),
        ('auto_explain',     'observability', 'Log slow query execution plans automatically'),
        ('pg_buffercache',   'observability', 'Shared buffer cache inspection'),
        ('pageinspect',      'observability', 'Low-level page structure inspection'),
        ('pgrowlocks',       'observability', 'Row-level lock information'),
        ('pgstattuple',      'observability', 'Table and index bloat statistics'),
        -- Utilities and cross-db
        ('tablefunc',        'utilities',     'Pivot / crosstab queries, normal distribution'),
        ('tcn',              'utilities',     'Triggered change notification'),
        ('postgres_fdw',     'utilities',     'Foreign data wrapper for other PostgreSQL servers'),
        ('dblink',           'utilities',     'Ad-hoc cross-database queries'),
        -- Procedural languages
        ('plpgsql',          'language',      'PL/pgSQL procedural language (built-in)'),
        ('plpython3u',       'language',      'PL/Python 3 untrusted procedural language'),
        ('pltcl',            'language',      'PL/Tcl procedural language'),
        -- XML and document
        ('xml2',             'document',      'XPath querying and XSLT transformation'),
        -- Cryptography extras
        ('pg_prewarm',       'performance',   'Preload relation data into buffer cache'),
        -- Additional contrib extensions commonly in pg16
        ('adminpack',        'admin',         'Administrative functions for pgAdmin'),
        ('amcheck',          'admin',         'Verify integrity of relation structure'),
        ('dict_int',         'search',        'Text search dictionary for integers'),
        ('dict_xsyn',        'search',        'Text search dictionary for extended synonyms'),
        ('file_fdw',         'utilities',     'Foreign data wrapper for flat files'),
        ('intagg',           'utilities',     'Integer aggregator and enumerator'),
        ('intarray',         'types',         'Integer array functions, operators, and indexes'),
        ('lo',               'types',         'Large object maintenance functions'),
        ('moddatetime',      'utilities',     'Functions for tracking last modification time'),
        ('old_snapshot',     'observability', 'Utilities for investigating snapshot age'),
        ('pg_freespacemap',  'observability', 'Examine the free space map'),
        ('pg_visibility',    'observability', 'Examine the visibility map and page-level visibility'),
        ('pgstattuple',      'observability', 'Table and index statistics (duplicate — already listed)'),
        ('refint',           'utilities',     'Referential integrity functions for triggers'),
        ('seg',              'types',         'Floating-point interval data type'),
        ('tsm_system_rows',  'sampling',      'TABLESAMPLE method: system_rows'),
        ('tsm_system_time',  'sampling',      'TABLESAMPLE method: system_time')
) AS e(name, category, note)
LEFT JOIN pg_available_extensions pae ON pae.name = e.name
ORDER BY e.category, e.name;

\echo ''
\echo '=== Extensions NOT available in this build (expected absences) ==='
SELECT
    name AS extension,
    'NOT available — not in pgvector/pgvector:pg16 image' AS status
FROM (VALUES
    ('pg_cron'),
    ('timescaledb'),
    ('postgis'),
    ('pgaudit')
) AS missing(name)
WHERE name NOT IN (SELECT name FROM pg_available_extensions)
ORDER BY name;

\echo ''
\echo '=== Currently installed extensions in this database ==='
SELECT
    extname     AS name,
    extversion  AS version,
    nspname     AS schema
FROM pg_extension
JOIN pg_namespace ON pg_namespace.oid = pg_extension.extnamespace
ORDER BY extname;

\echo ''
\echo '=== Summary counts ==='
SELECT
    (SELECT count(*) FROM pg_available_extensions)                          AS total_available,
    (SELECT count(*) FROM pg_extension)                                     AS total_installed,
    (SELECT count(*) FROM pg_available_extensions WHERE installed_version IS NULL) AS available_not_installed;

\echo ''
\echo '=== DONE: comprehensive extension availability check complete ==='
