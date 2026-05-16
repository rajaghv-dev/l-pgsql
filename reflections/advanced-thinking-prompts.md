# Advanced Thinking Prompts

20+ questions for engineers running PostgreSQL in production — performance, concurrency, internals, and operational safety.

---

## EXPLAIN and Query Planning

### Q: EXPLAIN shows "rows=1" but the query returns 10,000 rows. What does this mean, and how does it affect performance?
**Type:** Systems  
**Level:** Advanced  
**Hint:** The planner estimated 1 row but found 10,000. This means the statistics were wrong. What downstream decisions did the planner make based on that estimate? Think about join strategy, memory allocation, and parallelism decisions.  
**Reference:** [[diagrams/sql-query-lifecycle]]

---

### Q: When does the planner use a parallel sequential scan, and what limits its parallelism?
**Type:** Systems  
**Level:** Advanced  
**Hint:** Parallel queries use multiple worker processes. What parameters control the maximum parallelism (`max_parallel_workers_per_gather`)? When does the planner decide parallelism is not worth the overhead?  
**Reference:** [[diagrams/sql-query-lifecycle]]

---

### Q: What is the difference between `EXPLAIN ANALYZE` on a query that returns 1M rows vs one that returns 10 rows, in terms of timing accuracy?
**Type:** Critical  
**Level:** Advanced  
**Hint:** EXPLAIN ANALYZE must execute the query. For a 1M-row result, it must produce and discard all 1M rows. How does this affect the timing you see? When is `EXPLAIN (ANALYZE, FORMAT JSON)` more useful than the default text output?  
**Reference:** [[diagrams/sql-query-lifecycle]]

---

### Q: What is the "generic plan vs custom plan" problem in prepared statements, and how does it affect parameterized queries?
**Type:** Systems  
**Level:** Advanced  
**Hint:** PostgreSQL can generate a plan for a specific parameter value (custom) or a generic plan for all values. What is the risk of using a generic plan on a table with high data skew (one value represents 95% of rows)?  
**Reference:** [[diagrams/sql-query-lifecycle]]

---

## MVCC and Vacuum

### Q: What is the risk of a long-running autovacuum on a busy table?
**Type:** Systems  
**Level:** Advanced  
**Hint:** Autovacuum takes a `ShareUpdateExclusiveLock` — it does not block normal DML. But what does it do to I/O? What does it do to the dead tuple accumulation rate if it cannot keep up?  
**Reference:** [[design-principles/advanced-design-principles]] Principle 1

---

### Q: What is transaction ID wraparound, and what does PostgreSQL do when it is about to happen?
**Type:** Critical  
**Level:** Advanced  
**Hint:** Transaction IDs are 32-bit. At 2 billion, they wrap. PostgreSQL tracks `age(datfrozenxid)`. What happens at 2 billion - 10 million? What is the "autovacuum to prevent wraparound" mode?  
**Reference:** [[design-principles/advanced-design-principles]] Principle 9

---

### Q: Why does table bloat happen even when you DELETE and INSERT equal numbers of rows?
**Type:** Systems  
**Level:** Advanced  
**Hint:** Think about what MVCC does with UPDATE and DELETE. Do heap files shrink after VACUUM? What is the difference between reclaiming space within a file vs returning it to the OS?  
**Reference:** [[diagrams/transaction-mvcc-flow]]

---

### Q: What is HOT (Heap-Only Tuple) update, and when does it apply?
**Type:** Systems  
**Level:** Advanced  
**Hint:** A HOT update avoids creating a new index entry by chaining the new tuple to the old one on the same heap page. What conditions must be met for HOT to apply? What is the benefit for write-heavy columns that are not indexed?  
**Reference:** [[concepts/intermediate/08-mvcc-and-snapshot-thinking]]

---

## Locking and Concurrency

### Q: What lock does `ALTER TABLE ADD COLUMN` take, and how has its behavior changed across PostgreSQL versions?
**Type:** Systems  
**Level:** Advanced  
**Hint:** In PG 11+, adding a column with a constant default is instant and takes only a brief `AccessExclusiveLock`. Before PG 11, it rewrote the table. What is the current behavior for volatile defaults (e.g., `DEFAULT now()`)?  
**Reference:** [[design-principles/concurrency-design-principles]] Principle 4

---

### Q: How does PostgreSQL choose between a hash join and a merge join?
**Type:** Systems  
**Level:** Advanced  
**Hint:** Hash join builds a hash table in memory (`work_mem`). Merge join requires both inputs to be sorted. When is merge join preferred over hash join? Consider input size, available memory, and whether inputs are already sorted.  
**Reference:** [[diagrams/sql-query-lifecycle]]

---

### Q: What is a lock queue, and how can a short DDL operation cause a traffic jam for hundreds of connections?
**Type:** Systems  
**Level:** Advanced  
**Hint:** `AccessExclusiveLock` blocks all DML. If one long-running SELECT holds a lock and a DDL tries to acquire `AccessExclusiveLock`, all subsequent DML waits behind the DDL. Draw the queue.  
**Reference:** [[design-principles/concurrency-design-principles]] Principle 4

---

### Q: What is the difference between `pg_terminate_backend()` and `pg_cancel_backend()`?
**Type:** Critical  
**Level:** Advanced  
**Hint:** `pg_cancel_backend()` sends SIGINT — cancels the current query but keeps the connection. `pg_terminate_backend()` sends SIGTERM — kills the connection entirely. What happens to in-flight transactions in each case?  
**Reference:** [[design-principles/concurrency-design-principles]]

---

## Partitioning and Large Tables

### Q: What is partition pruning, and what prevents it from working?
**Type:** Systems  
**Level:** Advanced  
**Hint:** The planner can skip scanning partitions that cannot contain rows matching the WHERE clause. What must the WHERE clause contain for pruning to work? What happens if you partition by date but query by a non-constant expression like `WHERE date_col > now()`?  
**Reference:** [[design-principles/advanced-design-principles]] Principle 4

---

### Q: Why does adding a NOT NULL constraint to an existing table without a default potentially require a table rewrite?
**Type:** Critical  
**Level:** Advanced  
**Hint:** Adding NOT NULL to an existing column with NULL values would violate the constraint immediately. If the column has no existing NULLs, PostgreSQL can skip the rewrite (PG 11+ constraint check). What is the `NOT VALID` pattern for large tables?  
**Reference:** [[design-principles/advanced-design-principles]] Principle 4

---

### Q: What is `pg_repack` and why is it preferred over `VACUUM FULL` for production tables?
**Type:** Critical  
**Level:** Advanced  
**Hint:** VACUUM FULL holds `AccessExclusiveLock` for the entire rewrite. pg_repack works concurrently by creating a new table structure alongside the old one. What brief lock does it take at the final switchover?  
**Reference:** [[design-principles/advanced-design-principles]] Principle 3

---

## Observability

### Q: What does `pg_stat_statements` show you, and what does it not show you?
**Type:** Ontology  
**Level:** Advanced  
**Hint:** It shows aggregated statistics for normalized query text. Does it show individual query executions? Does it show which user ran the query? Does it show when the query ran?  
**Reference:** [[diagrams/extension-ecosystem-map]]

---

### Q: What is the difference between `shared_buffers` and `effective_cache_size`?
**Type:** Ontology  
**Level:** Advanced  
**Hint:** `shared_buffers` is the actual memory allocation for PostgreSQL's page cache. `effective_cache_size` is a planner hint about how much OS cache is available. Does changing `effective_cache_size` allocate more memory?  
**Reference:** [[diagrams/postgres-mental-model]]

---

### Q: What does `pg_buffercache` tell you, and how do you use it to diagnose cache thrashing?
**Type:** Systems  
**Level:** Advanced  
**Hint:** `pg_buffercache` shows which pages are currently in shared buffers. How would you identify if a specific table is consuming most of shared buffers? What does a high `usagecount` mean?  
**Reference:** [[diagrams/extension-ecosystem-map]]

---

### Q: Why might autovacuum be running frequently but dead tuple count stays high?
**Type:** Systems  
**Level:** Advanced  
**Hint:** Autovacuum has cost throttling parameters (`autovacuum_vacuum_cost_delay`, `autovacuum_vacuum_cost_limit`). It can be throttled to avoid I/O impact. What happens on a write-heavy table where new dead tuples are created faster than vacuum can reclaim them?  
**Reference:** [[design-principles/advanced-design-principles]] Principle 1

---

### Q: What is logical replication and how does it differ from physical streaming replication?
**Type:** Ontology  
**Level:** Advanced  
**Hint:** Streaming replication copies WAL bytes — binary replica of all changes. Logical replication decodes WAL into row changes and can replicate specific tables, between different PostgreSQL major versions, or to non-PostgreSQL systems.  
**Reference:** [[diagrams/postgres-mental-model]]

---

### Q: What is connection pooling doing that PostgreSQL itself cannot do, and why does PgBouncer matter at scale?
**Type:** Systems  
**Level:** Advanced  
**Hint:** PostgreSQL forks a process per connection. At 10,000 connections, the overhead (memory, context switches, lock table size) becomes significant. What does PgBouncer's transaction-mode pooling do that session-mode cannot?  
**Reference:** [[diagrams/application-to-database-flow]]
