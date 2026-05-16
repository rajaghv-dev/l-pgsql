# Systems Thinking Prompts

15+ questions about how PostgreSQL components interact — how a change in one part affects the whole system.

---

## Autovacuum and Table Maintenance

### Q: What happens to a running transaction when autovacuum starts on the same table?
**Type:** Systems  
**Level:** Intermediate  
**Hint:** Autovacuum takes `ShareUpdateExclusiveLock` — it does not block SELECT, INSERT, UPDATE, or DELETE. But what cannot happen while autovacuum holds this lock? What DDL operations conflict?  
**Reference:** [[design-principles/advanced-design-principles]] Principle 1

---

### Q: A long transaction has been open for 3 hours. What is happening to autovacuum across all tables in the database during this time?
**Type:** Systems  
**Level:** Advanced  
**Hint:** MVCC requires that no live transaction's snapshot needs the old row versions. A 3-hour transaction creates an "oldest xmin" that blocks vacuum from reclaiming anything older than 3 hours across all tables, not just the tables the transaction touched.  
**Reference:** [[diagrams/transaction-mvcc-flow]]

---

### Q: You restart PostgreSQL after a crash. How does it decide what to replay from WAL?
**Type:** Systems  
**Level:** Advanced  
**Hint:** Recovery starts from the last checkpoint, not from the beginning of the WAL. What does a checkpoint record contain? How does PostgreSQL know which WAL segment to start replaying from?  
**Reference:** [[diagrams/postgres-mental-model]]

---

### Q: What happens to shared buffers when you increase `shared_buffers` without restarting PostgreSQL?
**Type:** Systems  
**Level:** Intermediate  
**Hint:** `shared_buffers` is a startup parameter — it requires a restart to take effect. What happens if you try to change it with `ALTER SYSTEM SET` without restarting? What is the current effective value?  
**Reference:** [[diagrams/postgres-mental-model]]

---

## Lock Contention

### Q: A migration script runs `ALTER TABLE orders ADD COLUMN archived bool NOT NULL DEFAULT false`. Meanwhile, 500 application requests are queued on that table. What happens?
**Type:** Systems  
**Level:** Advanced  
**Hint:** The ALTER TABLE waits for existing transactions to finish (acquires `AccessExclusiveLock`). Meanwhile, new requests queue behind the ALTER. If the ALTER takes 2 minutes, 500 requests time out. What is the cascade effect on the connection pool?  
**Reference:** [[design-principles/concurrency-design-principles]] Principle 4

---

### Q: How does a long transaction affect `pg_stat_activity` and lock waits across the cluster?
**Type:** Systems  
**Level:** Advanced  
**Hint:** A long transaction holds locks on rows it modified, blocks vacuum (raising dead tuple counts), and consumes a connection. How does this cascade if it holds a row lock that other transactions are waiting for?  
**Reference:** [[design-principles/advanced-design-principles]] Principle 1

---

### Q: What is the relationship between `max_connections`, `work_mem`, and total memory usage?
**Type:** Systems  
**Level:** Advanced  
**Hint:** Each connection is a process. Each process can allocate up to `work_mem` per sort/hash operation. A query with 3 sorts uses 3 × `work_mem`. With 100 connections each running such a query: what is the worst-case memory usage?  
**Reference:** [[diagrams/postgres-mental-model]]

---

## Query Execution

### Q: A query uses a parallel sequential scan with 4 workers. What happens if one worker finishes significantly faster than the others?
**Type:** Systems  
**Level:** Advanced  
**Hint:** Parallel sequential scan divides heap pages into chunks. Workers request chunks from a central coordinator. A fast worker can request more chunks. The query cannot return results until all workers complete. What is the implication for parallel query performance if one worker hits a heavily bloated section?  
**Reference:** [[diagrams/sql-query-lifecycle]]

---

### Q: What happens to an in-flight query when a streaming replica falls too far behind the primary?
**Type:** Systems  
**Level:** Advanced  
**Hint:** If you configured `synchronous_commit = on` with a synchronous standby, commits wait for the standby to acknowledge WAL. If the standby falls behind, primary commits block. If `synchronous_commit = off`, commits do not wait but the standby falls further behind. What is the data loss window?  
**Reference:** [[diagrams/postgres-mental-model]]

---

### Q: How does `statement_timeout` interact with a long-running query that is in the middle of writing data?
**Type:** Systems  
**Level:** Intermediate  
**Hint:** `statement_timeout` cancels the query — which triggers a rollback of the current transaction (if any). What happens to the rows that were already modified before the timeout? Does `statement_timeout` fire mid-UPDATE on a large table?  
**Reference:** [[design-principles/concurrency-design-principles]] Principle 6

---

### Q: A query is using a hash join that spills to disk (hash table exceeds `work_mem`). How does this appear in EXPLAIN ANALYZE?
**Type:** Systems  
**Level:** Advanced  
**Hint:** Look for "Batches: N" in the Hash node — if N > 1, the hash spilled to disk. What is the I/O cost? How do you fix it: increase `work_mem`, or rewrite the query to reduce the hash table size?  
**Reference:** [[diagrams/sql-query-lifecycle]]

---

## Replication and HA

### Q: You promote a standby to primary. What happens to connections that were pointed at the old primary?
**Type:** Systems  
**Level:** Advanced  
**Hint:** The old primary (if still running in standalone mode) will have connections that see a diverged timeline. The new primary has a new timeline ID. How do you handle in-flight transactions on the old primary that were not yet replicated?  
**Reference:** [[diagrams/postgres-mental-model]]

---

### Q: A checkpoint takes longer than `checkpoint_timeout`. What is the cascade effect?
**Type:** Systems  
**Level:** Advanced  
**Hint:** If a checkpoint cannot complete in `checkpoint_timeout`, the next checkpoint starts immediately. If writes are heavy, checkpoints overlap. What is the impact on WAL accumulation, disk I/O patterns, and recovery time objective (RTO) after a crash?  
**Reference:** [[diagrams/postgres-mental-model]]

---

## Connection Pooling

### Q: A connection pool is set to 100 connections, all active. A new request arrives. What happens?
**Type:** Systems  
**Level:** Intermediate  
**Hint:** The request waits in the pool's queue for an available connection. What happens if the wait exceeds the pool's connection timeout? What is the cascade if this happens for 500 requests simultaneously?  
**Reference:** [[diagrams/application-to-database-flow]]

---

### Q: PgBouncer is in transaction-mode pooling. A client sends `SET session_setting = 'value'`. Is the setting preserved for the next query?
**Type:** Systems  
**Level:** Advanced  
**Hint:** In transaction mode, each transaction may use a different backend connection. Session-level settings are not shared between connections. How do you handle `SET LOCAL` vs `SET` in this mode? What does this mean for `app.tenant_id` set via `SET`?  
**Reference:** [[design-principles/mcp-tool-design-principles]] Principle 3
