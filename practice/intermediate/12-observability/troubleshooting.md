# Troubleshooting — Observability

## pg_stat_statements is empty / not populated
**Cause 1:** Extension not installed.
```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```
**Cause 2:** `shared_preload_libraries` does not include `pg_stat_statements` — requires postgresql.conf change and restart.
```
# In postgresql.conf:
shared_preload_libraries = 'pg_stat_statements'
```
Run `scripts/dashboards/enable-pg-stat-statements.sh` to check and configure.

## ERROR: relation "pg_stat_statements" does not exist
**Cause:** Extension is in shared_preload_libraries but not yet created in this database.
**Fix:** `CREATE EXTENSION pg_stat_statements;` in the target database.

## pg_stat_statements doesn't track all queries
**Cause:** The hash table is full (`pg_stat_statements.max` reached — default 5000 entries). New query shapes evict old ones.
**Fix:** Increase `pg_stat_statements.max = 10000` in postgresql.conf (requires restart).

## pg_stat_activity shows no active queries
**Cause:** All sessions are idle, or the connection is the only session.
**Fix:** Run some queries in another session or use the workload generator queries in setup.sql.

## Cache hit ratio always 100%
**Cause:** Small test database — all data fits in shared_buffers easily.
**Note:** This is expected and correct for small test databases. On production, cache hit ratio becomes meaningful when the working set approaches shared_buffers size.

## pg_stat_user_tables shows seq_scan = 0
**Cause:** No queries have been run against the table since the last statistics reset.
**Fix:** Run some queries, then wait for stats to update (pg_stat_user_tables updates periodically).

## Lock wait query shows no blocking sessions
**Cause:** The blocked query has since finished, or the timeout expired.
**Note:** `pg_stat_activity` is a point-in-time view. Locks come and go quickly. For persistent lock analysis, use `pg_locks` joined with `pg_stat_activity` in a monitoring loop.

## pg_stat_statements_reset() takes a long time
**Cause:** Rare — usually reset is instant.
**Note:** If it hangs, check `pg_stat_activity` for a session holding a lock on the internal stats structures. Usually not an issue; safe to interrupt.
