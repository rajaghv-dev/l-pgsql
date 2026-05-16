# Vacuum, Autovacuum, and Bloat

Level: Advanced

## One-line intuition
VACUUM is PostgreSQL's garbage collector: MVCC means every update and delete leaves corpses behind, and without vacuum those corpses accumulate until the database runs out of space or wraps around the transaction ID counter.

## Why this exists
PostgreSQL's MVCC model never overwrites data in place. Every `UPDATE` writes a new version of a row; every `DELETE` marks the old version as dead. These dead tuples ("corpses") accumulate on heap pages, bloating tables and slowing queries. VACUUM reclaims space by marking dead tuples as reusable. Without it, tables bloat indefinitely — and eventually, transaction ID wraparound causes a hard stop of the entire cluster.

## First-principles explanation

### MVCC and dead tuples
Every heap tuple has `xmin` (inserting transaction) and `xmax` (deleting/updating transaction). A tuple is "dead" when `xmax` is committed and no active transaction can see the old version. Dead tuples:
- Occupy space on heap pages (bloat)
- Are visited during sequential scans (wasted CPU)
- Have stale entries in every index (index bloat)

### What VACUUM does
VACUUM does NOT shrink the table file. It marks dead tuple space as reusable:
1. Scans heap pages for dead tuples
2. Removes corresponding index entries
3. Marks freed space as available for new inserts
4. Updates the visibility map (VM) — pages fully visible to all transactions are marked; allows index-only scans
5. Updates `pg_stat_user_tables.n_dead_tup` and timestamps
6. If needed, updates the free space map (FSM) for future inserts

VACUUM FULL (separate command) actually rewrites the table file into a compact form — but it takes a full table lock and is rarely appropriate for production.

### Transaction ID wraparound
PostgreSQL uses 32-bit transaction IDs (XIDs). XID space is circular: after ~2 billion transactions, XIDs wrap around. PostgreSQL uses a safety mechanism:
- When a table is within 40 million XIDs of wraparound, autovacuum forces an aggressive vacuum (setting `relfrozenxid`)
- When within 1 million XIDs: the cluster refuses all writes with `ERROR: database is not accepting commands to avoid wraparound data loss`
- Avoiding wraparound is the most critical autovacuum function — it cannot be safely skipped

Monitor: `SELECT datname, age(datfrozenxid) FROM pg_database ORDER BY age DESC;` — alert if age > 1.5 billion.

### Autovacuum configuration
Autovacuum triggers when: `n_dead_tup > autovacuum_vacuum_threshold + autovacuum_vacuum_scale_factor × n_live_tup`

Default values:
- `autovacuum_vacuum_threshold = 50` (min 50 dead tuples before triggering)
- `autovacuum_vacuum_scale_factor = 0.2` (20% of table dead tuples triggers vacuum)
- `autovacuum_vacuum_cost_delay = 2ms` (throttling: pause after spending this much IO cost)
- `autovacuum_vacuum_cost_limit = 200` (how many IO cost units to spend before pausing)
- `autovacuum_max_workers = 3` (max parallel autovacuum workers)

For large tables (100M+ rows): 20% scale factor means 20M dead tuples before triggering. This is too lax. Override per-table:
```sql
-- blocked: Docker not accessible
ALTER TABLE orders SET (
    autovacuum_vacuum_scale_factor = 0.01,   -- trigger at 1% dead tuples
    autovacuum_vacuum_cost_delay = 10,        -- be more aggressive
    autovacuum_vacuum_threshold = 100
);
```

### VACUUM ANALYZE
Combines vacuum (dead tuple removal) and ANALYZE (statistics refresh) in one pass:
```sql
-- blocked: Docker not accessible
VACUUM ANALYZE orders;
VACUUM (VERBOSE, ANALYZE) orders;  -- verbose output shows what was done
```

### Measuring bloat
The canonical approach uses `pgstattuple`:
```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS pgstattuple;
SELECT * FROM pgstattuple('orders');
-- dead_tuple_percent > 20% indicates significant bloat
```

A statistical approximation without superuser:
```sql
-- blocked: Docker not accessible
-- Approximate bloat from pg_stat_user_tables
SELECT relname,
       n_live_tup,
       n_dead_tup,
       round(n_dead_tup::numeric / nullif(n_live_tup + n_dead_tup, 0) * 100, 1) AS dead_pct,
       pg_size_pretty(pg_total_relation_size(oid)) AS total_size,
       last_vacuum,
       last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

### VACUUM FULL vs VACUUM
| | VACUUM | VACUUM FULL |
|---|---|---|
| Lock | ShareUpdateExclusiveLock (allows reads and DML) | AccessExclusiveLock (blocks everything) |
| Space reclaimed | Marks as reusable within file | Rewrites file, shrinks OS file size |
| Duration | Fast (minutes for large tables) | Slow (can take hours) |
| Use case | Routine maintenance | One-time recovery from extreme bloat |
| Alternative | — | `pg_repack` (online, no table lock) |

`pg_repack` is the production-safe alternative to VACUUM FULL — it rebuilds the table and indexes concurrently with minimal locking.

### Autovacuum tuning patterns

**High-churn OLTP tables**: Lower scale factor, reduce cost delay for urgency.
```sql
-- blocked: Docker not accessible
ALTER TABLE sessions SET (
    autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_vacuum_cost_delay = 2
);
```

**Large historical tables**: Raise cost limit for faster progress.
```sql
-- blocked: Docker not accessible
ALTER TABLE events SET (
    autovacuum_vacuum_cost_limit = 800,
    autovacuum_vacuum_scale_factor = 0.05
);
```

**Anti-patterns**:
- `autovacuum = off` on any production table (except for specific frozen tables)
- Long-running transactions that hold `xmin`, preventing dead tuple cleanup
- `idle in transaction` sessions holding the oldest snapshot

### The visibility map and index-only scans
Vacuum maintains the visibility map — a compact bitmap marking pages where all tuples are visible to all transactions. Index-only scans (returning data from the index without touching the heap) require visible heap pages. A table with many dead tuples has few VM-marked pages, forcing heap fetches even for index-eligible queries. Regular vacuum restores VM pages and recovers index-only scan efficiency.

## Micro-concepts
- **xmin / xmax**: tuple header fields marking when a tuple became visible / was deleted
- **relfrozenxid**: the oldest XID in the table not yet frozen. Age = current XID - relfrozenxid. Vacuum freezes tuples older than `vacuum_freeze_min_age`.
- **autovacuum_freeze_max_age**: when age exceeds this (default 200M), autovacuum is forced regardless of dead tuple count — wraparound prevention mode.
- **pg_stat_user_tables.n_mod_since_analyze**: rows modified since last analyze. Used by autovacuum to trigger ANALYZE.
- **bloat**: table or index size in excess of what the live data requires. Caused by dead tuples and fragmented pages.
- **FSM — free space map**: tracks available space per page for future inserts. Updated by vacuum.
- **VM — visibility map**: two bits per page: all-visible (safe for index-only scan) and all-frozen (safe to skip during aggressive vacuum).

## Beginner view / Intermediate view / Advanced view

**Beginner view**: PostgreSQL automatically cleans up deleted rows. Don't turn autovacuum off.

**Intermediate view**: Bloat from high UPDATE/DELETE rate slows queries. Monitor `n_dead_tup`. Tune `autovacuum_vacuum_scale_factor` for large tables. Run `VACUUM ANALYZE` after bulk operations.

**Advanced view**: Autovacuum is the intersection of three independent concerns: dead tuple cleanup (prevents bloat), statistics freshness (prevents bad plans), and transaction ID wraparound prevention (prevents cluster-wide write stop). Tuning these requires per-table overrides because the cluster-wide defaults are conservative compromises. Long-running transactions (`idle in transaction`) hold the oldest `xmin`, preventing vacuum from removing dead tuples they might theoretically need. In read-heavy replicas, hot_standby_feedback can hold the primary's oldest xmin, blocking vacuum across the entire cluster. Both are silent killers of table health.

## Mental model
MVCC creates versions of rows like a time-lapse photo series. Vacuum is the archivist who periodically scans the photo archive, throws away old frames that nobody is watching anymore, and reclaims their shelf space. Transaction ID wraparound is the clock running out on the archive system — if the archivist stops working, the clock eventually strikes midnight and the system locks up to prevent data corruption. Autovacuum is the automatic scheduling system for the archivist; tune it well and it runs quietly in the background. Tune it poorly and the archivist either runs too rarely (bloat) or too aggressively (high IO).

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_stat_user_tables` (vacuum state), `pg_stat_progress_vacuum` (in-progress vacuum status), `pg_database` (wraparound age), `pg_stat_activity` (long-running transactions blocking vacuum).

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Wraparound risk monitoring
SELECT datname, age(datfrozenxid) AS xid_age,
       round(age(datfrozenxid)::numeric / 2000000000 * 100, 1) AS pct_to_wraparound
FROM pg_database
ORDER BY xid_age DESC;

-- Tables with high dead tuple ratio
SELECT relname, n_dead_tup, n_live_tup,
       round(n_dead_tup::numeric / nullif(n_live_tup, 0) * 100, 1) AS dead_pct,
       last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY dead_pct DESC;

-- Oldest transaction holding back vacuum
SELECT pid, usename, state, query_start, now() - query_start AS duration,
       wait_event_type, wait_event, left(query, 80)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY query_start;

-- In-progress vacuum status
SELECT relid::regclass, phase, heap_blks_scanned, heap_blks_total,
       index_vacuum_count, num_dead_tuples
FROM pg_stat_progress_vacuum;
```

**Non-SQL / hybrid view**: pgBadger parses autovacuum log lines (`log_autovacuum_min_duration = 0` logs all autovacuum runs). Prometheus + postgres_exporter tracks `n_dead_tup` and `last_autovacuum` metrics.

## Design principle
**Autovacuum is infrastructure, not a feature**: It is as important as backups and monitoring. A cluster without properly tuned autovacuum will accumulate bloat progressively and eventually hit a wraparound emergency. The two most impactful autovacuum tuning changes in production are: (1) lowering `autovacuum_vacuum_scale_factor` for large tables, and (2) terminating or bounding the duration of `idle in transaction` sessions.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: Autovacuum competes with user workload for I/O via cost delay/limit throttling. The default settings are conservative — autovacuum pauses frequently to avoid impacting production queries. This means on busy systems, autovacuum may not keep up with the dead tuple accumulation rate, leading to progressive bloat. The solution is not to disable throttling but to increase `autovacuum_vacuum_cost_limit` or reduce `autovacuum_vacuum_cost_delay` for specific tables.

**Creative**: Use `pg_stat_progress_vacuum` to build a real-time vacuum dashboard. Plot heap_blks_scanned/heap_blks_total as a progress bar. Log to a monitoring table after each vacuum completes using `log_autovacuum_min_duration`. Correlate vacuum completions with query plan changes (ANALYZE happens post-vacuum) to detect plan regressions caused by statistics updates.

**Systems**: Read replicas with `hot_standby_feedback = on` send their oldest active XID back to the primary. The primary's autovacuum then cannot remove dead tuples that the replica might still need for consistent reads. This can cause unbounded primary bloat on read-heavy clusters with long-running replica queries. Mitigate with `max_standby_streaming_delay` on replicas and alerting on primary bloat independently.

## MCP and agent perspective
Agents that perform many small writes (one row per agent action, per memory update) create a high dead-tuple rate on tables like `agent_sessions` and `memory_events`. These tables need aggressive autovacuum tuning. Agents should also avoid idle-in-transaction states — each open transaction holds an xmin snapshot, blocking vacuum. Connection poolers in session mode can hold idle transactions; use transaction mode in PgBouncer for agent connections. A monitoring agent can periodically query `pg_stat_user_tables` and alert when `dead_pct > 20%` for any agent-owned table.

## Ontology perspective
Vacuum is a mechanism for resolving temporal inconsistency: MVCC allows multiple versions of reality (tuple versions) to coexist simultaneously. Vacuum is the process that collapses historical reality — removing versions of the past that no observer (transaction) needs any longer. Transaction ID wraparound is the system's finite horizon for observing the past: beyond 2 billion transactions, the system can no longer distinguish "very old" from "brand new," which is why it stops writes before that point. Vacuum extends the observable horizon by freezing historical tuples.

## Practice session

**Exercise 1 — Check wraparound risk**: Alert threshold is ~1.5B.
```sql
-- blocked: Docker not accessible
SELECT datname, age(datfrozenxid) AS xid_age
FROM pg_database
ORDER BY xid_age DESC;
```

**Exercise 2 — Table bloat snapshot**: Identify highest-bloat tables.
```sql
-- blocked: Docker not accessible
SELECT relname, n_dead_tup, n_live_tup,
       round(n_dead_tup::numeric / nullif(n_live_tup + n_dead_tup, 0) * 100, 1) AS dead_pct
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 10;
```

**Exercise 3 — Trigger and observe autovacuum**: Create dead tuples and watch.
```sql
-- blocked: Docker not accessible
CREATE TABLE test_vacuum (id serial, val text);
INSERT INTO test_vacuum SELECT i, 'x' FROM generate_series(1,10000) i;
UPDATE test_vacuum SET val = 'y';  -- creates 10000 dead tuples
SELECT n_dead_tup, last_autovacuum FROM pg_stat_user_tables WHERE relname = 'test_vacuum';
-- Wait for autovacuum, then check again
```

**Exercise 4 — Per-table tuning**: Override autovacuum settings for a hot table.
```sql
-- blocked: Docker not accessible
ALTER TABLE orders SET (
    autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_analyze_scale_factor = 0.005
);
-- Verify
SELECT reloptions FROM pg_class WHERE relname = 'orders';
```

**Exercise 5 — Observe in-progress vacuum**: Trigger manual vacuum and watch progress.
```sql
-- blocked: Docker not accessible
-- In one session:
VACUUM VERBOSE orders;
-- In another session during the above:
SELECT relid::regclass, phase, heap_blks_scanned, heap_blks_total
FROM pg_stat_progress_vacuum;
```

## References
- PostgreSQL Documentation: [Routine Vacuuming](https://www.postgresql.org/docs/16/routine-vacuuming.html)
- PostgreSQL Documentation: [Autovacuum](https://www.postgresql.org/docs/16/runtime-config-autovacuum.html)
- PostgreSQL Documentation: [Preventing Transaction ID Wraparound Failures](https://www.postgresql.org/docs/16/routine-vacuuming.html#VACUUM-FOR-WRAPAROUND)
- PostgreSQL Documentation: [pg_stat_progress_vacuum](https://www.postgresql.org/docs/16/progress-reporting.html#VACUUM-PROGRESS-REPORTING)
- Hironobu Suzuki: [The Internals of PostgreSQL, Chapter 6 — Vacuum Processing](https://www.interdb.jp/pg/pgsql06.html)
- Laurenz Albe: [Autovacuum Tuning Basics](https://www.cybertec-postgresql.com/en/autovacuum-tuning-basics/)
- pg_repack: https://github.com/reorg/pg_repack
