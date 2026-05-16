# References — Query Planning with EXPLAIN

## PostgreSQL documentation
- EXPLAIN: https://www.postgresql.org/docs/16/sql-explain.html
- Query planner / optimizer: https://www.postgresql.org/docs/16/planner-optimizer.html
- Planner cost parameters: https://www.postgresql.org/docs/16/runtime-config-query.html#RUNTIME-CONFIG-QUERY-CONSTANTS
- Controlling the planner: https://www.postgresql.org/docs/16/explicit-joins.html
- pg_stat_statements: https://www.postgresql.org/docs/16/pgstatstatements.html
- pg_stat_user_tables: https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ALL-TABLES-VIEW
- pg_stat_user_indexes: https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ALL-INDEXES-VIEW
- Statistics used by planner: https://www.postgresql.org/docs/16/planner-stats.html
- pg_stats: https://www.postgresql.org/docs/16/view-pg-stats.html
- Index-only scans: https://www.postgresql.org/docs/16/indexes-index-only-scans.html
- work_mem: https://www.postgresql.org/docs/16/runtime-config-resource.html#GUC-WORK-MEM
- random_page_cost: https://www.postgresql.org/docs/16/runtime-config-query.html#GUC-RANDOM-PAGE-COST

## Tools and references
- Use The Index, Luke — Execution plans: https://use-the-index-luke.com/sql/explain-plan
- pev2 — EXPLAIN visualizer: https://explain.dalibo.com/
- depesz.com — EXPLAIN analyzer: https://explain.depesz.com/
- pgBadger — log-based slow query analysis: https://pgbadger.darold.net/
- auto_explain extension: https://www.postgresql.org/docs/16/auto-explain.html

## Deep dives
- "Explaining the unexplained" — Bruce Momjian: https://momjian.us/main/presentations/performance.html
- PostgreSQL query planner internals: https://www.postgresql.org/docs/16/geqo.html (genetic query optimizer for large joins)
- "How PostgreSQL chooses between index scan and seq scan": https://www.postgresql.org/docs/16/planner-stats-details.html
