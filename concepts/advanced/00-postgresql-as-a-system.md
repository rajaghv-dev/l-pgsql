# PostgreSQL as a System

Level: Advanced

## One-line intuition
PostgreSQL is not just a query engine — it is a multi-process operating-system-level application with dedicated background workers, a shared memory arena, and a pipeline from bytes on disk to rows in your result set.

## Why this exists
Understanding PostgreSQL as a system — not as a black box — lets you reason about why queries stall, where memory goes, what happens during a crash, and how to tune each layer independently. Every performance problem traces back to one of: process behavior, memory contention, IO patterns, or lock scheduling. You cannot diagnose what you cannot model.

## First-principles explanation
PostgreSQL uses the **process-per-connection** model: each client connection spawns a dedicated OS process (backend). Processes communicate through shared memory — a single contiguous region allocated at startup containing shared buffers, lock tables, WAL buffers, and control structures. This design avoids thread-safety complexity at the cost of per-process overhead (~5-10 MB RSS per backend at rest).

### The query pipeline
```
Client sends SQL text
  → Parser (pg_parse_query)         — produces raw parse tree
  → Analyzer/Rewriter               — resolves names, applies rewrite rules (views, rules)
  → Planner/Optimizer               — produces optimal plan tree (cost model)
  → Executor                        — executes plan, fetches rows from storage
  → Result sent to client
```

Each stage is inspectable: `EXPLAIN` shows planner output. `pg_stat_activity` shows executor state. `auto_explain` logs full plans for slow queries.

### Process roles
| Process | Role |
|---|---|
| postmaster | Parent process: accepts connections, forks backends, monitors children |
| backend (postgres) | One per connection: runs queries, holds locks, uses shared buffers |
| WAL writer | Flushes WAL buffers to WAL segment files on a schedule |
| checkpointer | Writes dirty shared buffers to data files at checkpoint intervals |
| autovacuum launcher | Spawns autovacuum workers; each worker vacuums one table at a time |
| autovacuum worker | Removes dead tuples, updates statistics, triggers analyze |
| bgwriter | Proactively writes dirty buffers to reduce checkpoint pressure |
| wal receiver | (replica) Streams WAL from primary |
| logical replication worker | Applies logical changes from a publication |
| archiver | Copies WAL segments to the archive location |

### Shared memory layout (simplified)
```
shared_buffers          — buffer pool for page cache (most important)
WAL buffers (wal_buffers) — ring buffer of WAL records before flush
Lock space              — fast-path locks + main lock table (LWLocks + heavyweight locks)
Proc array              — one entry per backend: PID, transaction ID, query state
CLOG / commit log       — transaction status bits (committed/aborted)
Background worker slots — for registered extensions
```

All these live in a single shared memory segment. Size is determined at startup; it cannot be resized without a restart.

## Micro-concepts
- **postmaster**: parent of all PostgreSQL processes. If it dies, all backends die.
- **backend fork**: `fork()` is cheap on Linux (copy-on-write), making process-per-connection practical.
- **shared_buffers**: the most impactful single parameter. Typically 25% of RAM for dedicated servers.
- **WAL**: write-ahead log — every change is written to WAL before the data page. Enables crash recovery, PITR, and replication.
- **checkpoint**: point where all dirty buffers are guaranteed written to data files. After a crash, recovery replays WAL only from the last checkpoint.
- **pg_stat_activity**: the live view of all backend process states. Your first diagnostic tool.
- **postmaster.pid**: the lock file; if it exists and postmaster is dead, PostgreSQL will refuse to start.
- **PGDATA**: the root directory. Contains `pg_wal/`, `base/` (databases), `global/` (cluster-wide tables), `pg_stat/`.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: PostgreSQL is a server that runs SQL queries and stores data. You connect, query, disconnect.

**Intermediate view**: PostgreSQL has a buffer cache, WAL for durability, autovacuum for cleanup. Tuning `shared_buffers`, `work_mem`, `max_connections` matters.

**Advanced view**: Each query traverses a full pipeline (parse → plan → execute). The planner's cost model determines plan shape. Shared memory is a finite resource divided between buffer pool, lock space, and process metadata. WAL is the backbone of durability and replication. Process count is bounded by OS limits and connection overhead. Understanding each process's role lets you predict bottlenecks before they occur — postmaster OOM kills, WAL writer falling behind, checkpointer stalling IO.

## Mental model
Think of PostgreSQL as a factory floor:
- **postmaster** = factory manager (hires workers, monitors safety)
- **backends** = workers (each running a specific job)
- **shared_buffers** = the warehouse of in-progress materials
- **WAL** = the ledger: every change is written in the ledger before touching the warehouse
- **checkpointer** = the end-of-shift reconciliation: warehouse state committed to permanent records
- **autovacuum** = the janitor: cleans up stale materials so the warehouse does not fill with garbage

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_stat_activity` shows all running backends. `pg_stat_bgwriter` shows checkpointer and bgwriter statistics. `pg_stat_wal` shows WAL write throughput.

**SQL view**:
```sql
-- blocked: Docker not accessible
-- List all backend processes and their states
SELECT pid, usename, application_name, state, wait_event_type, wait_event, query
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
ORDER BY state;

-- Checkpointer health
SELECT checkpoints_timed, checkpoints_req, buffers_checkpoint, buffers_clean
FROM pg_stat_bgwriter;
```

**Non-SQL / hybrid view**: On Linux, `ps aux | grep postgres` shows all backend processes. `pmap <pid>` shows shared memory mapping. `strace -p <pid>` shows system calls (reads, writes, futex waits). `perf top` shows CPU hotspots per function.

## Design principle
**Single-writer WAL + MVCC reader isolation**: PostgreSQL achieves high read concurrency by never blocking readers with writers (MVCC), while serializing all writes through WAL. This design trades storage overhead (dead tuples, WAL volume) for simplicity and correctness. Every design decision — vacuum, bloat, replication lag — traces to this core trade-off.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: Process-per-connection does not scale to tens of thousands of connections. PgBouncer or similar connection poolers are required in production above ~200-300 connections. The 5-10 MB per backend × 1000 connections = 5-10 GB of RAM just for process metadata. This is a known architectural limitation PostgreSQL has not yet addressed natively (though connection pooling is being discussed for core inclusion).

**Creative**: The process model is an accidental advantage: since each backend is an OS process, you can use OS tools (cgroups, nice, ionice) to throttle specific backends. You can also attach a debugger to a specific backend PID without affecting others.

**Systems**: WAL is the single point through which all durability passes. WAL write throughput limits your write throughput. WAL archiving latency limits your RPO. WAL replication lag limits your replica freshness. Understanding WAL means understanding the entire reliability posture of your cluster.

## MCP and agent perspective
An AI agent querying PostgreSQL is itself a backend process. Each agent query competes for shared buffer space and lock table entries. In high-agent-density deployments (many concurrent agent sessions), `max_connections` becomes a hard limit. Use a connection pool (PgBouncer in transaction mode) so that 1000 logical agent sessions map to 50 physical backends. Monitor `pg_stat_activity` to detect agent queries that are stuck in lock waits or idle-in-transaction — both are agent bugs that hold resources.

## Ontology perspective
PostgreSQL-as-a-system is a **sociotechnical actor**: it has identity (cluster UUID in `pg_control`), memory (shared buffers, WAL), time awareness (transaction IDs, LSN), communication channels (replication slots, logical decoding), and self-maintenance behaviors (autovacuum, checkpointing). Modeling it as an agent rather than a passive store changes how you design around it — you cooperate with its background processes rather than fighting them.

## Practice session

**Exercise 1 — Process census**: Count live backends by state.
```sql
-- blocked: Docker not accessible
SELECT state, count(*) FROM pg_stat_activity GROUP BY state ORDER BY count DESC;
```

**Exercise 2 — Shared memory headroom**: Estimate buffer pool usage.
```sql
-- blocked: Docker not accessible
SELECT count(*) AS used_buffers,
       round(count(*) * 8.0 / 1024, 1) AS used_mb
FROM pg_buffercache
WHERE relfilenode IS NOT NULL;
```

**Exercise 3 — WAL write rate**: Observe WAL generation.
```sql
-- blocked: Docker not accessible
SELECT pg_current_wal_lsn(), pg_walfile_name(pg_current_wal_lsn());
-- Run a write workload, then check again:
SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '<previous_lsn>'::pg_lsn)) AS wal_generated;
```

**Exercise 4 — Checkpoint gap**: How long since the last checkpoint?
```sql
-- blocked: Docker not accessible
SELECT now() - pg_postmaster_start_time() AS uptime,
       checkpoints_timed, checkpoints_req
FROM pg_stat_bgwriter;
```

**Exercise 5 — Identify your own backend**: Map your session to its OS PID.
```sql
-- blocked: Docker not accessible
SELECT pg_backend_pid(), inet_server_addr(), inet_server_port();
```

## References
- PostgreSQL Documentation: [Overview of PostgreSQL Internals](https://www.postgresql.org/docs/16/overview.html)
- PostgreSQL Documentation: [pg_stat_activity](https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW)
- PostgreSQL Documentation: [Background Processes](https://www.postgresql.org/docs/16/runtime-config-resource.html)
- Hironobu Suzuki: [The Internals of PostgreSQL](https://www.interdb.jp/pg/) — free online, chapter 1 (process model), chapter 2 (shared memory)
- Bruce Momjian: [PostgreSQL Internals Through Pictures](https://momjian.us/main/writings/pgsql/internalpics.pdf)
