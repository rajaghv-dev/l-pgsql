# Partitioning for Large Data

Level: Advanced

## One-line intuition
Partitioning splits a logical table into physical sub-tables, enabling PostgreSQL to skip entire partitions for queries, drop old data in O(1) time, and parallelize operations — but it adds complexity that only pays off when tables exceed tens of millions of rows.

## Why this exists
A 10-billion-row table with a query for last week's data will do a sequential scan or suffer heavy index I/O unless you can structurally limit what PostgreSQL touches. Partitioning is the structural limit: the planner prunes entire child tables when their partition key cannot match the query predicate. Partition detach/drop for old data is also instant — no VACUUM needed, no dead tuples, just a metadata change.

## First-principles explanation

### Declarative partitioning (PostgreSQL 10+)
```sql
-- blocked: Docker not accessible
-- Range partitioning by date
CREATE TABLE events (
    id bigserial,
    created_at timestamptz NOT NULL,
    user_id bigint,
    event_type text,
    payload jsonb
) PARTITION BY RANGE (created_at);

-- Create partitions
CREATE TABLE events_2024_q1 PARTITION OF events
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

CREATE TABLE events_2024_q2 PARTITION OF events
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

-- Default partition catches out-of-range inserts
CREATE TABLE events_default PARTITION OF events DEFAULT;
```

### Partition types

**RANGE**: ordered split on a column or column list. Best for time-series, sequence IDs.
```sql
-- blocked: Docker not accessible
PARTITION BY RANGE (created_at)
PARTITION BY RANGE (year, month)  -- multi-column range
```

**LIST**: explicit value enumeration. Best for categorical data (region, status).
```sql
-- blocked: Docker not accessible
PARTITION BY LIST (region)
-- CREATE TABLE events_us PARTITION OF events FOR VALUES IN ('US', 'CA');
```

**HASH**: even distribution by hash. Best for load distribution without natural range/list key.
```sql
-- blocked: Docker not accessible
PARTITION BY HASH (user_id)
-- CREATE TABLE events_0 PARTITION OF events FOR VALUES WITH (modulus 4, remainder 0);
```

### Partition pruning
The planner eliminates partitions whose bounds cannot satisfy the query predicate:
```sql
-- blocked: Docker not accessible
-- Only events_2024_q1 is accessed — all other partitions pruned
EXPLAIN SELECT * FROM events WHERE created_at = '2024-02-15';
```

Pruning requires the WHERE clause to use the partition key column directly. Wrapping in a function (`date_trunc('month', created_at)`) prevents pruning (the planner cannot reason about it). Exceptions: `to_char`, `extract` — planner can sometimes push these.

**Runtime pruning** (PG 12+): When partition keys depend on parameters (`WHERE created_at = $1`), pruning happens at execution time, not planning time. Visible in EXPLAIN as `Subplans Removed`.

### Partitioned indexes
Each partition has its own physical indexes:
```sql
-- blocked: Docker not accessible
-- Creates an index on all existing and future partitions
CREATE INDEX ON events (user_id);

-- Partition-local unique constraints (must include the partition key)
CREATE UNIQUE INDEX ON events (id, created_at);
```

Global unique indexes across all partitions are not supported. Unique constraints must include the partition key — a significant schema constraint.

### DEFAULT partition
Catches rows not matching any explicit partition bound. Essential safety net. To add a new partition:
1. Create the new partition
2. Move rows from DEFAULT to new partition: `INSERT INTO events_new SELECT * FROM events_default WHERE ...`
3. `DELETE FROM events_default WHERE ...`

Or more safely: detach DEFAULT, create new partition, attach modified DEFAULT.

### Data retention with partitioning
```sql
-- blocked: Docker not accessible
-- Drop an entire quarter of data instantly — no VACUUM needed
ALTER TABLE events DETACH PARTITION events_2022_q1;
DROP TABLE events_2022_q1;

-- Or: detach without dropping (archive)
ALTER TABLE events DETACH PARTITION events_2022_q1 CONCURRENTLY;
```

`DETACH PARTITION CONCURRENTLY` (PG 14+) detaches without taking AccessExclusiveLock on the parent.

### pg_partman
An extension (not available in this environment, but widely used) that automates partition creation and maintenance:
- Automatically creates future partitions on a schedule
- Drops or archives old partitions based on retention policy
- Supports time-based and serial-based partitioning

Without pg_partman, you need a cron job or application logic to create partitions before they're needed.

### When partitioning helps
- Tables > 50-100M rows with time-based or categorical queries
- Data retention requirements (drop old partitions instantly)
- Bulk loading to specific partitions
- Parallel query across partitions (PG can parallelize across partition workers)

### When partitioning hurts
- Tables < 10M rows: overhead exceeds benefit (planner overhead, join complexity)
- Heavy cross-partition joins (JOINs across many partitions lose pruning benefit)
- No natural partition key: hash partitioning reduces pruning effectiveness
- Unique constraints requiring cross-partition uniqueness (impossible without partition key in UNIQUE)

## Micro-concepts
- **partition key**: the column(s) used to route rows to partitions. Cannot be updated to cross a partition boundary (requires DELETE + INSERT).
- **partition pruning**: planner eliminates irrelevant partitions. Requires partition key in WHERE clause.
- **inheritance-based partitioning** (legacy pre-PG10): using `INHERITS` and `CHECK` constraints. Inferior to declarative; avoid in new schemas.
- **sub-partitioning**: a partition can itself be partitioned. `events_2024_q1` can be partitioned by `user_id`. Adds complexity exponentially.
- **attach partition**: `ALTER TABLE events ATTACH PARTITION events_2024_q3 FOR VALUES FROM ('2024-07-01') TO ('2024-10-01');` — validates existing data (can be slow on large tables; use `VALIDATE CONSTRAINT` pattern).
- **ONLY keyword**: `SELECT ... FROM ONLY events` — queries only the parent table, not partitions. Useful for metadata queries.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Partitioning splits a big table into smaller physical tables. Queries on one partition are faster.

**Intermediate view**: Range partitioning by time is the most common pattern. Add a DEFAULT partition as a safety net. Drop old partitions for instant data retention.

**Advanced view**: Partition pruning is fragile — any predicate transformation that obscures the partition key breaks it. Cross-partition joins require the planner to enumerate all partition combinations. Unique constraints cannot span partitions without the partition key. Partition maintenance (creating future partitions) requires automation (pg_partman or cron). At extreme scale (10,000+ partitions), planner planning time itself becomes a bottleneck. For truly massive datasets (petabytes), partitioning is a prerequisite — but not a complete solution without also tuning autovacuum per-partition and monitoring partition-level bloat individually.

## Mental model
Partitioning is like filing cabinets for a massive document archive. Each filing cabinet (partition) covers a date range. When you ask for documents from March 2024, the clerk (planner) only opens the March 2024 cabinet — ignoring all others. Shredding old documents means just removing the whole cabinet for that month (DROP PARTITION), not hunting through thousands of drawers.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_partitioned_table`, `pg_inherits`, `information_schema.partitions`.

**SQL view**:
```sql
-- blocked: Docker not accessible
-- List all partitions and their bounds
SELECT parent.relname AS parent, child.relname AS partition,
       pg_get_expr(child.relpartbound, child.oid) AS bounds,
       pg_size_pretty(pg_total_relation_size(child.oid)) AS size
FROM pg_inherits
JOIN pg_class parent ON parent.oid = pg_inherits.inhparent
JOIN pg_class child ON child.oid = pg_inherits.inhrelid
WHERE parent.relname = 'events'
ORDER BY child.relname;

-- Check if partition pruning is working
EXPLAIN (ANALYZE, VERBOSE) SELECT * FROM events WHERE created_at >= '2024-01-01';
```

**Non-SQL / hybrid view**: pg_partman GitHub: https://github.com/pgpartman/pg_partman. Time-based partition creation is typically managed via a cron job calling `partman.run_maintenance()`.

## Design principle
**Partition for operations, not just queries**: The primary benefits of partitioning are operational — instant data deletion, bounded VACUUM scope, and parallelism. Query performance improvement from pruning is secondary. Choose the partition key based on your operational needs (time-based retention, geographic sharding) first.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: Partitioning adds planner complexity. With 100 partitions, the planner must evaluate potential pruning for all 100 before any pruning happens. Planning time scales with partition count. At 10,000 partitions, planning time can reach hundreds of milliseconds per query. This defeats the purpose for short OLTP queries. Rule: < 1000 partitions total for OLTP workloads.

**Creative**: Combine partitioning with tablespaces to tier storage. Hot recent partitions on NVMe, cold historical partitions on cheaper SSD or HDD. PostgreSQL tablespaces let you move a partition to a different storage location with `ALTER TABLE partition SET TABLESPACE slow_storage`.

**Systems**: Autovacuum operates per partition independently. A table with 365 daily partitions may have 365 concurrent autovacuum workers scheduled — but only `autovacuum_max_workers` (default 3) can run at once. Plan partition granularity to keep total partition count manageable for autovacuum scheduling.

## MCP and agent perspective
AI agent event logs are a natural fit for time-based partitioning: monthly or weekly partitions, with old partitions dropped after retention period. Use a DEFAULT partition as a safety net for unexpected timestamps. Create the next month's partition before the month starts (cron or application startup check). The agent memory semantic store (embeddings) is typically small enough that partitioning is not needed unless you are storing millions of embeddings per agent instance.

## Ontology perspective
Partitioning is a form of pre-committed categorization — you decide in advance how data will be grouped, and the storage system enforces that grouping physically. This contrasts with indexes (post-hoc organization for retrieval) and views (logical reorganization without physical change). Partition keys are ontological commitments: they define the primary axis by which data is organized in reality (time, geography, tenant). Changing a partition key is a major schema migration — choose it carefully.

## Practice session

**Exercise 1 — Create a partitioned table**: Time-based range partitioning.
```sql
-- blocked: Docker not accessible
CREATE TABLE log_entries (
    id bigserial,
    ts timestamptz NOT NULL DEFAULT now(),
    level text,
    message text
) PARTITION BY RANGE (ts);

CREATE TABLE log_entries_2024_01 PARTITION OF log_entries
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE log_entries_default PARTITION OF log_entries DEFAULT;
```

**Exercise 2 — Verify pruning**: Confirm irrelevant partitions are excluded.
```sql
-- blocked: Docker not accessible
EXPLAIN SELECT * FROM log_entries WHERE ts >= '2024-01-01' AND ts < '2024-02-01';
-- Should show only log_entries_2024_01 in the plan
```

**Exercise 3 — Instant data deletion**: Drop an old partition.
```sql
-- blocked: Docker not accessible
ALTER TABLE log_entries DETACH PARTITION log_entries_2024_01;
DROP TABLE log_entries_2024_01;
```

**Exercise 4 — List partitions**: Inspect partition metadata.
```sql
-- blocked: Docker not accessible
SELECT child.relname, pg_get_expr(child.relpartbound, child.oid) AS bounds
FROM pg_inherits
JOIN pg_class child ON child.oid = pg_inherits.inhrelid
JOIN pg_class parent ON parent.oid = pg_inherits.inhparent
WHERE parent.relname = 'log_entries';
```

**Exercise 5 — Hash partitioning**: Distribute by user_id.
```sql
-- blocked: Docker not accessible
CREATE TABLE user_actions (
    id bigserial,
    user_id bigint NOT NULL,
    action text
) PARTITION BY HASH (user_id);

CREATE TABLE user_actions_0 PARTITION OF user_actions FOR VALUES WITH (modulus 4, remainder 0);
CREATE TABLE user_actions_1 PARTITION OF user_actions FOR VALUES WITH (modulus 4, remainder 1);
CREATE TABLE user_actions_2 PARTITION OF user_actions FOR VALUES WITH (modulus 4, remainder 2);
CREATE TABLE user_actions_3 PARTITION OF user_actions FOR VALUES WITH (modulus 4, remainder 3);
```

## References
- PostgreSQL Documentation: [Table Partitioning](https://www.postgresql.org/docs/16/ddl-partitioning.html)
- PostgreSQL Documentation: [Partition Pruning](https://www.postgresql.org/docs/16/ddl-partitioning.html#DDL-PARTITION-PRUNING)
- pg_partman: https://github.com/pgpartman/pg_partman
- Álvaro Herrera: [Partitioning in PostgreSQL 10](https://www.2ndquadrant.com/en/blog/partitioning-improvement-postgresql-10/)
- Hironobu Suzuki: [The Internals of PostgreSQL, Chapter 10 — Base Backup and Point-in-Time Recovery](https://www.interdb.jp/pg/)
