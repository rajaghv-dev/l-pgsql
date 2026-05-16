# Lock Contention, Deadlocks, and Serializable Isolation

Level: Advanced

## One-line intuition
PostgreSQL's lock system is the traffic light at every intersection of concurrent activity — understanding the hierarchy of lock modes, which operations request them, and how SSI detects conflicts without blocking is the difference between a database that scales and one that serially queues every operation.

## Why this exists
Concurrent access to shared data requires coordination. PostgreSQL uses a multi-layered locking system: lightweight locks (LWLocks) for internal structures, and heavyweight locks for user-visible concurrency control. Misunderstanding lock modes causes accidental serialization — schema migrations that block production traffic, long transactions that starve short ones, and deadlocks that waste work.

## First-principles explanation

### Lock mode hierarchy (table-level locks)
PostgreSQL has 8 table-level lock modes, ordered by restrictiveness:

| Mode | Acquired by | Conflicts with |
|---|---|---|
| AccessShareLock | SELECT | AccessExclusiveLock only |
| RowShareLock | SELECT FOR UPDATE/SHARE | ExclusiveLock, AccessExclusiveLock |
| RowExclusiveLock | INSERT, UPDATE, DELETE | ShareLock, ShareRowExclusiveLock, ExclusiveLock, AccessExclusiveLock |
| ShareUpdateExclusiveLock | VACUUM, ANALYZE, CREATE INDEX CONCURRENTLY | ShareUpdateExclusiveLock, ShareRowExclusiveLock, ExclusiveLock, AccessExclusiveLock |
| ShareLock | CREATE INDEX (non-concurrent) | RowExclusiveLock and above |
| ShareRowExclusiveLock | CREATE TRIGGER, some DDL | RowShareLock and above |
| ExclusiveLock | Rare DDL | All except AccessShareLock |
| AccessExclusiveLock | ALTER TABLE, DROP TABLE, TRUNCATE, REINDEX, LOCK TABLE | Everything |

Critical implication: `ALTER TABLE` takes `AccessExclusiveLock`. This blocks ALL queries including SELECT during DDL. A long-running SELECT prevents the ALTER from acquiring the lock. And the ALTER waiting for the lock blocks all subsequent queries behind it — a "lock queue storm."

### Row-level locks
Separate from table locks. Row locks are stored in the tuple header (`t_infomask`), not in the lock table:
- `FOR UPDATE`: exclusive row lock (no other writer or `FOR UPDATE` reader)
- `FOR SHARE`: shared row lock (other `FOR SHARE` readers OK, writers blocked)
- `FOR NO KEY UPDATE`: like FOR UPDATE but allows `FOR KEY SHARE`
- `FOR KEY SHARE`: weakest; only blocks `FOR UPDATE`

Row locks do not appear in `pg_locks` for typical cases (they are stored in heap tuple headers). The lock table only contains row locks when they overflow to the lock table (`pg_locks.locktype = 'tuple'`).

### pg_locks — the live lock view
```sql
-- blocked: Docker not accessible
-- Find blocking chains
SELECT blocked_locks.pid AS blocked_pid,
       blocked_activity.usename AS blocked_user,
       blocking_locks.pid AS blocking_pid,
       blocking_activity.usename AS blocking_user,
       blocked_activity.query AS blocked_query,
       blocking_activity.query AS blocking_query
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

### Deadlock detection
When two transactions each hold a lock the other needs, they deadlock. PostgreSQL detects deadlocks by:
1. When a backend waits for a lock beyond `deadlock_timeout` (default 1 second), it runs the deadlock detector
2. The deadlock detector builds a "wait-for" graph: transaction A waits for B, B waits for A
3. If a cycle is found, PostgreSQL aborts one transaction (the "victim") with `ERROR: deadlock detected`
4. The surviving transaction proceeds

Deadlock prevention strategies:
- Always acquire resources in the same order across all transactions
- Keep transactions short (less time to accumulate locks)
- Use `SELECT ... FOR UPDATE SKIP LOCKED` for work queue patterns (avoids deadlock on queue items)
- Use `NOWAIT` to fail immediately instead of waiting: `SELECT ... FOR UPDATE NOWAIT`

### Lock queue storms
Pattern: Long SELECT → DDL waits → all subsequent SELECTs queue behind DDL
```
T1: SELECT ... (running for 10 min, holds AccessShareLock)
T2: ALTER TABLE ... (waiting for AccessExclusiveLock, blocked by T1)
T3: SELECT ... (waiting for AccessShareLock, blocked by T2's position in queue)
T4: SELECT ... (waiting, blocked by T3, blocked by T2...)
```

Prevention:
- Set `lock_timeout` on DDL sessions: `SET lock_timeout = '3s'; ALTER TABLE ...;` — fails fast instead of queuing
- Set `statement_timeout` to bound long queries
- Use `CREATE INDEX CONCURRENTLY` instead of `CREATE INDEX`
- Use `ADD COLUMN NOT NULL DEFAULT` (safe in PG 11+) instead of older multi-step patterns

### Transaction isolation levels
| Level | Dirty Read | Non-Repeatable Read | Phantom Read | Serialization Anomaly |
|---|---|---|---|---|
| READ UNCOMMITTED | Not in PG | Yes | Yes | Yes |
| READ COMMITTED (default) | No | Yes | Yes | Yes |
| REPEATABLE READ | No | No | No in PG | Yes |
| SERIALIZABLE | No | No | No | No |

PostgreSQL's default is `READ COMMITTED`. Most applications run here — each statement sees committed data at statement start, not transaction start.

### Serializable Snapshot Isolation (SSI)
PostgreSQL's SERIALIZABLE uses SSI (not locking). SSI:
1. Tracks read/write dependencies between concurrent transactions
2. Detects serialization anomalies (patterns of reads and writes that cannot occur in any serial order)
3. Aborts one transaction in the conflicting pair

SSI does not block reads or writes — it only aborts transactions when a conflict is detected at commit time. Applications must handle `ERROR: could not serialize access due to read/write dependencies` with a retry loop.

SSI is appropriate for:
- Financial transactions where anomalies would be catastrophic
- Complex multi-row invariants that are hard to express with explicit locks
- Replacing application-level pessimistic locking with optimistic conflict detection

Cost: SSI tracks predicate locks (`pg_locks.locktype = 'relation'` for serializable scans). Overhead is modest for most workloads.

## Micro-concepts
- **lock_timeout**: raises error if a lock cannot be acquired within N milliseconds. Essential for DDL safety.
- **deadlock_timeout**: how long to wait before running the deadlock detector (default 1s). Lower values → earlier detection but more false positives.
- **pg_blocking_pids(pid)**: returns the PIDs blocking a given PID. Simpler than the `pg_locks` join query.
- **SKIP LOCKED**: `SELECT ... FOR UPDATE SKIP LOCKED` — skips rows that are already locked. Perfect for task queue consumers with multiple workers.
- **advisory locks**: application-defined locks not tied to any table or row. `SELECT pg_advisory_lock(12345)` — acquires a named lock that persists until explicitly released or session ends.
- **ShareUpdateExclusiveLock**: held by VACUUM and ANALYZE — conflicts with itself. This means only one VACUUM can run on a table at a time.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Transactions lock rows they're changing. Conflicts cause waits. Deadlocks cause one transaction to be killed.

**Intermediate view**: Table-level locks from DDL are the main contention source in production. `CREATE INDEX CONCURRENTLY` avoids the full lock. Monitor `pg_locks` for blocking chains.

**Advanced view**: The lock queue is FIFO. A DDL statement waiting for AccessExclusiveLock blocks all subsequent requests, even if they would otherwise be compatible with the current holders. This makes `lock_timeout` on DDL sessions a requirement, not an option. SSI provides true serializability without read locks — the only PostgreSQL isolation level that guarantees full ACID in the presence of all anomalies. Understanding which DDL commands take which lock modes (the table above) lets you design zero-downtime migrations.

## Mental model
The lock system is a permit office:
- Different permit types (lock modes) allow different activities
- Some permits conflict with others (you can't build and demolish simultaneously)
- The queue is first-come-first-served: even if a new request is compatible with current holders, it must wait behind any queued incompatible request
- Deadlock is two people each holding the other's required permit and refusing to release
- SSI is a camera system: everyone moves freely, but if the camera detects a circular dependency pattern after the fact, one person is asked to redo their work

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_locks`, `pg_stat_activity`, `pg_blocking_pids()`.

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Simple blocker/blocked query
SELECT pid, pg_blocking_pids(pid) AS blocked_by, query, state
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;

-- All current locks
SELECT pid, locktype, relation::regclass, mode, granted
FROM pg_locks
WHERE NOT granted
ORDER BY pid;

-- Terminate a blocking session (requires superuser or pg_signal_backend)
SELECT pg_terminate_backend(<blocking_pid>);
```

**Non-SQL / hybrid view**: pgBadger parses lock timeout log messages. `log_lock_waits = on` (in postgresql.conf) logs details about lock waits exceeding `deadlock_timeout`. Essential for forensics.

## Design principle
**Make locks as narrow as possible, for as short a time as possible**: Acquire locks late, release them early. Perform all computation before starting the transaction. Use `SELECT ... FOR UPDATE` only when actually modifying the locked rows. Prefer optimistic concurrency (REPEATABLE READ + retry) over pessimistic locking (explicit FOR UPDATE) for read-heavy workloads.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: SERIALIZABLE sounds like the safest option and it is — but it comes with a retry requirement. Applications that don't handle `ERROR: could not serialize access` correctly will surface user-visible errors instead of retrying. Most ORMs and frameworks do not handle this automatically. Switching to SERIALIZABLE without application-level retry logic is dangerous.

**Creative**: Advisory locks can implement distributed mutex semantics within a PostgreSQL-connected application cluster. Multiple application servers can use `pg_advisory_lock(hash_key)` to coordinate exclusive access to an external resource (like an S3 bucket operation) without any external service. They are session-scoped (auto-released on disconnect) or transaction-scoped (`pg_advisory_xact_lock`).

**Systems**: Lock contention in OLTP is often a symptom of application-level design — many short transactions competing for the same rows. The root cause is usually either (1) a "hot row" (a counter, a status field updated by every transaction), or (2) a missing index causing table scans that touch more rows than necessary. A hot row can be replaced with `UPDATE ... RETURNING` + optimistic lock versioning, or with `INSERT ... ON CONFLICT` (upsert) patterns that avoid blocking.

## MCP and agent perspective
Agents that write to shared tables (e.g., an `agent_actions` table where multiple agent instances record their work) must coordinate access to avoid both deadlocks and lost updates. Best practice: use `INSERT` for event logs (append-only, no row-level contention), use `SELECT ... FOR UPDATE SKIP LOCKED` for task queue consumption, and avoid long-running transactions that hold row locks while waiting for LLM inference (which can take seconds). The LLM inference call should happen BEFORE opening the transaction, not inside it.

## Ontology perspective
The lock hierarchy is an ontology of conflict: it defines what activities are compatible and what activities are mutually exclusive. At the top level (AccessExclusiveLock) is the premise that nothing else can happen — absolute exclusivity. At the bottom (AccessShareLock) is pure read — infinitely parallel. The levels in between represent graduated claims on the data's future state. SSI extends this ontology from static conflict detection to temporal pattern recognition — it models not just the current state of locks but the history of reads and writes that produced it.

## Practice session

**Exercise 1 — View current locks**: Inspect the lock table.
```sql
-- blocked: Docker not accessible
SELECT pid, locktype, relation::regclass, mode, granted
FROM pg_locks
WHERE relation IS NOT NULL
ORDER BY relation, mode;
```

**Exercise 2 — Simulate lock contention**: Open two sessions.
```sql
-- Session 1:
-- blocked: Docker not accessible
BEGIN;
SELECT * FROM orders WHERE id = 1 FOR UPDATE;
-- (keep session open)

-- Session 2:
-- blocked: Docker not accessible
SELECT pg_blocking_pids(pg_backend_pid());
UPDATE orders SET status = 'shipped' WHERE id = 1;  -- will block
```

**Exercise 3 — SKIP LOCKED for queue**: Multiple workers consuming a task queue.
```sql
-- blocked: Docker not accessible
-- Worker pattern: each worker takes one task without blocking others
SELECT id, payload FROM task_queue
WHERE status = 'pending'
ORDER BY created_at
LIMIT 1
FOR UPDATE SKIP LOCKED;
```

**Exercise 4 — Advisory lock**: Coordinate across connections.
```sql
-- blocked: Docker not accessible
-- Session 1:
SELECT pg_advisory_lock(42);
-- Session 2:
SELECT pg_try_advisory_lock(42);  -- returns false without blocking
```

**Exercise 5 — DDL with lock_timeout**: Safe schema change pattern.
```sql
-- blocked: Docker not accessible
SET lock_timeout = '3s';
ALTER TABLE orders ADD COLUMN notes text;
-- Fails fast if blocked, instead of creating a lock queue storm
```

## References
- PostgreSQL Documentation: [Explicit Locking](https://www.postgresql.org/docs/16/explicit-locking.html)
- PostgreSQL Documentation: [Transaction Isolation](https://www.postgresql.org/docs/16/transaction-iso.html)
- PostgreSQL Documentation: [Serializable Snapshot Isolation](https://www.postgresql.org/docs/16/transaction-iso.html#XACT-SERIALIZABLE)
- PostgreSQL Documentation: [pg_locks](https://www.postgresql.org/docs/16/view-pg-locks.html)
- Kevin Grittner & Dan Ports: [Serializable Snapshot Isolation in PostgreSQL](https://drkp.net/papers/ssi-vldb12.pdf)
- Laurenz Albe: [Lock Monitoring in PostgreSQL](https://www.cybertec-postgresql.com/en/lock-monitoring/)
- 2ndQuadrant: [Zero Downtime Postgres Migrations](https://www.braintreepayments.com/blog/safe-operations-for-high-volume-postgresql/)
