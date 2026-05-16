# PostgreSQL Extension Ecosystem Map

PostgreSQL's extension system allows adding types, functions, operators, and index methods without modifying the core server. This diagram categorizes the most useful extensions by purpose.

```mermaid
flowchart TD
    PG["PostgreSQL Core"]

    subgraph SEARCH["Search & Similarity"]
        PGVEC["pgvector\nvector similarity search\nANN indexes: ivfflat, hnsw"]
        TRGM["pg_trgm\ntrigram similarity\nLIKE / ILIKE acceleration"]
        UNACC["unaccent\nremove accent marks\nfor normalized text search"]
        FUZZY["fuzzystrmatch\nLevenshtein, soundex\nphonetic matching"]
    end

    subgraph SEC["Security"]
        CRYPTO["pgcrypto\ndigest, encrypt, gen_random_bytes\npgp_sym_encrypt"]
        RLS["Row Level Security\nbuilt-in — not an extension\nper-row access policies"]
        SSLI["sslinfo\ninspect SSL connection\ncert details"]
    end

    subgraph OBS["Observability"]
        PGSS["pg_stat_statements\nquery-level stats\ncalls, total_time, mean_time"]
        PGBC["pg_buffercache\nshared buffer inspection\nhit/miss per page"]
        PGINS["pageinspect\nraw page contents\nheap tuples, index entries"]
    end

    subgraph TYPES["Data Types"]
        LTREE["ltree\nhierarchical label paths\nA.B.C pattern matching"]
        HSTORE["hstore\nkey-value in one column\nsimpler alternative to JSONB"]
        CITEXT["citext\ncase-insensitive text type\nno LOWER() needed in queries"]
        CUBE["cube\nmulti-dimensional points\nand ranges"]
        EARTH["earthdistance\ngreat-circle distance\nusing cube"]
        ISN["isn\nISBN, EAN, UPC types\nformat validation built-in"]
    end

    subgraph IDX["Indexing"]
        BTGIN["btree_gin\nGIN indexes on scalar types\ncombined with other GIN columns"]
        BTGIST["btree_gist\nGiST indexes on scalar types\nexclusion constraints"]
        BLOOM["bloom\nprobabilistic index\nmulti-column equality, small size"]
    end

    subgraph FDW["Foreign Data"]
        PGFDW["postgres_fdw\nquery remote PostgreSQL\nas local tables"]
        DBLINK["dblink\ncross-database queries\nin same cluster"]
    end

    PG --> SEARCH
    PG --> SEC
    PG --> OBS
    PG --> TYPES
    PG --> IDX
    PG --> FDW
```

## Installation pattern

```sql
-- Check if available
SELECT name, default_version FROM pg_available_extensions WHERE name = 'pgvector';

-- Install (requires superuser or pg_extension_owner role)
CREATE EXTENSION IF NOT EXISTS pgvector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;  -- also needs shared_preload_libraries

-- List installed extensions
SELECT extname, extversion FROM pg_extension ORDER BY extname;
```

## Key notes

- `pg_stat_statements` requires `shared_preload_libraries = 'pg_stat_statements'` in `postgresql.conf` and a server restart before `CREATE EXTENSION` works.
- `pgvector` must be compiled and installed at the OS level before it appears in `pg_available_extensions`.
- `earthdistance` depends on `cube` — install `cube` first.
- `RLS` is a core PostgreSQL feature (not an extension) but is listed here for completeness as a security capability.
