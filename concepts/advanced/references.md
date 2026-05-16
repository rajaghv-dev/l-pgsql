# Advanced References

Curated references for advanced PostgreSQL internals and production systems.

See also: [root references.md](../../references.md) for the full curated list.

---

## Core references for this level

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|------------|
| The Internals of PostgreSQL (Suzuki) | https://www.interdb.jp/pg/ | Free Book | Advanced | 10–15 h | Storage layout, MVCC internals, vacuum, WAL — best free deep-dive |
| Bruce Momjian — PostgreSQL Internals PDF | https://momjian.us/main/writings/pgsql/internals.pdf | Free Book | Advanced | 6–8 h | Core developer slides-as-book on concurrency, executor, planner |
| WAL and Replication | https://www.postgresql.org/docs/16/wal.html | Official Docs | Advanced | 2 h | WAL internals, checkpoints, durability guarantees |
| Partitioning | https://www.postgresql.org/docs/16/ddl-partitioning.html | Official Docs | Advanced | 2 h | Range/list/hash partitioning, partition pruning, attach/detach |
| System Catalogs | https://www.postgresql.org/docs/16/catalogs.html | Official Docs | Advanced | reference | pg_stat_*, pg_catalog — introspect the live system |
| PostgreSQL Wiki — Performance Optimization | https://wiki.postgresql.org/wiki/Performance_Optimization | Wiki | Advanced | 1 h | Config knobs, vacuum, explain — community-maintained checklist |
| pgvector GitHub (HNSW section) | https://github.com/pgvector/pgvector#hnsw | GitHub | Advanced | 20 min | HNSW parameters, recall/speed tradeoffs, production tuning |
| Robert Haas Blog | https://rhaas.blogspot.com/ | Blog | Advanced | variable | Core developer blog on heap AM, logical replication, planner |
| ANN Benchmarks | https://ann-benchmarks.com/ | Wiki | Advanced | 30 min | Verified benchmark comparing approximate nearest-neighbor algorithms |
| OWASP Top 10 for LLM Applications | https://owasp.org/www-project-top-10-for-large-language-model-applications/ | Wiki | Advanced | 1 h | Agent security risks: prompt injection, data leakage, insecure output |
