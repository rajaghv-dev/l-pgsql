# References

Curated free references for every topic covered in this PostgreSQL learning repo.

Legend — **Type**: Official Docs, Free Book, Video, Blog, GitHub, Wiki | **Level**: Beginner, Intermediate, Advanced, All

---

## 1. Official PostgreSQL Documentation

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|------------|
| PostgreSQL 16 Documentation (root) | https://www.postgresql.org/docs/16/ | Official Docs | All | reference | Authoritative entry point for every feature |
| SQL Commands reference | https://www.postgresql.org/docs/16/sql-commands.html | Official Docs | All | reference | Complete alphabetical SQL command syntax |
| Tutorial (official) | https://www.postgresql.org/docs/16/tutorial.html | Official Docs | Beginner | 2–3 h | Structured intro written by the PostgreSQL team |
| Data Types | https://www.postgresql.org/docs/16/datatype.html | Official Docs | Beginner | 1 h | Full list of built-in types with storage sizes |
| Indexes | https://www.postgresql.org/docs/16/indexes.html | Official Docs | Intermediate | 2 h | B-tree, Hash, GiST, GIN, BRIN — when to use each |
| MVCC | https://www.postgresql.org/docs/16/mvcc.html | Official Docs | Intermediate | 1 h | How PostgreSQL handles concurrent transactions |
| Row Level Security | https://www.postgresql.org/docs/16/ddl-rowsecurity.html | Official Docs | Intermediate | 45 min | Policy syntax, BYPASSRLS, real-world SaaS patterns |
| EXPLAIN / ANALYZE | https://www.postgresql.org/docs/16/using-explain.html | Official Docs | Intermediate | 1 h | Reading query plans, cost model, actual vs estimated rows |
| Routine Vacuuming | https://www.postgresql.org/docs/16/routine-vacuuming.html | Official Docs | Intermediate | 1 h | Autovacuum tuning, bloat control, visibility maps |
| Full-Text Search | https://www.postgresql.org/docs/16/textsearch.html | Official Docs | Intermediate | 2 h | tsvector, tsquery, ranking, dictionaries |
| JSONB functions | https://www.postgresql.org/docs/16/functions-json.html | Official Docs | Intermediate | 1 h | jsonb operators, path queries, indexing strategies |
| Partitioning | https://www.postgresql.org/docs/16/ddl-partitioning.html | Official Docs | Advanced | 2 h | Range, list, hash partitioning; partition pruning |
| WAL and Replication | https://www.postgresql.org/docs/16/wal.html | Official Docs | Advanced | 2 h | Write-ahead log internals, durability guarantees |
| Locking | https://www.postgresql.org/docs/16/explicit-locking.html | Official Docs | Advanced | 1 h | Lock modes, deadlocks, advisory locks |
| PL/pgSQL | https://www.postgresql.org/docs/16/plpgsql.html | Official Docs | Intermediate | 2 h | Stored procedures, triggers, exception handling |
| pg_stat_statements | https://www.postgresql.org/docs/16/pgstatstatements.html | Official Docs | Intermediate | 30 min | Query-level CPU/IO stats; essential for tuning |
| System Catalogs | https://www.postgresql.org/docs/16/catalogs.html | Official Docs | Advanced | reference | pg_stat_*, pg_catalog — introspect the running system |
| Roles and Privileges | https://www.postgresql.org/docs/16/user-manag.html | Official Docs | Intermediate | 1 h | GRANT, REVOKE, role inheritance, pg_hba.conf |
| pg_dump / pg_restore | https://www.postgresql.org/docs/16/backup-dump.html | Official Docs | Intermediate | 30 min | Logical backup strategies |
| Connection Strings | https://www.postgresql.org/docs/16/libpq-connect.html | Official Docs | Beginner | 20 min | DSN format, environment variables, service files |

---

## 2. Free Books

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|------------|
| The Internals of PostgreSQL (Suzuki) | https://www.interdb.jp/pg/ | Free Book | Advanced | 10–15 h | Deep storage, heap tuples, WAL, MVCC, vacuum internals; free online |
| Use The Index, Luke | https://use-the-index-luke.com/ | Free Book | Intermediate | 4–6 h | Index design explained through execution plans; vendor-neutral |
| PostgreSQL Tutorial (postgresqltutorial.com) | https://www.postgresqltutorial.com/ | Free Book | Beginner | 8–12 h | Comprehensive topic-by-topic reference with runnable examples |
| The Art of PostgreSQL (excerpts) | https://theartofpostgresql.com/ | Free Book | Intermediate | variable | Advanced SQL patterns; some chapters free on the site |
| PostgreSQL: Up and Running (O'Reilly sample) | TODO: verify URL — search O'Reilly for free sample chapters | Free Book | Beginner | 2 h | Practical quick-start; check publisher for free chapter access |
| Bruce Momjian — PostgreSQL Internals (PDF) | https://momjian.us/main/writings/pgsql/internals.pdf | Free Book | Advanced | 6–8 h | Authoritative PDF on physical internals from a core developer |

---

## 3. SQL Learning

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|------------|
| SQLZoo | https://sqlzoo.net/ | Blog | Beginner | 4–6 h | Interactive browser exercises; instant feedback; no install needed |
| W3Schools SQL Tutorial | https://www.w3schools.com/sql/ | Blog | Beginner | 3–5 h | Quick-reference syntax with try-it editor; not PostgreSQL-specific |
| Mode Analytics SQL Tutorial | https://mode.com/sql-tutorial/ | Blog | Beginner | 4–6 h | Business-context examples; covers aggregations, window functions |
| Select Star SQL | https://selectstarsql.com/ | Free Book | Beginner | 3 h | Interactive book; teaches SQL using real executions data |
| Window Functions (official) | https://www.postgresql.org/docs/16/tutorial-window.html | Official Docs | Intermediate | 1 h | OVER, PARTITION BY, ROWS/RANGE — canonical reference |
| SQL Style Guide (Simon Holywell) | https://www.sqlstyle.guide/ | Blog | All | 30 min | Community-standard formatting rules; useful for code review |

---

## 4. PostgreSQL Internals

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|------------|
| The Internals of PostgreSQL (Suzuki) | https://www.interdb.jp/pg/ | Free Book | Advanced | 10–15 h | Storage layout, MVCC, vacuum, WAL — best free deep-dive available |
| Bruce Momjian — PostgreSQL Internals PDF | https://momjian.us/main/writings/pgsql/internals.pdf | Free Book | Advanced | 6–8 h | Slides-as-book format; covers concurrency, executor, planner |
| PostgreSQL Wiki — Slow Query Questions | https://wiki.postgresql.org/wiki/Slow_Query_Questions | Wiki | Advanced | 30 min | Diagnostic checklist from the community |
| PostgreSQL Wiki — Performance Optimization | https://wiki.postgresql.org/wiki/Performance_Optimization | Wiki | Advanced | 1 h | Config knobs, vacuum, explain — community-maintained |
| Citus Data Blog — PostgreSQL Internals | https://www.citusdata.com/blog/ | Blog | Advanced | variable | Deep technical posts on planner, sharding, partitioning |
| Robert Haas Blog (heap, WAL, planner) | https://rhaas.blogspot.com/ | Blog | Advanced | variable | Core developer blog; heap AM, logical replication internals |

---

## 5. pgvector / Vector Search

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|------------|
| pgvector GitHub README | https://github.com/pgvector/pgvector | GitHub | Intermediate | 30 min | Primary reference: install, operators, index types (IVFFlat, HNSW) |
| pgvector HNSW indexing | https://github.com/pgvector/pgvector#hnsw | GitHub | Advanced | 20 min | HNSW parameters (m, ef_construction), recall vs speed tradeoffs |
| Ollama documentation | https://ollama.com/docs | Official Docs | Intermediate | 1 h | Local embedding generation; integrates with pgvector workflows |
| OpenAI Embeddings guide | https://platform.openai.com/docs/guides/embeddings | Official Docs | Intermediate | 30 min | Embedding API reference; dimensions, distance metrics |
| ANN Benchmarks (ann-benchmarks.com) | https://ann-benchmarks.com/ | Wiki | Advanced | 30 min | Verified benchmark comparing ANN algorithms including HNSW |
| Supabase pgvector guide | https://supabase.com/docs/guides/ai/vector-columns | Blog | Intermediate | 20 min | Practical patterns: store, index, query vectors in Postgres |

---

## 6. Extensions

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|------------|
| pg_trgm (trigram search) | https://www.postgresql.org/docs/16/pgtrgm.html | Official Docs | Intermediate | 30 min | Fuzzy LIKE, similarity(), GIN/GiST index for text search |
| pgcrypto | https://www.postgresql.org/docs/16/pgcrypto.html | Official Docs | Intermediate | 30 min | Hashing, symmetric/asymmetric encryption, password storage |
| ltree (hierarchical data) | https://www.postgresql.org/docs/16/ltree.html | Official Docs | Intermediate | 30 min | Dot-path labels, ancestor queries, GiST index |
| hstore (key-value) | https://www.postgresql.org/docs/16/hstore.html | Official Docs | Beginner | 20 min | Schema-flexible key-value in a single column |
| pg_stat_statements | https://www.postgresql.org/docs/16/pgstatstatements.html | Official Docs | Intermediate | 30 min | Per-query execution stats; essential for identifying slow queries |
| auto_explain | https://www.postgresql.org/docs/16/auto-explain.html | Official Docs | Advanced | 20 min | Log plans for slow queries automatically |
| pg_buffercache | https://www.postgresql.org/docs/16/pgbuffercache.html | Official Docs | Advanced | 20 min | Inspect which tables/indexes are in shared_buffers |
| pageinspect | https://www.postgresql.org/docs/16/pageinspect.html | Official Docs | Advanced | 30 min | Read raw page bytes; understand heap tuple layout |
| btree_gin | https://www.postgresql.org/docs/16/btree-gin.html | Official Docs | Intermediate | 15 min | Use GIN index for btree-comparable types |
| btree_gist | https://www.postgresql.org/docs/16/btree-gist.html | Official Docs | Intermediate | 15 min | Use GiST for exclusion constraints on btree types |
| citext (case-insensitive text) | https://www.postgresql.org/docs/16/citext.html | Official Docs | Beginner | 15 min | Drop-in type for case-insensitive comparisons without LOWER() |
| unaccent | https://www.postgresql.org/docs/16/unaccent.html | Official Docs | Intermediate | 15 min | Strip accents before text search; used with ts_config |
| uuid-ossp | https://www.postgresql.org/docs/16/uuid-ossp.html | Official Docs | Beginner | 15 min | UUID generation functions (v1, v4); compare with gen_random_uuid() |
| tablefunc (crosstab) | https://www.postgresql.org/docs/16/tablefunc.html | Official Docs | Intermediate | 20 min | PIVOT / crosstab queries |
| postgres_fdw | https://www.postgresql.org/docs/16/postgres-fdw.html | Official Docs | Advanced | 30 min | Query remote PostgreSQL servers as local tables |
| PostGIS (project site) | https://postgis.net/documentation/ | Official Docs | Advanced | variable | Geospatial types, functions, and indexes; not installed locally |
| TimescaleDB docs | https://docs.timescale.com/ | Official Docs | Advanced | variable | Time-series hypertables, continuous aggregates; not installed locally |

---

## 7. Performance

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|------------|
| Use The Index, Luke | https://use-the-index-luke.com/ | Free Book | Intermediate | 4–6 h | Index design, range scans, function indexes — best free resource |
| EXPLAIN docs (official) | https://www.postgresql.org/docs/16/using-explain.html | Official Docs | Intermediate | 1 h | Reading plan nodes, cost fields, buffers output |
| pg_stat_statements docs | https://www.postgresql.org/docs/16/pgstatstatements.html | Official Docs | Intermediate | 30 min | total_exec_time, mean_exec_time, calls — where to start tuning |
| PostgreSQL Wiki — Performance Optimization | https://wiki.postgresql.org/wiki/Performance_Optimization | Wiki | Advanced | 1 h | Config knobs, autovacuum, connection pooling checklist |
| explain.depesz.com | https://explain.depesz.com/ | Blog | Intermediate | 10 min | Paste EXPLAIN ANALYZE output; get color-coded bottleneck view |
| pgBadger (log analyzer) | https://github.com/darold/pgbadger | GitHub | Advanced | 30 min | Parse PostgreSQL logs into HTML performance reports |
| Postgres Performance Tips (Craig Kerstiens) | https://www.crunchydata.com/blog/ | Blog | Intermediate | variable | Crunchy Data blog; vetted posts on query tuning and indexing |
| pgtune | https://pgtune.leopard.in.ua/ | Blog | Beginner | 5 min | Config calculator for postgresql.conf based on hardware profile |

---

## 8. Security

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|------------|
| Row Level Security (official) | https://www.postgresql.org/docs/16/ddl-rowsecurity.html | Official Docs | Intermediate | 45 min | Policy creation, USING vs WITH CHECK, permissive vs restrictive |
| pgcrypto docs | https://www.postgresql.org/docs/16/pgcrypto.html | Official Docs | Intermediate | 30 min | Hashing (crypt/gen_salt), AES encrypt/decrypt, PGP functions |
| Roles and Privileges (official) | https://www.postgresql.org/docs/16/user-manag.html | Official Docs | Intermediate | 1 h | GRANT, REVOKE, role inheritance, nologin roles, pg_hba.conf |
| PostgreSQL SSL Setup | https://www.postgresql.org/docs/16/ssl-tcp.html | Official Docs | Advanced | 30 min | TLS for client-server connections |
| OWASP SQL Injection cheat sheet | https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html | Wiki | Intermediate | 20 min | Parameterized queries, prepared statements, defense patterns |
| PostgreSQL Security Hardening (wiki) | https://wiki.postgresql.org/wiki/Security | Wiki | Advanced | 1 h | Community checklist: auth, superuser, pg_hba patterns |

---

## 9. Observability

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|------------|
| postgres_exporter GitHub | https://github.com/prometheus-community/postgres_exporter | GitHub | Intermediate | 30 min | Prometheus metrics from PostgreSQL; standard for dashboards |
| Grafana PostgreSQL Overview dashboard | https://grafana.com/grafana/dashboards/9628-postgresql-database/ | Blog | Intermediate | 15 min | Import-ready dashboard ID 9628; uses postgres_exporter metrics |
| Prometheus documentation | https://prometheus.io/docs/introduction/overview/ | Official Docs | Intermediate | 1–2 h | Scrape config, PromQL basics, alerting |
| Grafana Getting Started | https://grafana.com/docs/grafana/latest/getting-started/ | Official Docs | Beginner | 1 h | Dashboards, data sources, alerts |
| pg_stat_statements (official) | https://www.postgresql.org/docs/16/pgstatstatements.html | Official Docs | Intermediate | 30 min | Query stats that feed observability tooling |
| pgBadger | https://github.com/darold/pgbadger | GitHub | Advanced | 30 min | Offline log-based HTML reports; no Prometheus required |
| Datadog PostgreSQL integration guide | https://docs.datadoghq.com/integrations/postgres/ | Official Docs | Intermediate | 20 min | Useful reference for metric names even if not using Datadog |

---

## 10. MCP and Agent Safety

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|------------|
| Model Context Protocol specification | https://modelcontextprotocol.io/specification | Official Docs | Advanced | 2–3 h | Full MCP spec: servers, tools, resources, prompts |
| MCP GitHub repository | https://github.com/modelcontextprotocol/specification | GitHub | Advanced | reference | Canonical spec source; read Issues for design rationale |
| Anthropic Model Safety documentation | https://www.anthropic.com/safety | Official Docs | All | 30 min | Anthropic's safety approach; useful context for agent design |
| Anthropic API Reference | https://docs.anthropic.com/en/api/getting-started | Official Docs | Intermediate | 1 h | Tool use, system prompts, context window limits |
| OWASP Top 10 for LLM Applications | https://owasp.org/www-project-top-10-for-large-language-model-applications/ | Wiki | Advanced | 1 h | LLM-specific risks: prompt injection, data leakage, insecure output |
| Simon Willison — Prompt Injection | https://simonwillison.net/2023/Apr/14/worst-that-could-happen/ | Blog | Intermediate | 15 min | Practical explanation of prompt injection risks in agent contexts |

---

## 11. Tools and Ecosystem

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|------------|
| psql documentation | https://www.postgresql.org/docs/16/app-psql.html | Official Docs | Beginner | 30 min | \d, \timing, \x, \copy, meta-commands reference |
| pgAdmin documentation | https://www.pgadmin.org/docs/ | Official Docs | Beginner | 30 min | GUI client for query editing and schema exploration |
| DBeaver documentation | https://dbeaver.com/docs/dbeaver/ | Official Docs | Beginner | 20 min | Multi-database GUI; popular alternative to pgAdmin |
| Docker PostgreSQL image | https://hub.docker.com/_/postgres | Official Docs | Beginner | 20 min | Official image docs; environment variables, init scripts |
| pgcli (enhanced psql) | https://www.pgcli.com/ | GitHub | Beginner | 10 min | Auto-complete and syntax highlighting for psql sessions |
| PGXN — PostgreSQL Extension Network | https://pgxn.org/ | Wiki | Intermediate | reference | Searchable registry of community PostgreSQL extensions |
| pg_activity | https://github.com/dalibo/pg_activity | GitHub | Intermediate | 15 min | top-like monitor for running queries and locks |

---

## TODO items (verified by search — URL uncertain)

- TODO: verify URL — PostgreSQL: Up and Running (O'Reilly) free chapter access
- TODO: Find verified short YouTube series (< 15 min episodes) for beginner SQL topics
- TODO: Find verified free reference for pgvector ANN recall benchmarks (ann-benchmarks.com listed above — verify it covers pgvector specifically)
- TODO: Find verified free resource for TimescaleDB concepts once locally available
- TODO: Find verified free resource for PostGIS spatial SQL once locally available
