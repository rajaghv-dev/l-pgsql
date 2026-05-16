# Transactions and Isolation Levels
Level: Intermediate

## One-line intuition
A transaction is a fenced unit of work where either everything commits or nothing does; isolation levels control how much concurrent transactions can see of each other's in-progress work.

## Why this exists
Without isolation guarantees, concurrent readers and writers would see half-written data, repeated queries within one session would return different rows, and long-running reports would observe changes mid-flight. ACID's "I" exists to let multiple sessions share one database without corrupting each other's mental model of the world.

## First-principles explanation
PostgreSQL uses MVCC (Multi-Version Concurrency Control) as the engine behind isolation. Instead of locking rows for reads, it keeps multiple versions of each row and assigns each transaction a snapshot — a point-in-time view. The isolation level determines *which snapshot* the transaction is handed and *when* that snapshot is refreshed.

Four read anomalies are possible if isolation is insufficient:

| Anomaly | Description |
|---|---|
| Dirty read | Reading uncommitted data from another transaction |
| Non-repeatable read | Row read twice returns different values (update committed in between) |
| Phantom read | Set of rows matching a predicate changes between two reads (insert/delete committed in between) |
| Serialization anomaly | Two correct-in-isolation transactions together produce an impossible result |

PostgreSQL supports three effective isolation levels:

| Level | Dirty read | Non-repeatable read | Phantom read | Serialization anomaly |
|---|---|---|---|---|
| READ COMMITTED (default) | Impossible | Possible | Possible | Possible |
| REPEATABLE READ | Impossible | Impossible | Impossible* | Possible |
| SERIALIZABLE | Impossible | Impossible | Impossible | Impossible |

*PostgreSQL's REPEATABLE READ also prevents phantom reads, stronger than the SQL standard requires.

## Micro-concepts
- **BEGIN / COMMIT / ROLLBACK** — explicit transaction boundary markers
- **SAVEPOINT / ROLLBACK TO SAVEPOINT** — nested rollback points within a transaction
- **SET TRANSACTION ISOLATION LEVEL** — must be issued before the first statement in the transaction
- **autocommit** — when no explicit BEGIN is used, each statement is its own transaction
- **SSI (Serializable Snapshot Isolation)** — PostgreSQL's SERIALIZABLE uses SSI, a lock-free algorithm that detects serialization anomalies and aborts one of the conflicting transactions

## Beginner view
Think of transactions like a shopping cart checkout: you see the total, confirm it, and either the whole payment goes through or nothing is charged. Isolation levels are like asking: "can I see items that other people are currently holding?"

## Intermediate view
READ COMMITTED re-acquires a new snapshot for every statement. REPEATABLE READ takes a snapshot at the first statement and holds it for the transaction duration. SERIALIZABLE adds a dependency graph to detect write skew and serialization anomalies, aborting transactions that would violate a serial execution order.

## Advanced view
SSI tracks rw-antidependencies between transactions. A serialization anomaly (write skew) occurs when two transactions each read data the other writes. PostgreSQL detects the dangerous cycle and raises `ERROR: could not serialize access due to read/write dependencies among transactions`. The aborted transaction must be retried. Design retry loops around SERIALIZABLE transactions.

## Mental model
Imagine each transaction as a photograph of the database at a specific instant. READ COMMITTED re-takes the photo before every statement. REPEATABLE READ takes one photo at the start and reads from it throughout. SERIALIZABLE additionally tracks who else touched the subjects in your photo and aborts if the result couldn't have come from any serial order.

## PostgreSQL view
```sql
-- Explicit isolation level
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM accounts WHERE id = 1;  -- snapshot locked here
-- ... other statements
COMMIT;

-- Shorthand
BEGIN ISOLATION LEVEL SERIALIZABLE;
```

## SQL view
The SQL standard defines READ UNCOMMITTED, READ COMMITTED, REPEATABLE READ, SERIALIZABLE. PostgreSQL maps READ UNCOMMITTED to READ COMMITTED (dirty reads are never allowed), so effectively only three levels exist.

## Non-SQL or hybrid view
ORMs like SQLAlchemy or Hibernate use the database's isolation levels but may re-try on serialization failure automatically. Some ORMs default to READ COMMITTED; you must explicitly request SERIALIZABLE for financial workflows. Application-level optimistic locking (version columns) is an alternative to database-level SERIALIZABLE for some patterns.

## Design principle
**Choose the weakest isolation level that still gives you correct semantics.** SERIALIZABLE is the safest but has throughput cost. READ COMMITTED suffices for most OLTP. Use REPEATABLE READ or SERIALIZABLE for reporting transactions that must see a consistent point in time, and for any workflow involving "read-then-write" decisions (balance checks, seat reservations).

## Critical thinking
- Most bugs attributed to "data corruption" in production are actually isolation-level bugs — two concurrent transactions each made a locally valid decision.
- SERIALIZABLE does not mean "slow" — SSI has lower overhead than 2PL (two-phase locking). The cost is potential transaction retries.
- READ COMMITTED with advisory locks is a common pattern that mimics SERIALIZABLE for specific rows without the full SSI overhead.

## Creative thinking
Model reservation systems, inventory deductions, and point balances always using at least REPEATABLE READ. A hotel booking that reads "1 room available" and then books it needs the guarantee that no phantom row appears between the check and the insert.

## Systems thinking
Isolation level choice is a systems-wide contract. If microservice A uses SERIALIZABLE but microservice B calls the same tables with READ COMMITTED, the system as a whole is only as strong as the weakest isolation. Distributed transactions across services require saga patterns or 2PC; no single isolation level fixes cross-service anomalies.

## MCP and agent perspective
An MCP agent managing financial data should wrap every multi-step workflow (read balance → compute → write) in an explicit transaction with SERIALIZABLE isolation and include a retry loop for `ERROR 40001` (serialization failure). Autocommit mode is never appropriate for agent-driven financial mutations.

## Ontology perspective
In an ontology, a "transaction" is a boundary event — a moment when the world transitions from one valid state to another. Isolation levels define visibility rules across concurrent boundary events. SERIALIZABLE ensures that overlapping boundary events appear as if they occurred in a strict sequence, preserving the integrity of causal chains in the ontology.

## Practice session
See `practice/intermediate/04-transactions-and-isolation/` for hands-on exercises covering isolation level comparison, phantom-read demonstration, and SAVEPOINT usage.

## References
- PostgreSQL docs — Transaction Isolation: https://www.postgresql.org/docs/16/transaction-iso.html
- PostgreSQL docs — BEGIN: https://www.postgresql.org/docs/16/sql-begin.html
- PostgreSQL docs — SET TRANSACTION: https://www.postgresql.org/docs/16/sql-set-transaction.html
- A. Fekete et al. "Making Snapshot Isolation Serializable" (ACM TODS 2005) — SSI foundation paper
- Martin Kleppmann, *Designing Data-Intensive Applications*, Chapter 7 — Transactions (O'Reilly)
