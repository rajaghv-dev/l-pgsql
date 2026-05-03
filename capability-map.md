# Capability Map

PostgreSQL capabilities organized by what problem they solve.

---

## Store structured data

| Capability | Feature | Level |
|------------|---------|-------|
| Relational tables | CREATE TABLE, types, constraints | Beginner |
| Schema namespacing | CREATE SCHEMA | Beginner |
| Flexible documents | JSONB columns | Beginner+ |
| Key-value pairs | hstore | Intermediate |
| Hierarchical paths | ltree | Intermediate |
| Time-series (external) | TimescaleDB | Advanced |
| Geospatial | PostGIS | Advanced |

## Query and retrieve data

| Capability | Feature | Level |
|------------|---------|-------|
| Basic queries | SELECT, WHERE, JOIN, GROUP BY | Beginner |
| Aggregation | COUNT, SUM, AVG, window functions | Intermediate |
| Full-text search | tsvector, tsquery, GIN index | Intermediate |
| Fuzzy search | pg_trgm similarity | Intermediate |
| Vector search | pgvector, cosine / L2 distance | Intermediate |
| JSON queries | JSONB operators, jsonpath | Intermediate |
| Graph traversal | Recursive CTEs | Intermediate |
| Pivot tables | tablefunc crosstab | Intermediate |
| Spatial queries | PostGIS (not local) | Advanced |

## Protect data integrity

| Capability | Feature | Level |
|------------|---------|-------|
| Column constraints | NOT NULL, UNIQUE, CHECK | Beginner |
| Referential integrity | FOREIGN KEY | Beginner |
| Transactions | BEGIN / COMMIT / ROLLBACK | Beginner |
| Isolation levels | READ COMMITTED, REPEATABLE READ, SERIALIZABLE | Intermediate |
| Optimistic locking | Version columns, SERIALIZABLE | Intermediate |
| MVCC | Built-in, no explicit config | Intermediate |

## Control access

| Capability | Feature | Level |
|------------|---------|-------|
| Roles and grants | CREATE ROLE, GRANT, REVOKE | Beginner |
| Row Level Security | CREATE POLICY, ENABLE RLS | Intermediate |
| Column-level security | Column GRANT | Intermediate |
| Encryption | pgcrypto | Intermediate |
| Audit logging | pgaudit (not local), triggers, event tables | Intermediate |

## Improve performance

| Capability | Feature | Level |
|------------|---------|-------|
| B-tree index | Default index type | Beginner |
| GIN index | JSONB, full-text, trgm | Intermediate |
| GiST index | Range types, geometric, trgm | Intermediate |
| Partial index | WHERE clause on index | Intermediate |
| Expression index | Index on function result | Intermediate |
| BRIN index | Large append-only tables | Advanced |
| Covering index | INCLUDE columns | Intermediate |
| Query planning | EXPLAIN, ANALYZE, pg_stat_statements | Intermediate |
| Autovacuum tuning | autovacuum params | Advanced |
| Parallel query | max_parallel_workers | Advanced |
| Connection pooling | PgBouncer (external) | Advanced |

## Build agent-safe systems

| Capability | Feature | Level |
|------------|---------|-------|
| Narrow MCP tools | Limit to specific operations | Intermediate |
| RLS tenant isolation | per-row policy | Intermediate |
| Immutable audit | append-only trigger, no DELETE | Intermediate |
| Approval workflows | status column + constraint | Intermediate |
| Queue patterns | SKIP LOCKED | Advanced |
| Compensation / rollback | Transaction + savepoint | Advanced |
| Semantic memory | pgvector embeddings | Advanced |

## Observe and debug

| Capability | Feature | Level |
|------------|---------|-------|
| Query stats | pg_stat_statements | Intermediate |
| Buffer cache | pg_buffercache | Advanced |
| Auto-explain | auto_explain | Advanced |
| Page inspection | pageinspect | Advanced |
| Bloat stats | pgstattuple | Advanced |
| Lock inspection | pgrowlocks, pg_locks | Advanced |
