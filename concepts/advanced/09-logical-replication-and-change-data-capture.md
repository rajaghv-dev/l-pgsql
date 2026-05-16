# Logical Replication and Change Data Capture

Level: Advanced

## One-line intuition
Logical replication decodes PostgreSQL's WAL into a stream of row-level change events — enabling selective table replication, zero-downtime migrations, and event-driven architectures without external change-data-capture agents.

## Why this exists
Physical (streaming) replication copies byte-for-byte WAL to a replica — the replica must be an identical PostgreSQL version and cannot be used for selective replication or cross-version upgrades. Logical replication decodes WAL into row-level INSERTs, UPDATEs, and DELETEs, enabling: subscribing to only specific tables, replicating to different PostgreSQL versions, feeding data pipelines (Kafka, Debezium), and building event sourcing architectures entirely within PostgreSQL.

## First-principles explanation

### WAL logical decoding
WAL stores physical changes: "at offset X in block Y of file Z, write these bytes." Logical decoding translates those physical changes into logical row events: "table `orders`, INSERT, row {id=42, status='pending', amount=100}."

The decoding layer uses:
- **replication slot**: a named cursor in the WAL stream. The server retains WAL until the slot consumer acknowledges it.
- **output plugin**: a library that formats decoded changes (built-in: `pgoutput` for logical replication; external: `wal2json`, `decoderbufs` for CDC tools).

### Publication / Subscription model

**Publisher side** (source database):
```sql
-- blocked: Docker not accessible
-- Publish specific tables
CREATE PUBLICATION orders_pub FOR TABLE orders, order_items;

-- Publish all tables
CREATE PUBLICATION all_tables_pub FOR ALL TABLES;

-- Publish with row filter (PG 15+)
CREATE PUBLICATION active_orders_pub FOR TABLE orders WHERE (status != 'archived');

-- Publish only specific columns (PG 16+)
CREATE PUBLICATION orders_summary_pub FOR TABLE orders (id, status, total_amount);
```

**Subscriber side** (target database):
```sql
-- blocked: Docker not accessible
CREATE SUBSCRIPTION orders_sub
CONNECTION 'host=source_db dbname=source_db user=replication_user password=xxx'
PUBLICATION orders_pub;
```

The subscription:
1. Takes an initial snapshot (COPY) of the published tables
2. Switches to streaming logical changes from the replication slot
3. Applies changes in order within each transaction

### Replication slots
```sql
-- blocked: Docker not accessible
-- List replication slots
SELECT slot_name, plugin, active, restart_lsn, confirmed_flush_lsn,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS lag_bytes
FROM pg_replication_slots;
```

**Critical risk**: An inactive replication slot (subscriber disconnected) causes WAL to accumulate on the publisher indefinitely. If the subscriber is down for hours/days, the publisher can run out of disk space. Always monitor slot lag. Drop unused slots immediately.

```sql
-- blocked: Docker not accessible
-- Drop an unused slot (emergency disk space recovery)
SELECT pg_drop_replication_slot('slot_name');
```

### CDC — Change Data Capture patterns

**Pattern 1: Direct logical replication** (PostgreSQL → PostgreSQL)
- Built-in, no external tools
- Limited to PostgreSQL → PostgreSQL
- No transformation, minimal filtering (PG 15+ adds row filters)

**Pattern 2: Debezium via wal2json/pgoutput**
- Debezium (Java) connects as a logical replication client
- Publishes change events to Kafka, with full schema metadata
- Enables fan-out to multiple consumers (ElasticSearch, data warehouse, other DBs)

**Pattern 3: pg_logical_emit_message**
```sql
-- blocked: Docker not accessible
-- Emit custom messages into the WAL stream
-- Useful for marking business events in the change stream
SELECT pg_logical_emit_message(false, 'order_fulfillment', '{"order_id": 42, "event": "shipped"}');
-- transactional: if true, message is part of the enclosing transaction
```

**Pattern 4: Trigger-based CDC** (legacy, avoid for high-volume tables)
- Triggers write changes to a `changes` table
- No WAL dependency
- High write overhead; simpler but less reliable

### Logical replication requirements
- `wal_level = logical` on the publisher (requires restart if changing from `replica`)
- `max_replication_slots >= 1` on publisher
- `max_wal_senders >= 1` on publisher
- User with `REPLICATION` privilege on publisher
- Tables must have `REPLICA IDENTITY` set:
  - `FULL`: writes old row values to WAL for UPDATE/DELETE (needed for tables without PK)
  - `DEFAULT`: uses primary key (default for tables with PK)
  - `NOTHING`: no identity — UPDATE/DELETE not replicatable

```sql
-- blocked: Docker not accessible
ALTER TABLE orders REPLICA IDENTITY FULL;  -- for tables without PK
```

### Logical replication for major version upgrades
The standard zero-downtime upgrade path:
1. Set up logical replication from old version → new version PostgreSQL
2. Let new version catch up (lag approaches zero)
3. Stop writes to old version briefly
4. Allow new version to fully catch up
5. Switch application to new version
6. Drop subscription and old cluster

This enables upgrades with < 1 minute downtime even for multi-TB databases.

### Conflict handling
Logical replication applies changes as a subscriber, running as a regular PostgreSQL session. Conflicts occur when:
- INSERT violates a unique constraint (a row already exists)
- UPDATE/DELETE references a row that doesn't exist

Resolution options:
- `disable subscription` (stop; manual resolution)
- Skip the conflicting transaction: `SELECT pg_replication_origin_advance('...', '<lsn>');`
- Use `synchronize_seqscans` or replication origin for idempotent replay

## Micro-concepts
- **LSN**: Log Sequence Number — the WAL byte offset. Uniquely identifies a point in the WAL stream.
- **confirmed_flush_lsn**: the LSN the subscriber has acknowledged. WAL before this can be freed.
- **restart_lsn**: the WAL position the server must retain for this slot.
- **wal_level = logical**: requires `wal_level = logical` (not `replica` or `minimal`). Check: `SHOW wal_level;`
- **pgoutput**: the built-in output plugin for logical replication (used by native subscriptions).
- **wal2json**: external plugin that outputs changes as JSON. Used by Debezium and many CDC tools.
- **replication origin**: tracks the origin of changes for loop prevention in bidirectional replication.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Logical replication copies specific tables from one PostgreSQL server to another. Changes are streamed in real-time.

**Intermediate view**: Set up publication/subscription for selective table replication. Monitor replication slot lag. Use for major version upgrades. Be careful with inactive slots — they accumulate WAL.

**Advanced view**: Logical replication is a WAL consumer that runs as a separate process on the publisher. The replication slot is a promise from the publisher to retain WAL until the subscriber acknowledges. An inactive slot is therefore a potential disk-filling bomb. Column filters (PG 16) and row filters (PG 15) enable fine-grained publication without external transformation. `pg_logical_emit_message` allows embedding business events in the WAL stream, creating an audit/event log that is transactionally consistent with the data changes that produced it.

## Mental model
Logical replication is a stenographer listening to all database changes and transcribing them into a ledger that other systems can read. The publication says which chapters of the book the stenographer covers. The subscription is a subscriber reading those chapters on another system. The replication slot is a bookmark — the publisher can't shred pages until all subscribers have read past them. If the subscriber disappears, pages pile up indefinitely.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_publication`, `pg_subscription`, `pg_replication_slots`, `pg_stat_replication`, `pg_stat_subscription`.

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Publication status
SELECT pubname, puballtables, pubinsert, pubupdate, pubdelete FROM pg_publication;

-- Subscription status
SELECT subname, subenabled, subpublications, subslotname FROM pg_subscription;

-- Replication lag monitoring
SELECT slot_name, active,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots;

-- Subscriber apply lag
SELECT subname, received_lsn, latest_end_lsn,
       extract(epoch FROM (now() - last_msg_send_time)) AS lag_seconds
FROM pg_stat_subscription;
```

**Non-SQL / hybrid view**: Debezium (https://debezium.io/) is the standard CDC bridge between PostgreSQL logical replication and Kafka. Benthos/Redpanda, AWS DMS, and Airbyte also support logical replication as a source. Monitor `pg_replication_slots.lag_bytes` in Prometheus for slot health.

## Design principle
**WAL is the source of truth for events**: In an event-driven architecture, logical replication makes the WAL an event bus. Every database change is already an event — logical decoding just surfaces it. This eliminates the dual-write problem (writing to both the database and an event queue) by deriving events from the database write, not alongside it.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: Logical replication does not replicate DDL changes (ALTER TABLE, CREATE INDEX, etc.). If you add a column on the publisher, the subscriber errors out until you manually add the column there too. Schema changes require careful coordination: add column to subscriber first, then publisher, in the right order.

**Creative**: Use logical replication and `pg_logical_emit_message` to build a transactional outbox without a separate outbox table. Emit business events as WAL messages within the same transaction that modifies data. A Debezium consumer reads both the data change and the message, publishing both atomically.

**Systems**: Logical replication throughput is bounded by the subscriber's apply rate, which is single-threaded by default (one apply worker per subscription). PG 16 introduced parallel apply (`max_parallel_apply_workers_per_subscription`). For high-volume publishers, this can be a bottleneck — the subscriber's apply falls behind, the slot accumulates WAL, and publisher disk fills. Design for this: monitor slot lag, set `max_slot_wal_keep_size` to bound WAL retention (slot is invalidated if exceeded, but disk is saved), and partition large tables to enable parallel apply per partition.

## MCP and agent perspective
For AI agent event sourcing: use logical replication to stream agent actions from the primary to an analytics database where they can be queried without impacting the OLTP primary. Agent memory writes (episodic events) are typically high-volume; logical replication allows the analytics store to be populated asynchronously. The `pg_logical_emit_message` pattern can embed agent reasoning traces as WAL-level events, providing an audit trail that is physically tied to the data changes that caused them.

## Ontology perspective
Logical replication operationalizes the event sourcing pattern at the infrastructure level: every state change (INSERT/UPDATE/DELETE) is surfaced as a named event with before/after values. This shifts the ontology from "current state" (what the database looks like now) to "event history" (what happened and in what order). The WAL LSN is the universal timestamp for all events in this model — a global causal clock for the entire database.

## Practice session

**Exercise 1 — Check WAL level**: Verify replication is possible.
```sql
-- blocked: Docker not accessible
SHOW wal_level;
-- Should be 'logical' for CDC. 'replica' allows physical only.
```

**Exercise 2 — Create a publication**: Publish specific tables.
```sql
-- blocked: Docker not accessible
CREATE PUBLICATION my_pub FOR TABLE orders, customers;
SELECT * FROM pg_publication;
SELECT * FROM pg_publication_tables WHERE pubname = 'my_pub';
```

**Exercise 3 — Inspect replication slots**: Monitor lag.
```sql
-- blocked: Docker not accessible
SELECT slot_name, plugin, active, restart_lsn,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS lag
FROM pg_replication_slots;
```

**Exercise 4 — Emit a logical message**: Custom event in WAL.
```sql
-- blocked: Docker not accessible
BEGIN;
UPDATE orders SET status = 'shipped' WHERE id = 1;
SELECT pg_logical_emit_message(true, 'audit', '{"action":"ship","order_id":1}');
COMMIT;
```

**Exercise 5 — REPLICA IDENTITY**: Check and set for tables without PK.
```sql
-- blocked: Docker not accessible
SELECT relname, relreplident FROM pg_class WHERE relname = 'orders';
-- 'd' = default (PK), 'f' = full, 'n' = nothing, 'i' = specific index
ALTER TABLE orders REPLICA IDENTITY FULL;
```

## References
- PostgreSQL Documentation: [Logical Replication](https://www.postgresql.org/docs/16/logical-replication.html)
- PostgreSQL Documentation: [pg_logical_emit_message](https://www.postgresql.org/docs/16/functions-admin.html#FUNCTIONS-REPLICATION)
- PostgreSQL Documentation: [Replication Slots](https://www.postgresql.org/docs/16/warm-standby.html#STREAMING-REPLICATION-SLOTS)
- Debezium PostgreSQL Connector: https://debezium.io/documentation/reference/stable/connectors/postgresql.html
- Álvaro Herrera: [Logical Replication in PostgreSQL 10](https://www.2ndquadrant.com/en/blog/logical-replication-postgresql-10/)
- wal2json: https://github.com/eulerto/wal2json
