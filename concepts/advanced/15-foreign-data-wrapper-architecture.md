# Foreign Data Wrapper Architecture

Level: Advanced

## One-line intuition
Foreign Data Wrappers make remote data sources look like local tables — enabling federated SQL queries across PostgreSQL instances, CSV files, REST APIs, and databases — but they are not magic: pushdown determines whether the remote server does the work or your PostgreSQL does.

## Why this exists
Data rarely lives in one place. FDW lets you JOIN a remote PostgreSQL table with a local table without extracting the data first. It enables read access to legacy systems, cross-cluster analytics, and data virtualization — all with standard SQL. The trade-off: network latency, predicate pushdown limitations, and join performance are all architectural concerns you must design around.

## First-principles explanation

### FDW architecture
PostgreSQL's FDW API is defined in `foreign_data_wrapper.h`. An FDW is a C extension that implements:
- `GetForeignRelSize`: estimate row count (for planner)
- `GetForeignPaths`: propose scan paths (for planner)
- `GetForeignPlan`: finalize the plan
- `BeginForeignScan` / `IterateForeignScan` / `EndForeignScan`: execution interface
- `BeginForeignModify` / `ExecForeignInsert` / etc.: write interface (if writable)

The FDW abstraction is clean: from the planner's perspective, a foreign table looks like a regular table with cost estimates. From the executor's perspective, it's an iterator that yields rows.

### postgres_fdw — the primary FDW

**Setup**:
```sql
-- blocked: Docker not accessible
-- On the local server:
CREATE EXTENSION postgres_fdw;

CREATE SERVER remote_analytics
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'analytics.internal', port '5432', dbname 'analytics');

CREATE USER MAPPING FOR local_user
    SERVER remote_analytics
    OPTIONS (user 'fdw_reader', password 'secret');

-- Import all tables from a remote schema
IMPORT FOREIGN SCHEMA public
    FROM SERVER remote_analytics
    INTO local_fdw_schema;

-- Or define manually:
CREATE FOREIGN TABLE remote_orders (
    id bigint,
    created_at timestamptz,
    customer_id bigint,
    total_amount numeric
) SERVER remote_analytics
  OPTIONS (schema_name 'public', table_name 'orders');
```

**Basic cross-server query**:
```sql
-- blocked: Docker not accessible
-- Join local customers with remote orders
SELECT c.name, o.total_amount
FROM customers c
JOIN remote_orders o ON o.customer_id = c.id
WHERE o.created_at >= '2024-01-01';
```

### Predicate pushdown
This is the most critical FDW concept. Predicate pushdown means: the WHERE clause (or part of it) is sent to the remote server for execution there, rather than fetching all rows and filtering locally.

**With pushdown**:
```sql
-- Remote server executes:
-- SELECT id, created_at, customer_id, total_amount FROM orders WHERE created_at >= '2024-01-01'
-- 10,000 rows returned
```

**Without pushdown** (if predicate is not pushdown-eligible):
```sql
-- Remote server executes:
-- SELECT id, created_at, customer_id, total_amount FROM orders
-- 100,000,000 rows returned, then local filter
```

Pushdown eligibility rules for `postgres_fdw`:
- Simple column comparisons with literals: pushed down
- Functions: pushed down if the function name exists on the remote
- Complex expressions: may not be pushed down (check EXPLAIN)
- JOINs between two foreign tables on the same server: pushed down as a remote join (PG 10+)

Always run `EXPLAIN (VERBOSE)` to see what SQL is sent to the remote:
```sql
-- blocked: Docker not accessible
EXPLAIN (VERBOSE, ANALYZE) SELECT * FROM remote_orders WHERE created_at >= '2024-01-01';
-- Shows: "Remote SQL: SELECT ... FROM public.orders WHERE ((created_at >= '2024-01-01 00:00:00+00'))"
```

### Asynchronous execution (PG 14+)
When querying multiple foreign tables on different servers, PostgreSQL 14+ can execute the scans in parallel:
```sql
-- blocked: Docker not accessible
-- Two foreign tables on different servers — scanned asynchronously
SELECT * FROM fdw_server1.events
UNION ALL
SELECT * FROM fdw_server2.events;
```

Enable: `SET enable_async_append = on;` (default on in PG 14+). With async execution, both foreign server queries start simultaneously, reducing total latency.

### file_fdw — read CSV/text files
```sql
-- blocked: Docker not accessible
CREATE EXTENSION file_fdw;

CREATE SERVER fs_server FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE sales_csv (
    date date,
    product_id int,
    quantity int,
    revenue numeric
) SERVER fs_server
  OPTIONS (filename '/data/sales.csv', format 'csv', header 'true');

-- Query like a regular table
SELECT date, sum(revenue) FROM sales_csv GROUP BY date;
```

file_fdw has no pushdown — all data is read and filtered locally. For large files, this is slow. Use `COPY` for bulk loading instead.

### Performance design patterns

**Pattern 1: FDW for selective lookups (good)**
```sql
-- blocked: Docker not accessible
-- Fetch a specific customer's orders (highly selective, few rows transferred)
SELECT * FROM remote_orders WHERE customer_id = 42;
```
Small result set → low network overhead → FDW is appropriate.

**Pattern 2: FDW for full cross-server join (bad)**
```sql
-- blocked: Docker not accessible
-- Join 1M local customers with 100M remote orders
SELECT c.name, count(o.id)
FROM customers c
JOIN remote_orders o ON o.customer_id = c.id
GROUP BY c.name;
```
This transfers 100M rows across the network unless the join is pushed down. Without pushdown (or if the join isn't all on one foreign server), this is catastrophically slow.

**Pattern 3: Materialized foreign data (compromise)**
```sql
-- blocked: Docker not accessible
-- Replicate remote data locally with a scheduled refresh
CREATE MATERIALIZED VIEW local_orders AS SELECT * FROM remote_orders;
CREATE INDEX ON local_orders (customer_id, created_at);
REFRESH MATERIALIZED VIEW CONCURRENTLY local_orders;
-- Query the local copy
```

This loses real-time freshness but gains full local query performance.

**Pattern 4: FDW for schema federation**
Use IMPORT FOREIGN SCHEMA to present a unified schema across shards:
```sql
-- blocked: Docker not accessible
-- Import shard 1 tables with prefix
IMPORT FOREIGN SCHEMA public LIMIT TO (users, orders)
    FROM SERVER shard1_server INTO shard1;
-- Import shard 2 tables with prefix
IMPORT FOREIGN SCHEMA public LIMIT TO (users, orders)
    FROM SERVER shard2_server INTO shard2;
-- Create union views
CREATE VIEW all_orders AS
    SELECT *, 1 AS shard FROM shard1.orders
    UNION ALL
    SELECT *, 2 AS shard FROM shard2.orders;
```

### When FDW is the right tool
- Cross-version PostgreSQL access (e.g., reading from a PG 14 cluster on PG 16)
- Selective, indexed lookups on a remote server
- ETL staging: read from remote, transform locally, write to local
- Federated reporting on multiple databases without replication setup
- Reading CSV / JSON files as tables (file_fdw, log_fdw)

### When FDW is the wrong tool
- High-frequency joins (> 100 queries/second) — network latency dominates
- Full-table or large-range scans on remote tables — use replication instead
- Write-heavy workloads on foreign tables — network round-trips per write
- Tables where pushdown is partial — unexpected full scans degrade unpredictably

## Micro-concepts
- **foreign server**: the connection definition to the remote data source (`CREATE SERVER`).
- **user mapping**: maps a local role to remote credentials (`CREATE USER MAPPING`).
- **IMPORT FOREIGN SCHEMA**: discovers and creates all foreign tables from a remote schema automatically.
- **`use_remote_estimate = true`**: tells `postgres_fdw` to query the remote server for table statistics (slower setup, better plan estimates).
- **`fetch_size`**: how many rows to fetch per network round-trip. Default 100. Raise for large scans: `OPTIONS (fetch_size '10000')`.
- **`batch_size`**: for INSERT operations via FDW, how many rows to batch per round-trip.
- **Writable FDW**: `postgres_fdw` supports INSERT/UPDATE/DELETE on foreign tables. Row modifications are sent to the remote server.
- **Transaction safety**: `postgres_fdw` participates in two-phase commit (2PC) for transaction safety across servers. Requires `max_prepared_transactions > 0`.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: FDW makes remote tables queryable with SQL. `postgres_fdw` for cross-PostgreSQL access, `file_fdw` for CSV files.

**Intermediate view**: Predicate pushdown determines performance. Check EXPLAIN VERBOSE. Use `fetch_size` for large scans. Set `use_remote_estimate = true` for better query plans.

**Advanced view**: FDW performance is fundamentally limited by network latency and pushdown completeness. A query that pushes a WHERE clause to a remote server with 1ms RTT still pays 1ms × number of round-trips. For high-frequency queries, FDW is inappropriate — use streaming replication or logical replication to maintain a local copy. Asynchronous FDW (PG 14+) parallelizes multi-server scans, reducing total latency to the maximum single-server latency rather than the sum. Two-phase commit for writable FDW requires careful transaction design and monitoring for in-doubt transactions.

## Mental model
FDW is a long-distance telephone call during your query: PostgreSQL picks up the phone (network connection), asks the remote database a question (SQL query), waits for the answer (network round-trip), and continues processing. Predicate pushdown means you ask the most specific question possible ("give me only March orders") rather than "give me all orders, I'll filter myself." The FDW is only as fast as your network connection and the remote server's ability to answer specifically.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_foreign_server`, `pg_foreign_table`, `pg_user_mappings`, `pg_foreign_data_wrapper`.

**SQL view**:
```sql
-- blocked: Docker not accessible
-- List foreign servers
SELECT srvname, fdwname, srvoptions FROM pg_foreign_server
JOIN pg_foreign_data_wrapper ON pg_foreign_data_wrapper.oid = srvfdw;

-- List foreign tables
SELECT foreign_table_name, foreign_server_name FROM information_schema.foreign_tables;

-- Check pushdown with VERBOSE
EXPLAIN (VERBOSE) SELECT * FROM remote_orders WHERE created_at >= now() - interval '7 days';
-- Look for "Remote SQL:" in output
```

**Non-SQL / hybrid view**: Many FDWs exist beyond postgres_fdw and file_fdw:
- `mysql_fdw`: read from MySQL
- `mongo_fdw`: read from MongoDB (JSONB result type)
- `redis_fdw`: read from Redis
- `oracle_fdw`: enterprise Oracle access
- `parquet_fdw`: query Parquet files directly
- `s3_fdw` (Citus, Hydra): query S3 object storage

## Design principle
**FDW is data virtualization, not data replication**: Use FDW when you need occasional access to remote data without the operational overhead of replication. When access frequency exceeds ~10 queries/second or data freshness tolerance exceeds 1 minute, prefer replication (logical replication or streaming) to FDW.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: FDW failures are hard to handle in application code. If the remote server is down, queries on foreign tables fail with a connection error, not a query error. Applications querying FDW tables need explicit error handling for network failures — treating a missing remote table as a non-retryable error is a common bug.

**Creative**: Use FDW + materialized view refresh to implement a simple ETL pipeline without external tooling. A daily cron job calls `REFRESH MATERIALIZED VIEW` on a view defined over FDW tables — pulling fresh data from the remote system, transforming it locally, and making it available for reporting with full local query performance.

**Systems**: In a microservices architecture where each service owns its database, FDW enables cross-service queries without building a data warehouse. The tradeoff: coupling at the data layer — the FDW query breaks if the remote schema changes. Contract testing (validating remote schema shape before querying) is a pattern from API-first design that applies equally to FDW schemas.

## MCP and agent perspective
AI agents in multi-service architectures can use FDW to query reference data from other services' databases without coupling at the application layer. An agent that needs product catalog data from the commerce service can query it via FDW from the agent's own database context. Ensure FDW user mappings use least-privilege read-only credentials. Monitor foreign table scan counts in `pg_stat_user_tables` (foreign tables appear in this view) to detect unexpected full-table FDW scans.

## Ontology perspective
FDW implements data virtualization — presenting remote data as if it were local without materializing it. This is a form of ontological transparency: from the query's perspective, there is only one data space. But the illusion breaks when performance is considered: the spatial and temporal properties of remote data (latency, freshness) are very different from local data. FDW makes the data model transparent while leaving the physical model opaque — a useful abstraction that requires understanding its leakage points (network, pushdown, transactions).

## Practice session

**Exercise 1 — Setup postgres_fdw** (requires two PostgreSQL servers):
```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE SERVER remote_db FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'localhost', port '5433', dbname 'other_db');
CREATE USER MAPPING FOR current_user
    SERVER remote_db OPTIONS (user 'postgres', password '');
```

**Exercise 2 — Import foreign schema**:
```sql
-- blocked: Docker not accessible
CREATE SCHEMA IF NOT EXISTS fdw_remote;
IMPORT FOREIGN SCHEMA public FROM SERVER remote_db INTO fdw_remote;
SELECT * FROM information_schema.foreign_tables WHERE foreign_server_name = 'remote_db';
```

**Exercise 3 — Check pushdown**: Verify predicates are sent to remote.
```sql
-- blocked: Docker not accessible
EXPLAIN (VERBOSE) SELECT * FROM fdw_remote.orders WHERE created_at > '2024-01-01';
-- Look for "Remote SQL:" containing the WHERE clause
```

**Exercise 4 — file_fdw for CSV**:
```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS file_fdw;
CREATE SERVER csv_server FOREIGN DATA WRAPPER file_fdw;
CREATE FOREIGN TABLE import_data (
    id int, name text, value numeric
) SERVER csv_server OPTIONS (filename '/tmp/data.csv', format 'csv', header 'true');
SELECT * FROM import_data LIMIT 5;
```

**Exercise 5 — Fetch size tuning**: For large remote tables.
```sql
-- blocked: Docker not accessible
ALTER FOREIGN TABLE fdw_remote.large_table OPTIONS (ADD fetch_size '10000');
-- Monitor: pg_stat_activity will show the remote query with FETCH
```

## References
- PostgreSQL Documentation: [Foreign Data](https://www.postgresql.org/docs/16/ddl-foreign-data.html)
- PostgreSQL Documentation: [postgres_fdw](https://www.postgresql.org/docs/16/postgres-fdw.html)
- PostgreSQL Documentation: [file_fdw](https://www.postgresql.org/docs/16/file-fdw.html)
- PostgreSQL Documentation: [Writing a Foreign Data Wrapper](https://www.postgresql.org/docs/16/fdwhandler.html)
- FDW extensions list: https://wiki.postgresql.org/wiki/Foreign_data_wrappers
- Álvaro Herrera: [postgres_fdw improvements](https://www.postgresql.org/docs/16/postgres-fdw.html)
