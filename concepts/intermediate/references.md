# Intermediate References

Curated references for intermediate-level PostgreSQL concepts.

See also: [root references.md](../../references.md) for the full curated list.

---

## Core references for this level

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|------------|
| Use The Index, Luke | https://use-the-index-luke.com/ | Free Book | Intermediate | 4–6 h | Index design through execution plans; best free resource on this topic |
| EXPLAIN / ANALYZE (official) | https://www.postgresql.org/docs/16/using-explain.html | Official Docs | Intermediate | 1 h | Reading plan nodes, cost estimates, actual rows, buffers |
| MVCC (official) | https://www.postgresql.org/docs/16/mvcc.html | Official Docs | Intermediate | 1 h | Snapshot isolation, visibility rules, xmin/xmax |
| Row Level Security | https://www.postgresql.org/docs/16/ddl-rowsecurity.html | Official Docs | Intermediate | 45 min | Policy syntax, USING vs WITH CHECK, multi-tenant patterns |
| pg_stat_statements | https://www.postgresql.org/docs/16/pgstatstatements.html | Official Docs | Intermediate | 30 min | Per-query stats; first place to look when a query is slow |
| Transactions and Isolation Levels | https://www.postgresql.org/docs/16/transaction-iso.html | Official Docs | Intermediate | 1 h | READ COMMITTED, REPEATABLE READ, SERIALIZABLE semantics |
| Full-Text Search | https://www.postgresql.org/docs/16/textsearch.html | Official Docs | Intermediate | 2 h | tsvector, tsquery, ts_rank, GIN indexes, custom dictionaries |
| JSONB Functions | https://www.postgresql.org/docs/16/functions-json.html | Official Docs | Intermediate | 1 h | Operators, path queries, jsonb_set, GIN index strategies |
| Routine Vacuuming | https://www.postgresql.org/docs/16/routine-vacuuming.html | Official Docs | Intermediate | 1 h | Autovacuum config, bloat detection, visibility map |
| explain.depesz.com | https://explain.depesz.com/ | Blog | Intermediate | 10 min | Paste EXPLAIN ANALYZE output; get color-coded bottleneck view |
