# When NOT to Use PostgreSQL

Level: Advanced

## One-line intuition
PostgreSQL's honest limits are real and specific — knowing them prevents you from building systems that work in development and fail in production at scale.

## Why this exists
PostgreSQL advocacy can become PostgreSQL dogma. Advanced practitioners owe themselves and their teams an honest accounting of where PostgreSQL's architecture creates hard limits that cannot be optimized away. Some workloads genuinely require specialized systems, and using PostgreSQL for those workloads creates compounding technical debt.

## First-principles explanation

### PostgreSQL's structural limits
PostgreSQL's architecture creates unavoidable constraints:

**Row-store storage**: All columns of a row are stored together. OLAP queries that access 3 of 50 columns must read all 50 — 94% wasted IO. Column-store systems skip irrelevant columns entirely.

**MVCC dead tuple tax**: Every UPDATE creates a new row version. Every DELETE marks a row dead. Dead rows accumulate until VACUUM removes them. At > 500K writes/second, vacuum cannot keep up — bloat accumulates unboundedly.

**Single-leader write model**: All writes go to one primary. Replicas are read-only. Cross-region writes require routing to the primary — adding 50-150ms of network latency for users in distant regions.

**Process-per-connection**: Each connection is an OS process (~5-10MB RAM). At 10,000 connections, this is 50-100GB of RAM just for process metadata. Connection pooling helps but has its own limits.

**WAL-first writes**: Every write goes to WAL before the data file. WAL is sequential, but it adds latency. At extreme throughput, WAL write rate becomes the bottleneck.

### Hard limits — when PostgreSQL structurally fails

#### 1. IoT telemetry at 1M+ writes/second sustained
**Why PostgreSQL fails**: MVCC write amplification + vacuum lag + WAL throughput bottleneck. At 1M rows/second, WAL generates ~1GB/s continuously. Dead tuple accumulation from any UPDATEs or DELETEs overwhelms vacuum workers. Even with TimescaleDB (which helps significantly with its columnar compression and automatic partitioning), pure PostgreSQL/TimescaleDB hits a wall around 200-500K writes/second on reasonable hardware.

**Real ceiling**: ~100-200K inserts/second for simple time-series with no indexes, on high-end NVMe hardware.

**Use instead**: InfluxDB, QuestDB, Apache Druid (each engineered for this specific write pattern).

#### 2. Global active-active multi-region writes
**Why PostgreSQL fails**: The single-leader model cannot provide low-latency writes from multiple regions. A write from Tokyo to a US primary has ~150ms RTT before returning. BDR (Bi-Directional Replication, commercial extension) adds multi-master but requires application-level conflict resolution — which is error-prone and complex.

**Real ceiling**: Single-region write latency ≤ 5ms. Cross-region writes always pay the speed-of-light tax.

**Use instead**: CockroachDB (PostgreSQL-compatible, distributed consensus), Cassandra (eventually consistent, extremely write-scalable), DynamoDB (global tables with last-writer-wins).

**Important caveat**: Many "global active-active" requirements are actually "users in multiple regions need fast reads" — solvable with PostgreSQL read replicas per region. True multi-region write requirements are rarer than assumed.

#### 3. Pure OLAP at petabyte scale with sub-second latency
**Why PostgreSQL fails**: Row-store access pattern for analytical queries reads 10-50x more data than necessary. PostgreSQL's query planner is optimized for OLTP not OLAP execution plans. No vectorized execution. No late materialization. Aggregation on 100M+ rows takes seconds to minutes.

**Real ceiling**: Analytical queries on > 100M rows with sub-second latency requirements.

**Use instead**: ClickHouse (OLAP-optimized column store, sub-second on billions of rows), DuckDB (in-process OLAP for development/moderate scale), BigQuery/Redshift (managed column store at petabyte scale).

**Important caveat**: PostgreSQL with parallel query and partition pruning handles analytical workloads well at 10-50M rows. The ceiling is higher than many assume.

#### 4. Pure graph algorithm workloads
**Why PostgreSQL fails**: Graph traversal in SQL is recursive CTE + JOIN chain. Each hop is a new JOIN operation — O(edges) per hop. Multi-hop traversals (shortest path, PageRank, community detection) on graphs with millions of edges are impractical in SQL.

**Real ceiling**: Reliable graph traversal with < 100ms latency up to ~4-5 hops, for simple traversal patterns. Complex graph algorithms (PageRank) are not tractable in PostgreSQL at scale.

**Use instead**: Neo4j (native graph storage, O(1) edge traversal, Cypher query language), Memgraph (in-memory graph database), Amazon Neptune.

**Important caveat**: PostgreSQL with ltree extension (installed in this environment) handles hierarchical tree structures well (categories, organizational charts). The limit is specifically for dense, non-hierarchical graph traversal.

#### 5. Real-time pub/sub at scale
**Why PostgreSQL fails**: LISTEN/NOTIFY delivers messages only to connected clients, has no message persistence, no consumer groups, no backpressure, no replay. It is a notification mechanism, not a message queue.

**Real ceiling**: LISTEN/NOTIFY works for simple "something changed" notifications (< 1000/second). It cannot replace Kafka's replayable, persistent, exactly-once delivery.

**Use instead**: Kafka, Pulsar, NATS (for high-throughput event streaming); Redis Pub/Sub (for ephemeral notifications at moderate scale).

### What PostgreSQL handles better than commonly believed

| Capability | Common misconception | Reality |
|---|---|---|
| Vector search | "Need a vector DB" | pgvector + HNSW is production-ready for < 10M vectors |
| Full-text search | "Need Elasticsearch" | tsvector + GIN + ts_rank covers 80% of FTS needs |
| Time-series | "Need InfluxDB" | Partitioning + BRIN handles < 100K inserts/minute |
| JSON documents | "Need MongoDB" | JSONB + GIN covers most MongoDB use cases with ACID |
| Job queues | "Need Redis/Celery" | SKIP LOCKED pattern handles millions of jobs/day |
| Caching | "Need Redis" | shared_buffers + pg_prewarm can serve many cache needs |

## Micro-concepts
- **Write amplification**: N indexes × 1 insert = N+1 writes + WAL. At high insert rates, this is the primary bottleneck.
- **MVCC tax**: no in-place updates. Every UPDATE is a delete-insert pair. Vacuum is the garbage collector for the deleted half.
- **Speed-of-light constraint**: no database system can deliver sub-RTT multi-region writes. This is physics, not PostgreSQL's fault.
- **WAL throughput**: at very high write rates, WAL write speed is the bottleneck. On NVMe, WAL can sustain ~2-5 GB/s. Above that, writes queue.
- **Single-leader PITR**: in a cluster with streaming replication, all replicas replay from the same primary WAL. A single point of failure for write durability.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Use PostgreSQL unless you have a specific, measured reason not to. Most "we need Redis/Kafka/Elasticsearch" decisions are premature optimization.

**Intermediate view**: Validate each requirement before adding a specialized system. Measure your actual throughput, latency, and query patterns against PostgreSQL's real behavior — not theoretical limits.

**Advanced view**: PostgreSQL's limits are structural — they cannot be resolved by tuning, indexing, or hardware upgrades alone. Row-store OLAP inefficiency, MVCC dead tuple accumulation, single-leader write throughput, and LISTEN/NOTIFY limitations are architectural properties, not bugs. The decision to use a specialized system is made when the workload structurally requires a different architecture — not when PostgreSQL underperforms due to misuse.

## Mental model
PostgreSQL is a city center: dense, well-connected, handles enormous variety of activity. Some things belong outside the city center: the distribution warehouse (ClickHouse for OLAP), the global shipping network (Cassandra for global writes), the dedicated communication tower (Kafka for event streaming). The city center can simulate some of these — you can store packages in a downtown office — but only up to a point. Know the city's limits.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_stat_bgwriter` (checkpoint pressure), `pg_stat_wal` (WAL generation rate), `pg_stat_user_tables` (vacuum health) — these show when you're approaching PostgreSQL's limits.

**SQL view**:
```sql
-- blocked: Docker not accessible
-- WAL generation rate (approaching limit if > 1-2 GB/min)
SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) AS total_wal_generated;

-- Vacuum lag (approaching limit if n_dead_tup grows faster than it shrinks)
SELECT relname, n_dead_tup, n_live_tup, last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 10;

-- Connection count approaching limit
SELECT count(*), max_conn FROM pg_stat_activity, (SELECT setting::int AS max_conn FROM pg_settings WHERE name = 'max_connections') s
GROUP BY max_conn;
```

**Non-SQL / hybrid view**: Load testing tools: pgbench (PostgreSQL-specific), sysbench, HammerDB. These measure actual PostgreSQL throughput against your specific workload to find the ceiling empirically.

## Design principle
**Measure the ceiling empirically before declaring PostgreSQL insufficient**: run pgbench or a realistic load test, observe `pg_stat_statements` and system IO, and identify the actual bottleneck. The bottleneck is often a missing index, a misconfigured autovacuum, or a poorly written query — not PostgreSQL's architectural limits. Only when the empirical ceiling is reached is a specialized system justified.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: "We'll need Kafka/Redis/ClickHouse eventually" is not a reason to add it today. Systems that are added prematurely impose operational overhead and data synchronization complexity before the performance benefit is needed. The engineering cost of premature specialization is paid immediately; the performance benefit may never materialize.

**Creative**: For workloads approaching PostgreSQL's limits, consider the "PostgreSQL + extension" path before a separate system: TimescaleDB for time-series, pgvector for vectors, Citus for horizontal sharding, pg_partman for partition management. Each extends PostgreSQL's ceiling without adding a new system to operate.

**Systems**: Every specialized system added alongside PostgreSQL creates three new failure modes: (1) data synchronization failure (the two systems drift apart), (2) partial failure (data written to PostgreSQL but not yet to the specialized system), (3) split-brain (the two systems have inconsistent state). Each failure mode requires detection logic, alerting, and recovery procedures — multiplied across every specialized system in your architecture.

## MCP and agent perspective
For AI agent infrastructure, PostgreSQL's generality is a feature: one system means one audit log, one permission model, one backup strategy, one connection pool, one monitoring setup. Prefer `PostgreSQL + extensions` over a multi-system architecture for agent memory. The specific case where a specialized system is justified for agents: > 10M embeddings (consider Qdrant or Weaviate), or > 100K agent events/second (consider InfluxDB for the event log, PostgreSQL for structured state).

## Ontology perspective
The decision "when not to use PostgreSQL" is an ontological decision: what is the fundamental nature of this data? PostgreSQL's relational ontology (entities, relationships, transactions) is the most general. When data is fundamentally temporal (time-series), fundamentally connected (graph), or fundamentally immutable-analytical (OLAP), a specialized ontology may provide a more natural — and more performant — representation. Choosing the wrong ontology is not a configuration problem; it is an architectural mismatch.

## Practice session

**Exercise 1 — Measure write throughput ceiling**: Use pgbench for baseline.
```bash
# Shell (blocked: Docker not accessible)
# pgbench -c 10 -j 2 -T 60 -U cfp cfp
# Records: TPS (transactions per second) — PostgreSQL's actual OLTP ceiling on this hardware
```

**Exercise 2 — WAL generation rate**: Is write rate approaching WAL limits?
```sql
-- blocked: Docker not accessible
SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0'::pg_lsn)) AS wal_generated;
-- Wait 60s, then measure again:
-- WAL generated / 60 = WAL bytes per second
```

**Exercise 3 — Vacuum health check**: Is dead tuple accumulation under control?
```sql
-- blocked: Docker not accessible
SELECT relname,
       n_dead_tup,
       round(n_dead_tup::numeric / nullif(n_live_tup + n_dead_tup, 0) * 100, 1) AS dead_pct,
       last_autovacuum
FROM pg_stat_user_tables
WHERE n_live_tup > 1000
ORDER BY dead_pct DESC NULLS LAST;
-- dead_pct > 20% consistently = autovacuum can't keep up with write rate
```

**Exercise 4 — Connection saturation**: How close to max_connections?
```sql
-- blocked: Docker not accessible
SELECT count(*) AS active, (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') AS max,
       round(count(*)::numeric / (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') * 100, 1) AS pct
FROM pg_stat_activity;
-- > 80% = connection pool required immediately
```

**Exercise 5 — LISTEN/NOTIFY scale test**: Observe limits at low throughput.
```sql
-- blocked: Docker not accessible
-- Session 1: Listen
LISTEN test_channel;
-- Session 2: Notify rapidly
DO $$ BEGIN
    FOR i IN 1..100 LOOP
        PERFORM pg_notify('test_channel', 'message ' || i::text);
    END LOOP;
END $$;
-- Session 1: LISTEN delivers all 100 messages — but only to connected listeners, no persistence
```

## References
- PostgreSQL Documentation: [About PostgreSQL](https://www.postgresql.org/about/)
- InfluxDB: https://docs.influxdata.com/influxdb/ — time-series at scale
- ClickHouse: https://clickhouse.com/docs/ — OLAP column store
- CockroachDB: https://www.cockroachlabs.com/docs/ — distributed SQL
- Neo4j: https://neo4j.com/docs/ — native graph database
- Kafka: https://kafka.apache.org/documentation/ — event streaming
- pgbench: [PostgreSQL Documentation](https://www.postgresql.org/docs/16/pgbench.html) — load testing tool
- Bruce Momjian: [PostgreSQL Limitations](https://momjian.us/main/writings/pgsql/) — honest assessment from a core contributor
