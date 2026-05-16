# References — Observability

## PostgreSQL official documentation
- pg_stat_statements: https://www.postgresql.org/docs/16/pgstatstatements.html
- pg_stat_activity: https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW
- pg_stat_user_tables: https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ALL-TABLES-VIEW
- pg_locks: https://www.postgresql.org/docs/16/view-pg-locks.html
- Monitoring Statistics: https://www.postgresql.org/docs/16/monitoring-stats.html

## Blog posts and tools
- "Using pg_stat_statements to find slow queries" (Citus): https://www.citusdata.com/blog/2019/02/08/the-most-useful-postgres-extension-pg-stat-statements/
- pganalyze (commercial monitoring): https://pganalyze.com/
- pgBadger (log analyzer): https://github.com/darold/pgbadger
- "Diagnosing Lock Contention": https://www.cybertec-postgresql.com/en/lock-monitoring-in-postgresql/
- "PostgreSQL Monitoring Queries" (Will Leinweber): https://github.com/will/pgsql-perf-queries

## In this repo
- `scripts/dashboards/enable-pg-stat-statements.sh` — setup script
- `concepts/intermediate/19-observability-with-pg-stat-statements.md` — concept file
- `concepts/intermediate/09-locks-and-concurrency.md` — pg_locks deep dive
