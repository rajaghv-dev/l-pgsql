# Extension Map

Overview of PostgreSQL extensions covered in this repo.

All extensions below are available in the local `cfp_postgres` container (pgvector/pgvector:pg16) unless noted.

---

## Search and similarity

| Extension | Use case | Level | Available locally |
|-----------|----------|-------|-------------------|
| pgvector | Vector similarity search, AI embeddings | Intermediate+ | Yes |
| pg_trgm | Fuzzy string search, typo tolerance | Intermediate | Yes |
| unaccent | Accent-insensitive text search | Beginner+ | Yes |
| citext | Case-insensitive text column | Beginner+ | Yes |
| fuzzystrmatch | Soundex, Levenshtein, metaphone | Intermediate | Yes |

## Data types and structures

| Extension | Use case | Level | Available locally |
|-----------|----------|-------|-------------------|
| hstore | Key-value pairs in a column | Intermediate | Yes |
| ltree | Hierarchical label paths | Intermediate | Yes |
| cube | Multi-dimensional cubes | Advanced | Yes |
| earthdistance | Great-circle distance (needs cube) | Advanced | Yes |
| isn | International Standard Numbers (ISBN, etc.) | Intermediate | Yes |

## Indexing

| Extension | Use case | Level | Available locally |
|-----------|----------|-------|-------------------|
| btree_gin | GIN index for btree-comparable types | Intermediate | Yes |
| btree_gist | GiST index for btree-comparable types | Intermediate | Yes |
| bloom | Bloom filter indexes | Advanced | Yes |

## Security and crypto

| Extension | Use case | Level | Available locally |
|-----------|----------|-------|-------------------|
| pgcrypto | Hashing, encryption, UUID | Intermediate | Yes |
| sslinfo | TLS connection inspection | Advanced | Yes |
| pgaudit | Detailed audit logging | Intermediate | No — not in pgvector image |

## Observability and internals

| Extension | Use case | Level | Available locally |
|-----------|----------|-------|-------------------|
| pg_stat_statements | Query performance stats | Intermediate | Yes (needs config) |
| auto_explain | Log slow query execution plans | Advanced | Yes |
| pg_buffercache | Shared buffer cache inspection | Advanced | Yes |
| pageinspect | Low-level page inspection | Advanced | Yes |
| pgrowlocks | Row-level lock info | Advanced | Yes |
| pgstattuple | Table and index bloat stats | Advanced | Yes |

## Utilities and integrations

| Extension | Use case | Level | Available locally |
|-----------|----------|-------|-------------------|
| uuid-ossp | UUID generation | Beginner+ | Yes |
| tablefunc | Pivot / crosstab queries | Intermediate | Yes |
| tcn | Triggered change notification | Advanced | Yes |
| postgres_fdw | Foreign data wrapper to other PG instances | Advanced | Yes |
| dblink | Ad-hoc cross-database queries | Advanced | Yes |

## Not available locally (notable absences)

| Extension | Why notable |
|-----------|-------------|
| pg_cron | Job scheduling inside PostgreSQL |
| TimescaleDB | Time-series data (hypertables) |
| PostGIS | Geospatial data and queries |
| pgaudit | Detailed audit logging |

---

## How to install an extension

```sql
-- Run inside cfp_postgres container
CREATE EXTENSION IF NOT EXISTS extension_name;
```

Or via docker exec:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "CREATE EXTENSION IF NOT EXISTS extension_name;"
```

Note: `pg_stat_statements` requires `shared_preload_libraries = 'pg_stat_statements'` in `postgresql.conf` before it can be created.
