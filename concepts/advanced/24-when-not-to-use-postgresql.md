# When NOT to Use PostgreSQL

Level: Advanced
PostgreSQL 16 | Container: `docker exec cfp_postgres psql -U cfp -d cfp`

## One-line intuition
Knowing when to walk away from PostgreSQL is as important as knowing how to use it — every tool has a domain where it is the wrong choice.

## Why this exists
PostgreSQL advocacy can become PostgreSQL dogma. Honest engineers acknowledge that some workloads genuinely require specialized systems, and using PostgreSQL for those workloads creates operational debt, performance problems, and unnecessary complexity.

## First-principles explanation
PostgreSQL is a row-store, single-leader OLTP database with MVCC, SQL, and an extension ecosystem. These properties make it excellent for transactional workloads with complex queries. They also create inherent limitations at extremes: MVCC adds write overhead, row-based storage is inefficient for OLAP, single-leader limits global write distribution, and general-purpose parsing adds latency unavoidable for cache-tier use.

## When NOT to use PostgreSQL

### 1. Sub-millisecond latency requirements
**Use instead**: Redis, Memcached, Dragonfly

If your application requires P99 latency under 1ms (session caches, rate limiters, real-time leaderboards), PostgreSQL's parsing, planning, and network overhead makes it the wrong tool. Use an in-memory store.

### 2. Global active-active writes across regions
**Use instead**: CockroachDB, Cassandra, DynamoDB

PostgreSQL's streaming replication is leader-based. All writes go to the primary. If you need low-latency writes from multiple geographic regions simultaneously, PostgreSQL requires application-level conflict resolution that is error-prone. Distributed databases handle this natively.

### 3. OLAP on billions of rows with sub-second response
**Use instead**: ClickHouse, DuckDB, BigQuery, Redshift

PostgreSQL's row-based storage reads full rows even for queries touching 2 columns out of 50. Column-store systems compress and vectorize OLAP queries to run 10–100x faster on the same hardware at analytical scale.

### 4. IoT telemetry at > 500k writes/second sustained
**Use instead**: InfluxDB, TimescaleDB, QuestDB

MVCC means every UPDATE or DELETE creates dead tuples requiring vacuum. At extreme write rates, vacuum cannot keep up and bloat accumulates. TimescaleDB (a PostgreSQL extension) extends the ceiling significantly, but InfluxDB is purpose-built for this ceiling.

### 5. Native graph algorithms at graph scale
**Use instead**: Neo4j, Memgraph, Amazon Neptune

PostgreSQL can model graphs with recursive CTEs, but traversal is O(n) in SQL — each hop requires a new join. Native graph databases store adjacency lists as first-class objects with O(1) edge traversal. For graph algorithms (PageRank, shortest path, community detection) on millions of edges, use a native graph database.

### 6. Event streaming / pub-sub at scale
**Use instead**: Kafka, Pulsar, NATS

PostgreSQL's LISTEN/NOTIFY is a simple notification system. It has no persistence beyond the current session, no consumer groups, no message replay, and no backpressure. For high-throughput event streaming with durable, replayable queues, use a dedicated message broker.

## What PostgreSQL handles better than many assume

- **Vector search**: pgvector with HNSW is production-ready at moderate scale (< 10M embeddings)
- **Full-text search**: pg_trgm + tsvector covers most application FTS needs without Elasticsearch
- **Time-series at moderate scale**: partitioning + BRIN indexes work well for < 100k writes/minute
- **JSON documents**: JSONB with GIN indexes covers most MongoDB use cases with ACID guarantees
- **Queues**: SKIP LOCKED pattern works well for most background job systems

## Beginner view
Use PostgreSQL unless you have a specific, measured reason not to. Most "we need Redis/Kafka/Elasticsearch" decisions are premature optimization.

## Intermediate view
Validate each requirement before adding a specialized system. Measure your actual throughput, latency, and query patterns against PostgreSQL's real behavior — not theoretical limits.

## Advanced view
The cost of a specialized system is operational: monitoring, backup, scaling, security, team expertise, and data synchronization. Only pay that cost when PostgreSQL's ceiling is demonstrably below your requirement.

## Mental model
PostgreSQL is the Swiss Army knife of databases. It does everything adequately. For workloads at the extremes of any dimension, you need the specialized tool — but only at the extremes.

## Design principle
**Measure before specializing**: instrument your PostgreSQL workload before deciding it cannot handle it. pg_stat_statements often reveals that the bottleneck is a missing index or a bad query, not a database system limit.

## Critical thinking
A startup says "we'll definitely need Kafka eventually, so let's add it now." What is the counter-argument? What is the cost of adding Kafka prematurely?

## Creative thinking
How would you architect a migration path from a pure PostgreSQL system to a hybrid system (PostgreSQL + Redis) with zero downtime?

## Systems thinking
When you add a specialized system alongside PostgreSQL, what new failure modes appear? (Synchronization lag, inconsistency windows, partial failures, split-brain.)

## MCP and agent perspective
For AI agents, PostgreSQL's generality is a feature: one system means one audit log, one permission model, one backup strategy. Prefer PostgreSQL + extensions over a multi-system architecture for agent memory unless scale genuinely demands it.

## Ontology perspective
[[performance-ontology]] [[observability-ontology]] [[vector-search-ontology]] [[time-series-ontology]]

## References
- [PostgreSQL vs X comparison](https://www.postgresql.org/about/) — official capability docs
- [When to use Redis](https://redis.io/docs/about/) — Redis documentation
- [ClickHouse performance benchmarks](https://clickhouse.com/docs/en/getting-started/example-datasets/) — OLAP benchmarks
- [Kafka vs PostgreSQL queues](https://www.pgcon.org) — PGCon talks on queue patterns
