# Time-Series Ontology

Level: Intermediate → Advanced
Domain: PostgreSQL / Time-Series

## Definition
Time-series patterns in PostgreSQL leverage native features — table partitioning by time ranges, BRIN indexes on timestamp columns, and window functions for temporal analysis — to efficiently store and query large volumes of timestamped data without a dedicated time-series database.

## Why this concept matters
Most operational data is time-stamped: events, metrics, transactions, sensor readings. PostgreSQL can handle time-series workloads at significant scale using the right partitioning strategy, index type, and query patterns, keeping the data co-located with transactional tables and benefiting from full SQL expressiveness.

Note: TimescaleDB is not available in this local environment.

## Related concepts
- [[schema-design-ontology]] — parent (partitioning is a schema-level decision)
- [[index-ontology]] — parent (BRIN indexes for time-ordered data)
- [[query-ontology]] — related (window functions, partition pruning)
- [[performance-ontology]] — related (partition pruning, BRIN effectiveness)
- [[transaction-ontology]] — related (vacuum behavior on partitions)

---

## Partitioning by Time

One-line definition: Divides a logical table into physical child partitions based on a time range, allowing the planner to skip entire partitions when the query predicate is within a specific time range.

```sql
-- blocked: Docker not accessible
-- Create a partitioned parent table
CREATE TABLE events (
    id         BIGSERIAL,
    event_at   TIMESTAMPTZ NOT NULL,
    event_type TEXT NOT NULL,
    payload    JSONB
) PARTITION BY RANGE (event_at);

-- Create monthly partitions
CREATE TABLE events_2025_01 PARTITION OF events
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE events_2025_02 PARTITION OF events
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Inspect partitions
SELECT inhrelid::regclass AS partition_name,
       pg_get_expr(c.relpartbound, c.oid) AS bound
FROM pg_inherits
JOIN pg_class c ON c.oid = inhrelid
WHERE inhparent = 'events'::regclass;
```

### Partition pruning
The planner skips partitions whose bounds exclude the query's time range. Always filter on the partition key:

```sql
-- blocked: Docker not accessible
-- Partition pruning: only events_2025_01 is scanned
SELECT * FROM events
WHERE event_at BETWEEN '2025-01-01' AND '2025-01-31';

-- Confirm pruning with EXPLAIN
EXPLAIN SELECT * FROM events WHERE event_at = '2025-01-15';
-- Look for "Partitions selected: ..."
```

---

## BRIN Index (on time-ordered data)

One-line definition: A Block Range Index stores the min/max timestamp per range of pages; extremely compact and effective when rows are physically inserted in timestamp order.

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_events_at_brin ON events USING BRIN (event_at)
    WITH (pages_per_range = 128);

-- BRIN is tiny even on huge tables
SELECT pg_size_pretty(pg_relation_size('idx_events_at_brin'));
```

When BRIN works well: Append-only tables (events, logs, metrics) where rows are inserted in timestamp order. BRIN's effectiveness degrades with random-order inserts.

Related: [[index-ontology]]

---

## Window Functions

One-line definition: SQL functions that compute a value for each row by looking at a set of related rows (the "window") defined by a PARTITION BY and ORDER BY clause, without collapsing rows like GROUP BY.

```sql
-- blocked: Docker not accessible
-- General window function syntax
SELECT
    event_at,
    value,
    function_name() OVER (
        PARTITION BY category  -- reset window per group
        ORDER BY event_at      -- define ordering within window
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW  -- frame
    ) AS computed
FROM metrics;
```

---

## lag / lead

One-line definition: Window functions that access a value from a previous (`lag`) or subsequent (`lead`) row within the ordered window.

```sql
-- blocked: Docker not accessible
SELECT
    event_at,
    value,
    lag(value, 1) OVER (ORDER BY event_at) AS prev_value,
    value - lag(value, 1) OVER (ORDER BY event_at) AS delta
FROM metrics;
```

Use cases: Computing period-over-period changes, detecting gaps in sequences.

---

## first_value / last_value / nth_value

One-line definition: Window functions that return the first, last, or nth value within the current window frame.

```sql
-- blocked: Docker not accessible
SELECT
    event_at,
    value,
    first_value(value) OVER (
        PARTITION BY device_id
        ORDER BY event_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS first_reading
FROM sensor_readings;
```

Note: `last_value` requires an explicit frame extending to `UNBOUNDED FOLLOWING` to capture the last row of the partition.

---

## date_trunc

One-line definition: Truncates a timestamp to the specified precision (second, minute, hour, day, week, month, quarter, year), enabling grouping by time bucket.

```sql
-- blocked: Docker not accessible
-- Events per hour
SELECT date_trunc('hour', event_at) AS hour_bucket,
       count(*) AS event_count
FROM events
WHERE event_at > now() - interval '7 days'
GROUP BY 1
ORDER BY 1;

-- Events per day
SELECT date_trunc('day', event_at) AS day,
       sum(amount) AS daily_total
FROM transactions
GROUP BY 1
ORDER BY 1;
```

---

## EXTRACT

One-line definition: Retrieves a specific subfield (year, month, day, hour, minute, second, epoch, dow, doy) from a timestamp or interval.

```sql
-- blocked: Docker not accessible
SELECT EXTRACT(year  FROM event_at) AS year,
       EXTRACT(month FROM event_at) AS month,
       EXTRACT(dow   FROM event_at) AS day_of_week,  -- 0=Sunday
       EXTRACT(epoch FROM event_at) AS unix_timestamp
FROM events LIMIT 5;

-- Interval extraction
SELECT EXTRACT(epoch FROM (now() - created_at)) AS age_seconds FROM orders;
```

---

## Time-Series Query Patterns

### Rolling average
```sql
-- blocked: Docker not accessible
SELECT event_at,
       value,
       avg(value) OVER (
           ORDER BY event_at
           ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
       ) AS rolling_7_avg
FROM daily_metrics;
```

### Gap detection
```sql
-- blocked: Docker not accessible
-- Find missing days in a series
SELECT generate_series(
    min(event_at::date),
    max(event_at::date),
    '1 day'::interval
)::date AS expected_date
FROM events
EXCEPT
SELECT DISTINCT event_at::date FROM events
ORDER BY expected_date;
```

### Running total
```sql
-- blocked: Docker not accessible
SELECT event_at, amount,
       sum(amount) OVER (ORDER BY event_at ROWS UNBOUNDED PRECEDING) AS running_total
FROM transactions;
```

### Latest value per group (time-series last-seen)
```sql
-- blocked: Docker not accessible
SELECT DISTINCT ON (device_id)
    device_id, event_at, reading
FROM sensor_readings
ORDER BY device_id, event_at DESC;
```

---

## TimescaleDB

One-line definition: A PostgreSQL extension that automates time-series partition management (hypertables), adds continuous aggregates, compression, and data retention policies.

Note: TimescaleDB is not available in this local environment. The native PostgreSQL patterns above cover most use cases without it.

Key TimescaleDB concepts (for reference):
- **Hypertable**: `CREATE TABLE + SELECT create_hypertable(...)` — auto-partitions by time.
- **Continuous aggregate**: Pre-computed materialized views that refresh incrementally.
- **Compression**: Columnar compression of old chunks to reduce storage 10–90%.
- **Data retention**: `add_retention_policy` to automatically drop old partitions.

---

## Partition Maintenance

```sql
-- blocked: Docker not accessible
-- Detach old partition (for archival without DROP)
ALTER TABLE events DETACH PARTITION events_2024_01;

-- Drop old partition
DROP TABLE events_2024_01;

-- Attach an existing table as a new partition
ALTER TABLE events ATTACH PARTITION events_2025_03
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
```

---

## System catalog reference
- `pg_partitioned_table` — partitioned table metadata (strategy, key)
- `pg_inherits` — parent-child partition relationships
- `pg_class.relpartbound` — partition bound expression
- `pg_stat_user_tables` — per-partition vacuum/analyze timestamps
- `pg_index` — BRIN index metadata

---

## Beginner mental model
Time-series data is just a table with a timestamp column. To make it fast: partition the table by month (so old data can be ignored automatically), create a BRIN index on the timestamp (tiny and fast for sorted appends), and use date_trunc to group by time buckets.

## Intermediate mental model
Partition pruning is automatic but requires the WHERE clause to reference the partition key (the timestamp column) with a constant or stable expression. Window functions give you time-aware computations (rolling averages, lag/lead) without self-joins. DISTINCT ON is the idiomatic PostgreSQL pattern for "latest record per group" — far more efficient than a correlated subquery.

## Advanced mental model
Partition granularity is a tradeoff: daily partitions allow fine-grained retention but create many child tables (each has its own catalog entry, vacuum state, and indexes). Monthly partitions are a good default for most workloads. For sub-second ingestion rates (IoT, metrics), consider TimescaleDB's hypertable chunking which automatically selects chunk size based on data rate. BRIN index effectiveness depends entirely on insertion order — if you need to backfill historical data out of order, BRIN is ineffective; use a B-tree on the timestamp column instead.

## MCP and agent perspective
An agent querying time-series data should always include a time filter on the partition key to ensure partition pruning. Without it, the query scans all partitions. Agents performing data retention operations (DROP PARTITION) must do so under human approval — dropped partitions are unrecoverable without backup. An agent monitoring a time-series table can detect partition gaps by querying `pg_inherits` and comparing partition bounds to the expected sequence.

## Practical implication
| Situation | Implication |
|-----------|-------------|
| No time filter on partitioned table | Full scan of all partitions; partition pruning disabled |
| BRIN on randomly-inserted timestamps | Near-useless; min/max per block covers the full range |
| Too many partitions (daily for 10 years = 3650) | Catalog overhead; planner slower; use monthly or weekly |
| window function without explicit frame | Default frame is `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` for aggregate; `last_value` may surprise |
| date_trunc timezone mismatch | Always use `AT TIME ZONE 'UTC'` or `TIMESTAMPTZ` to avoid DST boundary errors |

## Obsidian connections
[[schema-design-ontology]] [[index-ontology]] [[query-ontology]] [[performance-ontology]] [[transaction-ontology]]

## References
- PostgreSQL Table Partitioning: https://www.postgresql.org/docs/16/ddl-partitioning.html
- Window Functions: https://www.postgresql.org/docs/16/functions-window.html
- date_trunc: https://www.postgresql.org/docs/16/functions-datetime.html
- TimescaleDB: https://docs.timescale.com/
