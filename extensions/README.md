# l-pgsql/extensions

Extension learning files for the PostgreSQL learning repo. Each file covers one extension in depth: purpose, install, core operations, index types, performance, and agent/ontology perspective.

All SQL in these files is marked **blocked: Docker not accessible** (current session constraint). PostGIS files additionally note **blocked: PostGIS not available in cfp_postgres image**.

See also: [extension-map.md](../extension-map.md) for a full availability table.

---

## Index

### Vector

| File | Extension | Level | Locally available |
|------|-----------|-------|-------------------|
| [vector/pgvector.md](vector/pgvector.md) | pgvector | Intermediate | Yes |

### Search and similarity

| File | Extension | Level | Locally available |
|------|-----------|-------|-------------------|
| [search/pg-trgm.md](search/pg-trgm.md) | pg_trgm | Intermediate | Yes |
| [search/unaccent.md](search/unaccent.md) | unaccent | Beginner+ | Yes |
| [search/fuzzystrmatch.md](search/fuzzystrmatch.md) | fuzzystrmatch | Intermediate | Yes |

### Geospatial

| File | Extension | Level | Locally available |
|------|-----------|-------|-------------------|
| [geospatial/postgis.md](geospatial/postgis.md) | PostGIS | Advanced | **No** — not in cfp_postgres image |

### Security and crypto

| File | Extension | Level | Locally available |
|------|-----------|-------|-------------------|
| [security/pgcrypto.md](security/pgcrypto.md) | pgcrypto | Intermediate | Yes |

### Observability

| File | Extension | Level | Locally available |
|------|-----------|-------|-------------------|
| [observability/pg-stat-statements.md](observability/pg-stat-statements.md) | pg_stat_statements | Intermediate | Yes (needs config) |

### Data types

| File | Extension | Level | Locally available |
|------|-----------|-------|-------------------|
| [data-types/ltree.md](data-types/ltree.md) | ltree | Intermediate | Yes |
| [data-types/hstore.md](data-types/hstore.md) | hstore | Intermediate | Yes |
| [data-types/uuid-ossp.md](data-types/uuid-ossp.md) | uuid-ossp | Beginner+ | Yes |

### Foreign data

| File | Extension | Level | Locally available |
|------|-----------|-------|-------------------|
| [foreign-data/postgres-fdw.md](foreign-data/postgres-fdw.md) | postgres_fdw | Advanced | Yes |

### Indexing

| File | Extension | Level | Locally available |
|------|-----------|-------|-------------------|
| [indexing/btree-gin.md](indexing/btree-gin.md) | btree_gin | Intermediate | Yes |
| [indexing/btree-gist.md](indexing/btree-gist.md) | btree_gist | Intermediate | Yes |
| [indexing/bloom.md](indexing/bloom.md) | bloom | Advanced | Yes |

---

## Status legend

- Full coverage: install, core ops, index types, performance, when to use, agent perspective
- Placeholder: header + "content coming in a future stage"

| File | Status |
|------|--------|
| vector/pgvector.md | Full coverage |
| search/pg-trgm.md | Full coverage |
| geospatial/postgis.md | Full coverage (reference only — not available locally) |
| security/pgcrypto.md | Full coverage |
| observability/pg-stat-statements.md | Full coverage |
| data-types/ltree.md | Full coverage |
| foreign-data/postgres-fdw.md | Full coverage |
| data-types/hstore.md | Full coverage |
| search/unaccent.md | Placeholder |
| search/fuzzystrmatch.md | Placeholder |
| data-types/uuid-ossp.md | Placeholder |
| indexing/btree-gin.md | Placeholder |
| indexing/btree-gist.md | Placeholder |
| indexing/bloom.md | Placeholder |
