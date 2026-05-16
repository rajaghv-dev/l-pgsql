# Transaction Ontology

Level: Intermediate → Advanced
Domain: PostgreSQL / Reliability

## Definition
A transaction is a unit of work that PostgreSQL guarantees to execute atomically, consistently, in isolation from concurrent transactions, and durably once committed — the ACID properties — using a multiversion concurrency control (MVCC) mechanism.

## Why this concept matters
Transactions are PostgreSQL's fundamental reliability guarantee. Without them, concurrent writes produce corruption, partial updates leave data in invalid states, and crashes lose committed work. MVCC underpins both isolation and PostgreSQL's non-blocking reads, making it essential knowledge for any serious user.

## Related concepts
- [[sql-ontology]] — parent (DML statements run inside transactions)
- [[query-ontology]] — related (execution snapshot is set per transaction)
- [[schema-design-ontology]] — related (DDL is transactional in PostgreSQL)
- [[performance-ontology]] — related (dead tuples, vacuum, bloat)
- [[security-ontology]] — related (RLS policies are evaluated per transaction)

---

## ACID Properties

### Atomicity
One-line definition: All statements in a transaction either all succeed or all fail — there is no partial commit.

```sql
-- blocked: Docker not accessible
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;  -- both succeed, or ROLLBACK makes neither happen
```

### Consistency
One-line definition: A transaction brings the database from one valid state to another, honoring all constraints (NOT NULL, FK, CHECK, UNIQUE).

Constraint violations abort the statement (and the transaction in `default` error handling).

### Isolation
One-line definition: Concurrent transactions appear to execute serially; the degree of apparent concurrency is controlled by the isolation level.

See: **Isolation Levels** section below.

### Durability
One-line definition: Once a transaction commits, its changes survive crashes — guaranteed by the Write-Ahead Log (WAL).

---

## Isolation Levels

| Level | Dirty Read | Non-Repeatable Read | Phantom Read | PostgreSQL behavior |
|-------|-----------|---------------------|--------------|---------------------|
| READ UNCOMMITTED | Possible* | Possible | Possible | Treated as READ COMMITTED in PG |
| READ COMMITTED | Not possible | Possible | Possible | Default; each statement gets a fresh snapshot |
| REPEATABLE READ | Not possible | Not possible | Not possible* | Snapshot taken at first statement; phantoms blocked |
| SERIALIZABLE | Not possible | Not possible | Not possible | SSI (Serializable Snapshot Isolation) detects anomalies |

*PostgreSQL's implementation prevents dirty reads even at READ UNCOMMITTED.

```sql
-- blocked: Docker not accessible
BEGIN ISOLATION LEVEL REPEATABLE READ;
-- All reads in this transaction see the same snapshot
COMMIT;
```

---

## MVCC (Multi-Version Concurrency Control)

### Snapshot
One-line definition: A consistent view of the database at a point in time, defined by the set of transaction IDs that were committed when the snapshot was taken.

At READ COMMITTED: a new snapshot is taken per statement.
At REPEATABLE READ / SERIALIZABLE: one snapshot per transaction.

### xmin / xmax
One-line definition: System columns on every heap tuple recording the transaction ID (XID) that inserted (`xmin`) and the XID that deleted or updated it (`xmax`).

```sql
-- blocked: Docker not accessible
SELECT xmin, xmax, * FROM my_table LIMIT 5;
```

A row is visible if:
- `xmin` committed before this snapshot AND
- `xmax` is either 0 (not deleted) or the deleting transaction aborted

### Dead Tuple
One-line definition: A heap tuple that is no longer visible to any transaction because its `xmax` committed, but has not yet been physically removed.

Dead tuples accumulate due to UPDATE and DELETE. They are physically removed by VACUUM.

---

## Vacuum

### VACUUM
One-line definition: Reclaims storage from dead tuples and updates the visibility map; does not return space to the OS (use VACUUM FULL for that).

```sql
-- blocked: Docker not accessible
VACUUM ANALYZE orders;       -- reclaim + refresh stats
VACUUM (VERBOSE) orders;     -- verbose output
VACUUM FULL orders;          -- full rewrite, table lock, returns space
```

### Autovacuum
One-line definition: A background daemon that automatically runs VACUUM and ANALYZE on tables that exceed configurable dead-tuple and change thresholds.

Key autovacuum parameters:
- `autovacuum_vacuum_scale_factor` (default 0.2) — trigger when 20% of rows are dead
- `autovacuum_analyze_scale_factor` (default 0.1) — trigger ANALYZE when 10% changed
- `autovacuum_vacuum_cost_delay` — throttle to reduce I/O impact

---

## Savepoint

One-line definition: A named marker within a transaction that allows partial rollback to that point without aborting the entire transaction.

```sql
-- blocked: Docker not accessible
BEGIN;
INSERT INTO orders ...;
SAVEPOINT sp1;
INSERT INTO order_items ...;  -- this fails
ROLLBACK TO SAVEPOINT sp1;    -- undo only the item insert
COMMIT;                        -- order insert survives
```

Related: [[sql-ontology]]

---

## Transaction ID (XID) Wraparound

One-line definition: PostgreSQL uses 32-bit transaction IDs; after ~2 billion transactions, IDs wrap around — VACUUM must mark old tuples as frozen before this happens to prevent data loss.

Monitoring:
```sql
-- blocked: Docker not accessible
SELECT datname, age(datfrozenxid) FROM pg_database ORDER BY 2 DESC;
-- Alert when age > 1.5 billion
```

---

## System catalog reference
- `pg_stat_activity` — active transactions, query text, state, wait events
- `pg_locks` — current locks held and awaited
- `pg_class.relfrozenxid` — oldest unfrozen XID per table
- `pg_database.datfrozenxid` — oldest unfrozen XID per database
- `pg_stat_user_tables` — `n_dead_tup`, `last_vacuum`, `last_autovacuum`

---

## Beginner mental model
A transaction is like a shopping cart: you add items (statements), and only when you say COMMIT does the purchase (write) happen. If anything goes wrong, ROLLBACK empties the cart as if you never started.

## Intermediate mental model
MVCC gives every transaction its own "snapshot" of the database. Readers never block writers and writers never block readers. Instead of locking rows, PostgreSQL keeps old versions of rows around (dead tuples) until VACUUM cleans them up. Isolation level controls how stale or fresh that snapshot is.

## Advanced mental model
MVCC is implemented via `xmin`/`xmax` columns on each tuple. The planner must account for MVCC overhead: HOT (Heap-Only Tuple) updates avoid index updates when no indexed column changes. Transaction ID wraparound is an existential threat — autovacuum must freeze tuples before the 2-billion-XID horizon. Serializable Snapshot Isolation (SSI) detects dangerous read/write dependencies and aborts one of the conflicting transactions; applications must retry.

## MCP and agent perspective
An agent submitting DML should always use explicit BEGIN/COMMIT/ROLLBACK so it can inspect intermediate state before committing. Long-running agent transactions hold snapshots open, preventing autovacuum from removing dead tuples, causing table bloat — agents must commit promptly. For audit patterns, append-only event tables should be in their own transaction to prevent rollback of the audit record.

## Practical implication
| Situation | Implication |
|-----------|-------------|
| Long-running idle transaction | Holds back autovacuum's oldest XID horizon; causes bloat |
| High UPDATE/DELETE rate with low autovacuum | Dead tuple accumulation → table bloat → seq scans get slower |
| VACUUM FULL in production | Acquires exclusive table lock; blocks all reads and writes |
| XID age approaching 2 billion | Aggressive autovacuum (or emergency manual VACUUM FREEZE) required |
| READ COMMITTED isolation + repeated reads | Same query may return different rows within one transaction |

## Obsidian connections
[[sql-ontology]] [[query-ontology]] [[schema-design-ontology]] [[performance-ontology]] [[security-ontology]] [[observability-ontology]]

## References
- MVCC: https://www.postgresql.org/docs/16/mvcc.html
- VACUUM: https://www.postgresql.org/docs/16/sql-vacuum.html
- Isolation Levels: https://www.postgresql.org/docs/16/transaction-iso.html
