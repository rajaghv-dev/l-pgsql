# References

Curated free references for PostgreSQL learning.

---

## Official documentation

| Title | URL | Level | Why useful |
|-------|-----|-------|------------|
| PostgreSQL 16 Documentation | https://www.postgresql.org/docs/16/ | All | Authoritative reference for every feature |
| PostgreSQL Tutorial (official) | https://www.postgresql.org/docs/16/tutorial.html | Beginner | Structured intro from the PostgreSQL team |
| SQL Commands reference | https://www.postgresql.org/docs/16/sql-commands.html | All | Complete SQL command reference |
| System Catalogs | https://www.postgresql.org/docs/16/catalogs.html | Intermediate+ | pg_stat_* and pg_catalog tables |

---

## Free books

| Title | URL | Level | Why useful |
|-------|-----|-------|------------|
| The Internals of PostgreSQL | https://www.interdb.jp/pg/ | Advanced | Deep storage, WAL, MVCC, vacuum internals |
| Use The Index, Luke | https://use-the-index-luke.com/ | Intermediate | Index design explained with execution plans |

---

## Extension documentation

| Extension | URL | Notes |
|-----------|-----|-------|
| pgvector | https://github.com/pgvector/pgvector | Vector similarity search |
| pg_trgm | https://www.postgresql.org/docs/16/pgtrgm.html | Fuzzy string search |
| pgcrypto | https://www.postgresql.org/docs/16/pgcrypto.html | Encryption functions |
| ltree | https://www.postgresql.org/docs/16/ltree.html | Hierarchical data |
| hstore | https://www.postgresql.org/docs/16/hstore.html | Key-value in a column |
| pg_stat_statements | https://www.postgresql.org/docs/16/pgstatstatements.html | Query stats |
| auto_explain | https://www.postgresql.org/docs/16/auto-explain.html | Log slow query plans |
| pg_buffercache | https://www.postgresql.org/docs/16/pgbuffercache.html | Buffer cache inspection |
| pageinspect | https://www.postgresql.org/docs/16/pageinspect.html | Low-level page inspection |
| btree_gin | https://www.postgresql.org/docs/16/btree-gin.html | GIN for btree types |
| btree_gist | https://www.postgresql.org/docs/16/btree-gist.html | GiST for btree types |
| citext | https://www.postgresql.org/docs/16/citext.html | Case-insensitive text |
| unaccent | https://www.postgresql.org/docs/16/unaccent.html | Accent-insensitive search |
| uuid-ossp | https://www.postgresql.org/docs/16/uuid-ossp.html | UUID generation |
| tablefunc | https://www.postgresql.org/docs/16/tablefunc.html | Pivot / crosstab queries |
| postgres_fdw | https://www.postgresql.org/docs/16/postgres-fdw.html | Foreign data wrapper |

---

## Key topics — reference pointers

| Topic | Reference |
|-------|-----------|
| EXPLAIN / ANALYZE | https://www.postgresql.org/docs/16/using-explain.html |
| MVCC | https://www.postgresql.org/docs/16/mvcc.html |
| Locking | https://www.postgresql.org/docs/16/explicit-locking.html |
| Row Level Security | https://www.postgresql.org/docs/16/ddl-rowsecurity.html |
| Full-text search | https://www.postgresql.org/docs/16/textsearch.html |
| JSONB | https://www.postgresql.org/docs/16/functions-json.html |
| Partitioning | https://www.postgresql.org/docs/16/ddl-partitioning.html |
| Vacuuming | https://www.postgresql.org/docs/16/routine-vacuuming.html |
| WAL | https://www.postgresql.org/docs/16/wal.html |
| Roles and privileges | https://www.postgresql.org/docs/16/user-manag.html |
| PL/pgSQL | https://www.postgresql.org/docs/16/plpgsql.html |

---

## TODO: verify and expand

- TODO: Find verified reference for pgvector ANN benchmarks.
- TODO: Find verified reference for TimescaleDB concepts (not installed locally).
- TODO: Find verified reference for PostGIS concepts (not installed locally).
- TODO: Find short YouTube videos (< 15 min) for beginner topics.
