# References — Indexing Strategies

## PostgreSQL documentation
- Index types: https://www.postgresql.org/docs/16/indexes-types.html
- B-tree: https://www.postgresql.org/docs/16/indexes-types.html#INDEXES-TYPES-BTREE
- GIN: https://www.postgresql.org/docs/16/gin.html
- GiST: https://www.postgresql.org/docs/16/gist.html
- BRIN: https://www.postgresql.org/docs/16/brin.html
- Partial indexes: https://www.postgresql.org/docs/16/indexes-partial.html
- Expression indexes: https://www.postgresql.org/docs/16/indexes-expressional.html
- Index-only scans and INCLUDE: https://www.postgresql.org/docs/16/indexes-index-only-scans.html
- Multicolumn indexes: https://www.postgresql.org/docs/16/indexes-multicolumn.html
- pg_stat_user_indexes: https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ALL-INDEXES-VIEW
- VACUUM: https://www.postgresql.org/docs/16/sql-vacuum.html
- pgstatindex: https://www.postgresql.org/docs/16/pgstatindex.html
- GIN pending list: https://www.postgresql.org/docs/16/gin-implementation.html#GIN-FAST-UPDATE

## Theory and practice
- Use The Index, Luke: https://use-the-index-luke.com/
- Use The Index, Luke — GIN: https://use-the-index-luke.com/sql/where-clause/searching-for-ranges/like-performance-tuning
- PostgreSQL internals blog — BRIN: https://www.postgresql.org/about/news/brin-indexes-1234/

## Tools
- pg_stat_statements: https://www.postgresql.org/docs/16/pgstatstatements.html
- EXPLAIN visualizer pev2: https://explain.dalibo.com/
- Index bloat estimation: https://github.com/ioguix/pgsql-bloat-estimation
