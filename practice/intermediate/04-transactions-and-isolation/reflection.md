# Reflection — Transactions and Isolation Levels

## Key takeaways
- **READ COMMITTED is the default** — it is correct for most OLTP workloads but allows non-repeatable reads and phantom reads.
- **REPEATABLE READ** is a snapshot transaction — the same query returns the same result no matter how many times it runs within the transaction.
- **SERIALIZABLE** is the safest but requires retry logic. It is essential for workflows involving "read → decide → write" across multiple rows.
- Transactions should be as short as possible. Long-held transactions block VACUUM and accumulate lock pressure.

## Common mistakes
1. Assuming READ COMMITTED means "I see a consistent snapshot throughout my transaction" — it does not. Each statement sees the latest committed state.
2. Not handling `SQLSTATE 40001` (serialization failure) in application code. Every SERIALIZABLE transaction can fail; the application must retry.
3. Using long-running transactions for background tasks. Use batch commits instead.
4. Mixing isolation levels across related operations — the weakest level in any path defines the system's actual guarantee.

## Deeper questions
1. How does PostgreSQL's SSI (Serializable Snapshot Isolation) differ from two-phase locking (2PL)? Which has lower contention?
2. If you need "read-your-own-writes" consistency in a distributed system with read replicas, what isolation guarantees does the primary need to provide?
3. When is an application-level optimistic lock (version column) preferable to SERIALIZABLE?
4. How does `idle_in_transaction_session_timeout` protect the system from long-running transactions?

## Connection to MVCC
Isolation levels are implemented through MVCC snapshots, not through row locks (for reads). This is why readers never block writers in PostgreSQL. The isolation level controls *which version of each row* is visible, not *whether rows are locked*.

## Connection to locks
FOR UPDATE within a transaction still acquires a row-level lock regardless of isolation level. The combination of MVCC (for read isolation) and row locks (for write protection) is what enables correct concurrent transfers without requiring the database to be single-threaded.

## What to explore next
- Concept 08: MVCC and Snapshot Thinking — understand the xmin/xmax mechanics behind these exercises
- Concept 09: Locks and Concurrency — understand lock modes, deadlocks, and SKIP LOCKED
