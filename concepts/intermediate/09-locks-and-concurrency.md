# Locks and Concurrency
Level: Intermediate

## One-line intuition
PostgreSQL uses a hierarchy of locks to protect shared data; understanding which statements acquire which locks — and how to avoid deadlocks — is essential for building concurrent applications.

## Why this exists
Even with MVCC providing read-write non-blocking, writes to the same row still need coordination. Locks are the mechanism that prevents two transactions from concurrently making conflicting changes. Without locks, two sessions updating the same account balance would produce a lost-update anomaly.

## First-principles explanation
PostgreSQL has two levels of locking:

**1. Table-level locks** — acquired on the relation itself. Modes range from weakest (ACCESS SHARE) to strongest (ACCESS EXCLUSIVE). Most DML takes RowExclusiveLock; DDL like ALTER TABLE takes AccessExclusiveLock. Modes conflict with each other according to a compatibility matrix.

**2. Row-level locks** — acquired on individual heap tuples. Implemented via the tuple's `xmax` field (set to the locking transaction's XID with special flag bits). No separate lock table entry for rows — this is why PostgreSQL can hold millions of row locks without memory overhead.

**Lock compatibility matrix (table-level, partial):**

| Requested \ Held | ACCESS SHARE | ROW SHARE | ROW EXCL | SHARE | SHARE ROW EXCL | EXCL | ACCESS EXCL |
|---|---|---|---|---|---|---|---|
| ACCESS SHARE | OK | OK | OK | OK | OK | OK | WAIT |
| ROW EXCL | OK | OK | OK | WAIT | WAIT | WAIT | WAIT |
| ACCESS EXCL | WAIT | WAIT | WAIT | WAIT | WAIT | WAIT | WAIT |

**Deadlock detection:** PostgreSQL runs a deadlock detector every `deadlock_timeout` (default 1 second). When a cycle is detected, one transaction is aborted with `ERROR: deadlock detected`. The application must retry.

## Micro-concepts
- **pg_locks** — system view showing all currently held and awaited locks
- **pg_stat_activity** — shows what each backend is doing; join with pg_locks on `pid`
- **NOWAIT** — `SELECT ... FOR UPDATE NOWAIT` fails immediately rather than waiting for a lock
- **SKIP LOCKED** — `SELECT ... FOR UPDATE SKIP LOCKED` skips rows that are already locked; essential for queue patterns
- **advisory locks** — application-controlled locks (`pg_advisory_lock(key)`) with no relation to any table; useful for distributed critical sections
- **deadlock_timeout** — GUC parameter; time to wait before running deadlock detection
- **lock_timeout** — GUC; abort if waiting for a lock longer than this duration
- **statement_timeout** — GUC; abort any statement running longer than this duration

## Beginner view
Locks are like bathroom stalls: you can't enter if someone is already inside (exclusive lock). Some operations are like reading a menu — many people can do it at once (shared lock). A deadlock is two people each blocking a door the other needs to open.

## Intermediate view
Understand which lock mode your DDL takes before running it in production. `ALTER TABLE ADD COLUMN` with a default that requires a table rewrite takes AccessExclusiveLock and will block all reads and writes. Adding a NOT NULL constraint with `NOT VALID` first allows concurrent operation. Always check `pg_locks` joined with `pg_stat_activity` to diagnose lock waits.

## Advanced view
Row-level locking modes: FOR UPDATE (strongest), FOR NO KEY UPDATE, FOR SHARE, FOR KEY SHARE. `FOR KEY SHARE` allows concurrent foreign key checks without blocking each other. Multi-version tuple locks are stored in the tuple header's `t_infomask` bits. When a tuple is locked by multiple transactions simultaneously, PostgreSQL uses a `MultiXact` ID to track the set.

## Mental model
Picture a conference room booking system: table-level locks are building-wide policies (no events during fire drill = ACCESS EXCLUSIVE), row-level locks are individual room reservations. SKIP LOCKED is a task queue where workers skip rooms already booked by colleagues and grab the next available one.

## PostgreSQL view
```sql
-- See current locks and who holds/waits for them
SELECT
    l.pid,
    l.relation::regclass,
    l.mode,
    l.granted,
    a.query,
    a.state
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.relation IS NOT NULL
ORDER BY l.granted, l.pid;

-- SELECT FOR UPDATE — row-level exclusive lock
BEGIN;
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
-- row is locked; other sessions block on the same row
COMMIT;

-- NOWAIT — fail immediately if locked
SELECT * FROM accounts WHERE id = 1 FOR UPDATE NOWAIT;

-- SKIP LOCKED — queue worker pattern
BEGIN;
SELECT * FROM job_queue
WHERE status = 'pending'
ORDER BY created_at
LIMIT 1
FOR UPDATE SKIP LOCKED;
-- process the job
UPDATE job_queue SET status = 'done' WHERE id = :id;
COMMIT;

-- Advisory lock for distributed critical section
SELECT pg_advisory_lock(12345);
-- ... do critical work
SELECT pg_advisory_unlock(12345);
```

## SQL view
The SQL standard specifies `SELECT ... FOR UPDATE` and `SELECT ... FOR SHARE` but does not define advisory locks or the detailed lock mode hierarchy. PostgreSQL's implementation is broader than the standard.

## Non-SQL or hybrid view
Redis uses optimistic concurrency via WATCH/MULTI/EXEC — similar to PostgreSQL's SERIALIZABLE but at key level. Distributed systems use distributed locks (ZooKeeper, etcd, Redlock) for cross-node critical sections. In microservice architectures, database-level locks only protect intra-database concurrency; cross-service consistency requires saga patterns or distributed locking.

## Design principle
**Minimize lock duration, minimize lock scope.** Keep transactions short. Lock the narrowest set of rows needed. Use SKIP LOCKED for queue patterns instead of application-level polling. Use `lock_timeout` to detect and surface lock contention rather than hanging indefinitely. Structure multi-table updates in a consistent order across all transactions to prevent deadlocks.

## Critical thinking
- The most common production incident involving locks is a long-running transaction blocking schema migrations. A single idle-in-transaction session holding a RowExclusiveLock will prevent any ALTER TABLE from completing.
- `pg_blocking_pids(pid)` returns the PIDs that are blocking a given session — use this in monitoring scripts.
- Lock contention is often a symptom of poor schema design (hot rows) rather than a problem to be solved with locking tricks.

## Creative thinking
Use `pg_advisory_xact_lock(hashtext('resource-name'))` as a named mutex for distributed workflows. Because the lock is tied to the transaction, it is automatically released on commit/rollback — no cleanup code required. This pattern works well for "exactly once" task processing in multi-worker systems.

## Systems thinking
Lock contention creates cascading delays: one blocked session blocks the next, forming a queue. Under high load, even a 100ms lock can cascade into a seconds-long tail latency for all subsequent requests. Monitor `pg_stat_activity.wait_event_type = 'Lock'` and alert when more than N sessions are in a lock wait state. Connection poolers (PgBouncer) can amplify this: many application connections mapping to few database connections can make one lock hold up many application threads.

## MCP and agent perspective
An MCP agent performing concurrent mutations should always set `lock_timeout = '2s'` at the start of its session to prevent indefinite blocking. For queue-style operations (claim next task), use FOR UPDATE SKIP LOCKED — this is the canonical pattern for concurrent workers without polling or external message queues. An agent that detects `ERROR: deadlock detected` should implement exponential backoff retry.

## Ontology perspective
In an ontology, a lock represents a temporary claim on the right to modify a concept. The lock mode encodes the type of claim: FOR SHARE is "I am observing this concept and it must not change"; FOR UPDATE is "I am transforming this concept". Deadlocks reveal circular dependencies in the ontology's dependency graph — two transformations that each require the other's precondition to be stable first. Resolving deadlocks often means restructuring the workflow to match the ontology's natural dependency order.

## Practice session
See `practice/intermediate/05-mvcc-and-locking/` for hands-on exercises demonstrating lock inspection, deadlock reproduction, and SKIP LOCKED queue patterns.

## References
- PostgreSQL docs — Explicit Locking: https://www.postgresql.org/docs/16/explicit-locking.html
- PostgreSQL docs — pg_locks: https://www.postgresql.org/docs/16/view-pg-locks.html
- PostgreSQL docs — Advisory Locks: https://www.postgresql.org/docs/16/functions-admin.html#FUNCTIONS-ADVISORY-LOCKS
- PostgreSQL docs — Lock Monitoring: https://www.postgresql.org/docs/16/monitoring-locks.html
- Laurenz Albe, "Lock Monitoring in PostgreSQL": https://www.cybertec-postgresql.com/en/lock-monitoring-in-postgresql/
