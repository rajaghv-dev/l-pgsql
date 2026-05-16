# References — MVCC and Locking

## PostgreSQL official documentation
- MVCC Introduction: https://www.postgresql.org/docs/16/mvcc-intro.html
- Routine Vacuuming: https://www.postgresql.org/docs/16/routine-vacuuming.html
- Vacuum for Wraparound: https://www.postgresql.org/docs/16/routine-vacuuming.html#VACUUM-FOR-WRAPAROUND
- pageinspect: https://www.postgresql.org/docs/16/pageinspect.html
- Explicit Locking: https://www.postgresql.org/docs/16/explicit-locking.html
- pg_locks view: https://www.postgresql.org/docs/16/view-pg-locks.html
- pg_stat_user_tables: https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ALL-TABLES-VIEW
- Advisory Locks: https://www.postgresql.org/docs/16/functions-admin.html#FUNCTIONS-ADVISORY-LOCKS

## Papers
- Bruce Momjian, "MVCC Unmasked": https://momjian.us/main/writings/pgsql/mvcc.pdf
- PostgreSQL internals — heap tuple layout: https://www.postgresql.org/docs/16/storage-page-layout.html

## Blog posts
- "PostgreSQL VACUUM: Understanding the Basics": https://www.postgresguide.com/performance/explain/
- Cybertec, "Lock Monitoring in PostgreSQL": https://www.cybertec-postgresql.com/en/lock-monitoring-in-postgresql/
- "SKIP LOCKED for Job Queues": https://www.2ndquadrant.com/en/blog/what-is-select-skip-locked-for-in-postgresql-9-5/
- "Understanding XID Wraparound": https://blog.dbi-services.com/postgresql-xid-wraparound/

## Related concepts in this repo
- `concepts/intermediate/07-transactions-and-isolation.md` — isolation levels
- `concepts/intermediate/08-mvcc-and-snapshot-thinking.md` — MVCC theory
- `concepts/intermediate/09-locks-and-concurrency.md` — lock types and patterns
- `concepts/intermediate/19-observability-with-pg-stat-statements.md` — monitoring queries and locks
