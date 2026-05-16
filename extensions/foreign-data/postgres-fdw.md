# postgres_fdw (postgres_fdw)

Level: Advanced
Available locally: Yes

## One-line purpose

Query remote PostgreSQL databases as if their tables were local, with WHERE clauses and JOINs pushed down to the remote server for efficiency.

## Why this exists

Distributed systems often split data across multiple PostgreSQL instances — separate databases for different services, read replicas, or historical archives. `postgres_fdw` (Foreign Data Wrapper) allows a local PostgreSQL session to issue SQL against a remote PostgreSQL server transparently. The planner pushes down as much filtering as possible so the remote server does the heavy lifting, minimizing data transfer.

## Install

```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
SELECT extname, extversion FROM pg_extension WHERE extname = 'postgres_fdw';
```

## Core operations

### 1. Create a foreign server

```sql
-- blocked: Docker not accessible
-- Define the remote PostgreSQL instance
CREATE SERVER remote_cfp
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (
        host 'remote-host.example.com',
        port '5432',
        dbname 'remote_db'
    );

-- Inspect servers
SELECT * FROM pg_foreign_server;
```

### 2. Create a user mapping

```sql
-- blocked: Docker not accessible
-- Map a local user to credentials on the remote server
CREATE USER MAPPING FOR cfp
    SERVER remote_cfp
    OPTIONS (
        user 'remote_user',
        password 'remote_password'
    );

-- List user mappings
SELECT * FROM pg_user_mappings;
```

### 3. Import remote schema (recommended)

```sql
-- blocked: Docker not accessible
-- Create a local schema to hold foreign table definitions
CREATE SCHEMA remote_tables;

-- Automatically import all tables from a remote schema
IMPORT FOREIGN SCHEMA public
    FROM SERVER remote_cfp
    INTO remote_tables;

-- Or import specific tables only
IMPORT FOREIGN SCHEMA public
    LIMIT TO (orders, customers)
    FROM SERVER remote_cfp
    INTO remote_tables;

-- List foreign tables
SELECT * FROM information_schema.foreign_tables;
```

### 4. Define foreign tables manually

```sql
-- blocked: Docker not accessible
-- Alternative to IMPORT FOREIGN SCHEMA — define column layout manually
CREATE FOREIGN TABLE remote_tables.orders (
    id          INT,
    customer_id INT,
    amount      NUMERIC(12,2),
    created_at  TIMESTAMPTZ
)
SERVER remote_cfp
OPTIONS (schema_name 'public', table_name 'orders');
```

### 5. Query foreign tables

```sql
-- blocked: Docker not accessible
-- Transparent query — runs on the remote server
SELECT * FROM remote_tables.orders WHERE amount > 1000;

-- JOIN between local and remote
SELECT c.name, o.amount
FROM local_customers c
JOIN remote_tables.orders o ON c.id = o.customer_id
WHERE o.created_at > NOW() - INTERVAL '7 days';

-- Aggregate pushed down to remote
SELECT DATE_TRUNC('day', created_at) AS day, SUM(amount)
FROM remote_tables.orders
GROUP BY 1
ORDER BY 1;
```

### 6. Write to foreign tables

```sql
-- blocked: Docker not accessible
-- INSERT, UPDATE, DELETE are supported if the remote user has permissions
INSERT INTO remote_tables.orders (customer_id, amount, created_at)
VALUES (42, 199.99, NOW());

-- Disable writes on a foreign table if read-only is intended
ALTER FOREIGN TABLE remote_tables.orders OPTIONS (ADD updatable 'false');
```

### 7. Connection options

```sql
-- blocked: Docker not accessible
-- Connection pooling: keep idle connections alive
ALTER SERVER remote_cfp OPTIONS (ADD keep_connections 'on');

-- Fetch size: rows fetched per round trip (default 100, tune for bulk reads)
ALTER SERVER remote_cfp OPTIONS (ADD fetch_size '1000');

-- Extension version compatibility
ALTER SERVER remote_cfp OPTIONS (ADD extensions 'uuid-ossp,pgcrypto');
```

### 8. Inspect pushdown behavior

```sql
-- blocked: Docker not accessible
EXPLAIN (VERBOSE) SELECT * FROM remote_tables.orders WHERE amount > 1000;
-- Look for "Foreign Scan" node with "Remote SQL" showing the pushed-down query
```

## Performance characteristics

- **Pushdown**: WHERE conditions on simple column types (text, int, numeric, timestamp) are pushed to the remote. Complex expressions, user-defined functions, and non-standard casts stay local.
- **JOIN pushdown**: in PG 12+, JOINs between two foreign tables on the same server are pushed down as a single remote query.
- **Aggregate pushdown**: simple aggregates (SUM, COUNT, AVG) are pushed down (PG 11+).
- **Fetch size**: default 100 rows per round trip — increase for bulk reads to reduce latency overhead.
- **Network cost**: each query incurs at least one round trip. For latency-sensitive paths, denormalize or cache results locally.
- **Connection overhead**: postgres_fdw opens a new connection to the remote per local backend (unless `keep_connections = on`). In high-concurrency scenarios, use a connection pooler on the remote side.

## When to use

- Cross-service queries: pull data from another team's PostgreSQL instance for reporting
- Historical data: move old data to a cold archive database; query it via FDW without migrating the schema
- Read replicas: route expensive analytics to a read replica while the primary handles writes
- Database migrations: query the old database from the new one during a cutover period
- Multi-tenant: federate queries across per-tenant databases from a central router database

## When NOT to use

- High-frequency, low-latency queries (< 1ms budget) — FDW round trips are slow
- Streaming or CDC pipelines — use logical replication or Debezium instead
- When the remote schema changes often — `IMPORT FOREIGN SCHEMA` must be re-run; foreign tables do not auto-update
- Replacing a proper data warehouse — FDW is query federation, not ETL; for analytics, replicate data via pglogical or streaming pipelines
- When remote credentials must be rotated frequently — user mappings store passwords in `pg_user_mappings` as plaintext in the catalog

## Alternatives

| Alternative | When to prefer |
|-------------|---------------|
| Logical replication | Continuously sync data to a local table; zero round-trip at query time |
| pglogical | Selective replication with conflict resolution |
| `dblink` | Ad-hoc, connection-per-query; simpler setup than FDW for one-off queries |
| ETL pipeline (Airbyte, Fivetran) | Scheduled batch replication to a local analytics schema |
| PL/Proxy | Hash-based query routing across shards |

## MCP and agent perspective

- **Cross-database agent memory**: an agent operating across multiple service databases can use postgres_fdw to retrieve memory records from a central `agent_memory` database without changing connection strings mid-session
- **Scoped reads**: grant the FDW user only `SELECT` on specific remote tables; set `updatable = false` on foreign tables in the local schema to prevent accidental writes
- **Audit trail**: queries through postgres_fdw appear in the remote server's `pg_stat_statements` under the mapped remote user — monitor both sides for cost attribution
- **Parameterized queries**: always use parameterized queries when building FDW SQL dynamically; the pushdown mechanism works correctly with bind parameters and prevents injection
- **Timeout alignment**: set `statement_timeout` on the remote user mapping to prevent a runaway agent query on the remote from blocking indefinitely

## Ontology connection

- Lives under `extensions/foreign-data/` — the federation/integration pillar
- Connects to: `pg_stat_statements` (monitor FDW query cost), `dblink` (simpler alternative), logical replication (alternative data access pattern)
- Concept map: postgres_fdw → foreign server → user mapping → foreign table → WHERE pushdown → remote execution plan

## References

- [PostgreSQL postgres_fdw docs](https://www.postgresql.org/docs/16/postgres-fdw.html)
- [PostgreSQL Foreign Data Wrappers overview](https://www.postgresql.org/docs/16/fdwhandler.html)
- [IMPORT FOREIGN SCHEMA](https://www.postgresql.org/docs/16/sql-importforeignschema.html)
- [postgres_fdw pushdown reference](https://www.postgresql.org/docs/16/postgres-fdw.html#id-1.11.7.47.12)
