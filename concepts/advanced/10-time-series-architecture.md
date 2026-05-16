# Time-Series Architecture in PostgreSQL

Level: Advanced

## One-line intuition
PostgreSQL can handle time-series workloads with range partitioning, BRIN indexes, and window functions — without TimescaleDB — if you understand the architectural trade-offs and tune for append-heavy, time-ordered data.

## Why this exists
Time-series data — IoT sensor readings, application metrics, event logs, financial ticks — has distinctive characteristics: high insert rate, strictly ordered by time, queries that aggregate over time windows, and data that loses value after a retention period. PostgreSQL can serve these workloads natively, but requires architectural decisions specifically suited to the access pattern.

## First-principles explanation

### Characteristics of time-series workloads
- **Append-heavy**: data arrives in roughly time order; past data is rarely updated
- **Ordered by time**: queries nearly always filter on a time range
- **Aggregation-focused**: `avg()`, `sum()`, `count()` over time windows dominate
- **Retention-bounded**: data older than N days/months can be dropped

These characteristics map directly to PostgreSQL features: range partitioning for retention, BRIN for time indexes, window functions for aggregations.

### Schema design for time-series

**Basic time-series table**:
```sql
-- blocked: Docker not accessible
CREATE TABLE sensor_readings (
    sensor_id integer NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    temperature numeric(5,2),
    humidity numeric(5,2),
    pressure numeric(7,2)
) PARTITION BY RANGE (recorded_at);

-- Monthly partitions
CREATE TABLE sensor_readings_2024_01 PARTITION OF sensor_readings
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

**Compressed column store for high density**: PostgreSQL's row store is suboptimal for time-series. Options:
- Use BRIN to minimize index overhead (not columnar)
- Use `JSONB` or `hstore` to pack multiple sensor values per row (one row per sensor batch)
- TimescaleDB compression (columnar within chunk) — unavailable here, but the pattern

### BRIN indexes for time-series
BRIN works perfectly for append-only time-series because physical insertion order matches time order (correlation ≈ 1.0):

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_readings_brin ON sensor_readings
    USING BRIN (recorded_at)
    WITH (pages_per_range = 32);  -- 32 pages ≈ 256KB per range summary

-- Verify correlation
SELECT attname, correlation FROM pg_stats
WHERE tablename = 'sensor_readings_2024_01'
  AND attname = 'recorded_at';
-- Should be close to 1.0 for append-only tables
```

For a 100GB table: B-tree index ≈ 2-5GB. BRIN index ≈ 100KB. With correlation ≈ 1.0, BRIN effectiveness approaches B-tree for range scans.

### Window functions for time-series analysis

**Lag and lead**: compare current row to previous/next.
```sql
-- blocked: Docker not accessible
SELECT sensor_id, recorded_at, temperature,
       lag(temperature) OVER (PARTITION BY sensor_id ORDER BY recorded_at) AS prev_temp,
       temperature - lag(temperature) OVER (PARTITION BY sensor_id ORDER BY recorded_at) AS delta
FROM sensor_readings
WHERE recorded_at >= '2024-01-01'
ORDER BY sensor_id, recorded_at;
```

**Rolling aggregates**: moving average.
```sql
-- blocked: Docker not accessible
SELECT sensor_id, recorded_at, temperature,
       avg(temperature) OVER (
           PARTITION BY sensor_id
           ORDER BY recorded_at
           ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
       ) AS moving_avg_6
FROM sensor_readings
WHERE recorded_at >= '2024-01-01';
```

**First/last value in a group**: first and last reading per day.
```sql
-- blocked: Docker not accessible
SELECT sensor_id, date_trunc('day', recorded_at) AS day,
       first_value(temperature) OVER (
           PARTITION BY sensor_id, date_trunc('day', recorded_at)
           ORDER BY recorded_at
       ) AS first_temp,
       last_value(temperature) OVER (
           PARTITION BY sensor_id, date_trunc('day', recorded_at)
           ORDER BY recorded_at
           ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
       ) AS last_temp
FROM sensor_readings;
```

**Time bucketing with date_trunc**:
```sql
-- blocked: Docker not accessible
-- Hourly averages
SELECT sensor_id,
       date_trunc('hour', recorded_at) AS hour,
       avg(temperature) AS avg_temp,
       min(temperature) AS min_temp,
       max(temperature) AS max_temp,
       count(*) AS reading_count
FROM sensor_readings
WHERE recorded_at >= now() - interval '7 days'
GROUP BY sensor_id, date_trunc('hour', recorded_at)
ORDER BY sensor_id, hour;
```

### Data retention via partitioning
```sql
-- blocked: Docker not accessible
-- Drop last month's partition (instant, no VACUUM needed)
ALTER TABLE sensor_readings DETACH PARTITION sensor_readings_2023_12;
DROP TABLE sensor_readings_2023_12;

-- Or archive to cold storage first (logical backup)
COPY sensor_readings_2023_12 TO '/archive/sensor_readings_2023_12.csv' CSV HEADER;
DROP TABLE sensor_readings_2023_12;
```

### Continuous aggregates (manual pattern without TimescaleDB)
Without TimescaleDB's native continuous aggregates, implement with materialized views refreshed on a schedule:

```sql
-- blocked: Docker not accessible
CREATE MATERIALIZED VIEW sensor_hourly AS
SELECT sensor_id,
       date_trunc('hour', recorded_at) AS hour,
       avg(temperature) AS avg_temp,
       count(*) AS reading_count
FROM sensor_readings
GROUP BY sensor_id, date_trunc('hour', recorded_at)
WITH NO DATA;

CREATE INDEX ON sensor_hourly (sensor_id, hour);

-- Refresh (call from cron or pg_cron):
REFRESH MATERIALIZED VIEW CONCURRENTLY sensor_hourly;
```

Limitation: `REFRESH MATERIALIZED VIEW CONCURRENTLY` requires a unique index. Cannot incrementally refresh — always recomputes the full view.

### Insert performance optimization
- **Batch inserts**: `INSERT INTO ... SELECT ...` or `COPY` for bulk loads
- **Disable synchronous_commit for non-critical data**: `SET synchronous_commit = off` — loses < 1 commit cycle on crash, 2-3x throughput gain
- **Fill current partition**: avoid auto-creating partitions mid-insert (performance penalty for first insert in a new partition)

### Limitations vs TimescaleDB
| Feature | Native PostgreSQL | TimescaleDB |
|---|---|---|
| Automatic partition management | Manual or pg_partman | Automatic (hypertables) |
| Columnar compression | No | Yes (per-chunk compression) |
| Continuous aggregates | Manual (mat. view) | Incremental, automatic |
| Data tiering | Manual tablespace | Automatic (hot/warm/cold) |
| Insert throughput | ~50K-200K rows/sec | ~500K-1M rows/sec |

For workloads above 200K inserts/second, TimescaleDB or a dedicated TSDB (InfluxDB, QuestDB) is more appropriate.

## Micro-concepts
- **`generate_series(start, end, interval)`**: generates time buckets without data. Essential for gap-filled time series.
- **gap-filling**: generate_series produces all expected time buckets; LEFT JOIN sensor data fills in NULLs for missing readings.
- **`percentile_cont(0.95) WITHIN GROUP (ORDER BY col)`**: ordered-set aggregate for percentile calculations in time windows.
- **`ROWS BETWEEN`**: frame specification for window functions. `ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING` = 3-row window.
- **`RANGE BETWEEN`**: time-based window frame. `RANGE BETWEEN interval '1 hour' PRECEDING AND CURRENT ROW` = rolling 1-hour window.
- **correlation maintenance**: for BRIN effectiveness, inserts must arrive in time order. Bulk loading out of order destroys BRIN correlation. Pre-sort data before loading: `COPY (SELECT ... ORDER BY ts) TO ...`.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Store readings with a timestamp, query with WHERE on the timestamp column, aggregate with GROUP BY + date_trunc.

**Intermediate view**: Partition by month for retention. Use BRIN for the timestamp index (tiny index, good for range scans). Use window functions for moving averages.

**Advanced view**: BRIN's effectiveness depends entirely on physical insertion order matching logical time order. Out-of-order bulk loads destroy BRIN benefit. Window function performance with PARTITION BY over large datasets may require pre-aggregation into materialized views. The `RANGE BETWEEN interval '...' PRECEDING AND CURRENT ROW` frame specification allows true time-based (not row-based) rolling windows but is significantly slower than `ROWS BETWEEN` for large datasets. Partition granularity (daily vs monthly vs quarterly) must balance pruning effectiveness against partition count overhead.

## Mental model
Time-series data is a river — always flowing in one direction (time), always adding water (new rows), with old water (old rows) eventually flowing out (retention). Partitioning builds dams along the river, one per time period. Queries fish in the stretch of river they care about. BRIN is a bridge over the river at regular intervals — you can quickly locate the right stretch because the river always flows in order. Window functions are the analysis: looking upstream and downstream from each point to compute rolling statistics.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_partitioned_table`, `pg_statio_user_tables` (I/O per partition), `pg_stat_user_tables` (tuple counts per partition).

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Gap-filled hourly reading (no gaps even for missing hours)
SELECT
    series.hour,
    s.sensor_id,
    coalesce(avg(r.temperature), 0) AS avg_temp
FROM generate_series(
    '2024-01-01'::timestamptz,
    '2024-01-07'::timestamptz,
    '1 hour'::interval
) AS series(hour)
CROSS JOIN (SELECT DISTINCT sensor_id FROM sensor_readings) s
LEFT JOIN sensor_readings r
    ON r.recorded_at >= series.hour
    AND r.recorded_at < series.hour + interval '1 hour'
    AND r.sensor_id = s.sensor_id
GROUP BY series.hour, s.sensor_id
ORDER BY s.sensor_id, series.hour;
```

**Non-SQL / hybrid view**: TimescaleDB (if available) provides hypertables, continuous aggregates, and data tiering. InfluxDB and QuestDB are purpose-built for time-series with columnar storage. Prometheus uses its own TSDB engine but can write metrics to PostgreSQL via adapters.

## Design principle
**Optimize for the write path first, the read path second**: Time-series workloads are write-dominant. Minimize write amplification (few indexes, BRIN not B-tree), maximize insert batching (COPY over individual INSERTs), and let the partition structure organize data so reads are naturally bounded. Pre-aggregate into materialized views at the granularity queries need rather than computing aggregations at query time.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: Materialized view refresh (`REFRESH MATERIALIZED VIEW`) is always a full recompute without TimescaleDB's incremental aggregation. For a year of hourly data, this can take minutes. It also locks the view for the duration of the refresh (mitigated by `CONCURRENTLY` but still requires an exclusive lock at the start and end). For true real-time dashboards, use pre-computed aggregate tables updated by triggers or application code.

**Creative**: Use `generate_series` + a lateral join to implement time-bucket queries without window functions — more flexible for complex aggregations:
```sql
-- blocked: Docker not accessible
SELECT bucket, (SELECT count(*) FROM sensor_readings r WHERE r.recorded_at >= bucket AND r.recorded_at < bucket + '1 hour'::interval) AS cnt
FROM generate_series('2024-01-01', '2024-01-02', '1 hour'::interval) AS bucket;
```

**Systems**: Time-series data at scale always needs a tiering strategy. Recent data (hot) = fast NVMe, high frequency, full granularity. Older data (warm) = compressed or pre-aggregated, slower storage. Archival data (cold) = object storage (S3) or PostgreSQL tablespace on HDD. Without TimescaleDB, implement tiering with tablespace-per-partition and a scheduled job that moves old partitions to slower storage.

## MCP and agent perspective
AI agents generate natural time-series data: actions, observations, reflections, all timestamped. Structuring agent logs as a time-series table (partitioned by day or week, BRIN-indexed) enables efficient replay of agent behavior for debugging, auditing, and training. Window functions over agent action logs enable detection of behavioral patterns (response latency trends, error rate by hour). Materialized views can pre-aggregate agent performance metrics without impacting the primary OLTP path.

## Ontology perspective
Time-series represents the transition of a system through state space over time. Each reading is a snapshot of the system's state at one moment. The time dimension is the primary ontological axis — not identity (which entity), not space (where), but when. This temporal primacy justifies the entire architectural orientation: partitioning by time, indexing by time, aggregating by time. Time-series architecture is an ontological commitment that time is the most fundamental dimension of the data.

## Practice session

**Exercise 1 — Time-bucket aggregation**: Hourly sensor averages.
```sql
-- blocked: Docker not accessible
SELECT date_trunc('hour', recorded_at) AS hour,
       sensor_id,
       round(avg(temperature)::numeric, 2) AS avg_temp,
       count(*) AS readings
FROM sensor_readings
WHERE recorded_at >= now() - interval '24 hours'
GROUP BY date_trunc('hour', recorded_at), sensor_id
ORDER BY hour, sensor_id;
```

**Exercise 2 — Moving average**: 5-reading rolling average per sensor.
```sql
-- blocked: Docker not accessible
SELECT sensor_id, recorded_at, temperature,
       round(avg(temperature) OVER (
           PARTITION BY sensor_id
           ORDER BY recorded_at
           ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
       )::numeric, 2) AS moving_avg
FROM sensor_readings
ORDER BY sensor_id, recorded_at;
```

**Exercise 3 — Gap filling**: Find all hours even if no data exists.
```sql
-- blocked: Docker not accessible
SELECT hour,
       coalesce(avg_temp, 0) AS avg_temp
FROM generate_series(
    date_trunc('hour', now() - interval '24 hours'),
    date_trunc('hour', now()),
    interval '1 hour'
) AS hour
LEFT JOIN (
    SELECT date_trunc('hour', recorded_at) AS h, avg(temperature) AS avg_temp
    FROM sensor_readings WHERE sensor_id = 1
    GROUP BY 1
) agg ON agg.h = hour;
```

**Exercise 4 — Partition by month for a new table**:
```sql
-- blocked: Docker not accessible
CREATE TABLE metrics (ts timestamptz NOT NULL, name text, value numeric)
PARTITION BY RANGE (ts);
CREATE TABLE metrics_2024_01 PARTITION OF metrics FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE metrics_default PARTITION OF metrics DEFAULT;
CREATE INDEX ON metrics USING BRIN (ts);
```

**Exercise 5 — Percentile calculation**: 95th percentile response time by hour.
```sql
-- blocked: Docker not accessible
SELECT date_trunc('hour', ts) AS hour,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY value) AS p95
FROM metrics
WHERE name = 'response_time_ms'
GROUP BY date_trunc('hour', ts)
ORDER BY hour;
```

## References
- PostgreSQL Documentation: [Window Functions](https://www.postgresql.org/docs/16/tutorial-window.html)
- PostgreSQL Documentation: [Window Function Syntax](https://www.postgresql.org/docs/16/sql-expressions.html#SYNTAX-WINDOW-FUNCTIONS)
- PostgreSQL Documentation: [Date/Time Functions](https://www.postgresql.org/docs/16/functions-datetime.html)
- TimescaleDB Documentation (conceptual reference): https://docs.timescale.com/
- Piotr Sarna: [PostgreSQL as a Time-Series Database](https://www.timescale.com/blog/what-is-time-series-data/)
- Michael Christofides: [Time-series data with PostgreSQL](https://crunchydata.com/blog/building-time-series-data-with-postgresql)
