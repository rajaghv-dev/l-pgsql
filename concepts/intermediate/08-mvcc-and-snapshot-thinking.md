# MVCC and Snapshot Thinking
Level: Intermediate

## One-line intuition
PostgreSQL never overwrites a row in place — it appends a new version and lets vacuum clean up old ones, giving every transaction a consistent snapshot without blocking reads.

## Why this exists
Locking-based databases serialize reads and writes, creating contention hotspots. MVCC eliminates read-write contention: readers never block writers and writers never block readers. This is the single biggest reason PostgreSQL scales well under mixed OLTP workloads.

## First-principles explanation
Every row in PostgreSQL has two hidden system columns:
- **xmin** — the transaction ID that inserted (created) this row version
- **xmax** — the transaction ID that deleted or updated this row version (0 = still live)

When a transaction updates a row, PostgreSQL does NOT modify the existing tuple. It:
1. Marks the old tuple's `xmax` with the current transaction ID (marking it deleted)
2. Inserts a new tuple with `xmin` set to the current transaction ID

A SELECT statement checks each tuple's `xmin` and `xmax` against the transaction's **snapshot** — a list of which transaction IDs were committed at the moment the snapshot was taken. A tuple is visible if:
- Its `xmin` is committed and visible to the snapshot
- Its `xmax` is not committed or not visible to the snapshot

Dead tuples (xmax committed and visible to all active transactions) are physically removed by **VACUUM**.

## Micro-concepts
- **xmin / xmax** — system columns encoding row version lifetime
- **transaction ID (XID)** — a 32-bit counter, wraps around every ~2 billion transactions; XID wraparound is a critical operational concern
- **snapshot** — the set of XIDs that are in-progress or uncommitted at a point in time
- **dead tuple** — a row version that is no longer visible to any active transaction
- **VACUUM** — reclaims space from dead tuples; does not shrink the file (use VACUUM FULL for that)
- **autovacuum** — background daemon that runs VACUUM automatically based on table change thresholds
- **hint bits** — lazily set bits in the tuple header that cache commit/abort status to avoid repeated clog lookups
- **clog (commit log)** — records whether each XID is committed, aborted, or in-progress
- **pageinspect** — extension that exposes raw page contents including xmin/xmax

## Beginner view
Think of a whiteboard where you never erase — you just cross out the old entry and write the new one next to it. Everyone looking at the whiteboard sees a consistent picture based on when they started looking. Vacuum is the janitor who eventually wipes out crossed-out entries.

## Intermediate view
Each UPDATE is a DELETE + INSERT at the storage level. Index entries point to specific heap tuple versions. The visibility check is per-tuple and per-snapshot. Hot-update optimization avoids index updates when non-indexed columns change.

## Advanced view
Snapshot construction calls `GetSnapshotData()` which walks `ProcArray` to find all active XIDs. For very high concurrency (thousands of active transactions), this scan can become a bottleneck — mitigated by `PGXACT` array caching. Frozen tuples (xmin set to FrozenXID via `VACUUM FREEZE`) are always visible to all transactions, which is how XID wraparound is prevented.

## Mental model
Think of the heap as an append-only ledger. Every row version is a journal entry with a birth-XID and an optional death-XID. Reading the ledger means filtering entries whose birth-XID is in your past and whose death-XID is either absent or in your future. VACUUM is the periodic reconciliation that removes entries older than anyone needs.

## PostgreSQL view
```sql
-- Inspect xmin/xmax on a table
SELECT xmin, xmax, * FROM accounts LIMIT 5;

-- See dead tuples accumulating
SELECT relname, n_dead_tup, n_live_tup, last_autovacuum
FROM pg_stat_user_tables
WHERE relname = 'accounts';

-- Force vacuum
VACUUM ANALYZE accounts;

-- Use pageinspect to see raw tuple headers
CREATE EXTENSION IF NOT EXISTS pageinspect;
SELECT lp, t_xmin, t_xmax, t_ctid, t_data
FROM heap_page_items(get_raw_page('accounts', 0));
```

## SQL view
The SQL standard does not expose MVCC internals. xmin/xmax are PostgreSQL-specific. Understanding them is essential for diagnosing table bloat, unexpected query slowness after heavy updates, and autovacuum configuration.

## Non-SQL or hybrid view
NoSQL systems like CockroachDB (Postgres-compatible) and Spanner also use MVCC. MongoDB uses document-level MVCC. Kafka topics are effectively immutable append logs — conceptually similar to PostgreSQL's heap before vacuum. Event sourcing architectures deliberately preserve all versions (no vacuum), making the historical record the primary source of truth.

## Design principle
**Design tables to minimize unnecessary updates.** Every UPDATE creates a dead tuple. Tables with frequent broad updates (updating many columns at once) accumulate bloat faster. Use partial updates, hstore/jsonb for variable attributes, and proper autovacuum tuning for high-churn tables. Column defaults and NOT NULL constraints with `ADD COLUMN ... DEFAULT` leverage fast schema changes without rewriting the table.

## Critical thinking
- XID wraparound is a real operational risk. A database that has never run VACUUM FREEZE on a large table can be forced into read-only mode to prevent data loss. Monitor `age(relfrozenxid)` in `pg_class`.
- Table bloat from MVCC means a table with 1M rows that is updated 10x will hold ~10M tuple slots until vacuum runs. This is why write-heavy tables need aggressive autovacuum settings.
- `VACUUM FULL` rewrites the entire table and acquires an exclusive lock. It should rarely be needed in a well-maintained database.

## Creative thinking
Use `xmin` as a lightweight change-detection column: if you store a table's `xmin` alongside a cached result, you can detect that a row has been modified since you last read it by comparing the stored xmin. This is an alternative to explicit `updated_at` columns for cache invalidation.

## Systems thinking
MVCC is the reason PostgreSQL can run long analytical queries against the same tables that are being written to by an OLTP workload — the analyst's snapshot is frozen at query start. However, long-running transactions hold back the MVCC horizon: vacuum cannot remove dead tuples that might still be needed by the oldest active transaction. Monitor `pg_stat_activity` for long-running transactions and set `idle_in_transaction_session_timeout` to prevent connection leaks.

## MCP and agent perspective
An MCP agent performing bulk data ingestion should be aware that large transactions (millions of rows) will accumulate dead tuples for the duration of the transaction. Breaking bulk loads into smaller batches (e.g., 10,000 rows per commit) allows autovacuum to keep pace and avoids extreme table bloat. An agent that monitors table health should query `pg_stat_user_tables` for `n_dead_tup` and alert when it exceeds a threshold.

## Ontology perspective
MVCC encodes the ontological notion that the database is not a snapshot of the present — it is a record of all past states. Each row version is a fact about what was true between xmin and xmax. This is structurally identical to temporal databases (bi-temporal modeling), except PostgreSQL's version history is implicit and eventually reclaimed. An ontology-driven design might choose to make this versioning explicit with `valid_from`/`valid_to` columns, trading vacuum efficiency for queryable history.

## Practice session
See `practice/intermediate/05-mvcc-and-locking/` for hands-on exercises demonstrating xmin/xmax inspection, dead tuple accumulation, and vacuum effects.

## References
- PostgreSQL docs — MVCC Introduction: https://www.postgresql.org/docs/16/mvcc-intro.html
- PostgreSQL docs — Transaction IDs: https://www.postgresql.org/docs/16/routine-vacuuming.html#VACUUM-FOR-WRAPAROUND
- PostgreSQL docs — pageinspect: https://www.postgresql.org/docs/16/pageinspect.html
- PostgreSQL docs — pg_stat_user_tables: https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ALL-TABLES-VIEW
- Bruce Momjian, "MVCC Unmasked": https://momjian.us/main/writings/pgsql/mvcc.pdf
