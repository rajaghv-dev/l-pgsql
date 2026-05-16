# Time-Series Monitoring Example

Level: Advanced
Domain: Range-partitioned metrics table with BRIN index, time-bucket aggregations, and anomaly detection
Synthetic data: Yes

## Overview

A time-series monitoring system for synthetic infrastructure metrics — no TimescaleDB
required. Uses pure PostgreSQL features:

- **Range partitioning** by month on `recorded_at`
- **BRIN index** on the timestamp column (efficient for append-only time-series)
- **`date_trunc` aggregations** for time-bucket queries (5-minute, hourly, daily)
- **Window functions** for rolling averages
- **Anomaly detection** — flag values more than 3 standard deviations from the mean
- **JSONB `labels`** column for flexible metric dimensions (host, region, service)

> TimescaleDB status: **blocked: TimescaleDB not available in cfp_postgres**
>
> This example uses vanilla PostgreSQL partitioning. TimescaleDB `time_bucket()`,
> `add_retention_policy()`, and hypertables are not available locally.

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- Parent partitioned table
CREATE TABLE metrics (
    id          BIGSERIAL,
    metric_name TEXT            NOT NULL,
    value       DOUBLE PRECISION NOT NULL,
    labels      JSONB            NOT NULL DEFAULT '{}',
    recorded_at TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, recorded_at)          -- partition key must be in PK
) PARTITION BY RANGE (recorded_at);

-- Monthly partitions (covers May and June 2024 for seed data)
CREATE TABLE metrics_2024_05 PARTITION OF metrics
    FOR VALUES FROM ('2024-05-01') TO ('2024-06-01');

CREATE TABLE metrics_2024_06 PARTITION OF metrics
    FOR VALUES FROM ('2024-06-01') TO ('2024-07-01');

-- Default partition: catches anything not matched above
CREATE TABLE metrics_default PARTITION OF metrics DEFAULT;

-- BRIN index: very compact, efficient for append-only time-series
-- (B-tree would also work but BRIN has much lower storage overhead)
CREATE INDEX idx_metrics_recorded_at ON metrics
    USING BRIN (recorded_at) WITH (pages_per_range = 128);

-- B-tree index on metric_name for filtering
CREATE INDEX idx_metrics_name ON metrics (metric_name, recorded_at);

-- GIN index on labels for JSONB filtering
CREATE INDEX idx_metrics_labels ON metrics USING GIN (labels);
```

Note on partitioning: in production you would automate monthly partition creation
(e.g., via a scheduled job or pg_partman). This example creates two static
partitions sufficient for the seed data.

## Seed data

The seed data simulates two metrics (`cpu_percent` and `memory_percent`) sampled
every 5 minutes over a 4-day window, with one injected anomaly spike.

```sql
-- Generate synthetic time-series data using generate_series
-- CPU % for host "web-01": baseline ~40%, two anomaly spikes
INSERT INTO metrics (metric_name, value, labels, recorded_at)
SELECT
    'cpu_percent',
    CASE
        -- Inject anomaly spikes
        WHEN gs BETWEEN 100 AND 103 THEN 95 + RANDOM() * 5    -- spike ~95-100%
        ELSE 35 + RANDOM() * 15                                 -- normal 35-50%
    END,
    '{"host": "web-01", "region": "eu-west-1", "service": "api"}'::JSONB,
    '2024-05-28 00:00:00+00'::TIMESTAMPTZ + (gs * INTERVAL '5 minutes')
FROM generate_series(0, 575) AS gs;   -- 575 * 5min = ~48 hours

-- Memory % for host "web-01": baseline ~60%, generally stable
INSERT INTO metrics (metric_name, value, labels, recorded_at)
SELECT
    'memory_percent',
    58 + RANDOM() * 8,   -- 58-66%
    '{"host": "web-01", "region": "eu-west-1", "service": "api"}'::JSONB,
    '2024-05-28 00:00:00+00'::TIMESTAMPTZ + (gs * INTERVAL '5 minutes')
FROM generate_series(0, 575) AS gs;

-- CPU % for host "db-01": lower baseline ~20%
INSERT INTO metrics (metric_name, value, labels, recorded_at)
SELECT
    'cpu_percent',
    18 + RANDOM() * 10,
    '{"host": "db-01", "region": "eu-west-1", "service": "postgres"}'::JSONB,
    '2024-05-28 00:00:00+00'::TIMESTAMPTZ + (gs * INTERVAL '5 minutes')
FROM generate_series(0, 575) AS gs;
```

## Example queries

### Last hour of data per metric (most recent point)

```sql
SELECT metric_name,
       labels->>'host'           AS host,
       ROUND(AVG(value)::NUMERIC, 2) AS avg_value,
       ROUND(MAX(value)::NUMERIC, 2) AS max_value,
       COUNT(*)                  AS data_points
FROM   metrics
WHERE  recorded_at >= NOW() - INTERVAL '1 hour'
GROUP  BY metric_name, labels->>'host'
ORDER  BY metric_name, host;
```

### 5-minute time buckets for a metric (like TimescaleDB time_bucket)

```sql
SELECT DATE_TRUNC('minute', recorded_at - (EXTRACT(MINUTE FROM recorded_at)::INT % 5) * INTERVAL '1 minute')
           AS bucket_start,
       ROUND(AVG(value)::NUMERIC, 2) AS avg_value,
       ROUND(MIN(value)::NUMERIC, 2) AS min_value,
       ROUND(MAX(value)::NUMERIC, 2) AS max_value,
       COUNT(*)                      AS samples
FROM   metrics
WHERE  metric_name = 'cpu_percent'
  AND  labels->>'host' = 'web-01'
  AND  recorded_at BETWEEN '2024-05-28 00:00:00+00' AND '2024-05-28 06:00:00+00'
GROUP  BY 1
ORDER  BY 1;
```

### Hourly aggregation

```sql
SELECT DATE_TRUNC('hour', recorded_at)    AS hour,
       ROUND(AVG(value)::NUMERIC, 2)     AS avg_cpu,
       ROUND(MAX(value)::NUMERIC, 2)     AS peak_cpu
FROM   metrics
WHERE  metric_name  = 'cpu_percent'
  AND  labels->>'host' = 'web-01'
  AND  recorded_at >= '2024-05-28'::DATE
GROUP  BY DATE_TRUNC('hour', recorded_at)
ORDER  BY hour;
```

### Rolling 1-hour average (window function)

```sql
SELECT recorded_at,
       value                           AS raw_value,
       ROUND(AVG(value) OVER (
           PARTITION BY metric_name, labels->>'host'
           ORDER BY recorded_at
           RANGE BETWEEN INTERVAL '30 minutes' PRECEDING
                     AND INTERVAL '30 minutes' FOLLOWING
       )::NUMERIC, 2)                  AS rolling_1h_avg
FROM   metrics
WHERE  metric_name  = 'cpu_percent'
  AND  labels->>'host' = 'web-01'
  AND  recorded_at BETWEEN '2024-05-28 01:00:00+00' AND '2024-05-28 05:00:00+00'
ORDER  BY recorded_at;
```

### Anomaly detection: values > mean + 3 * stddev

```sql
WITH stats AS (
    SELECT metric_name,
           labels->>'host'    AS host,
           AVG(value)         AS mean_val,
           STDDEV(value)      AS stddev_val
    FROM   metrics
    WHERE  recorded_at >= '2024-05-28'::DATE
    GROUP  BY metric_name, labels->>'host'
)
SELECT m.metric_name,
       m.labels->>'host'       AS host,
       m.recorded_at,
       ROUND(m.value::NUMERIC, 2)        AS value,
       ROUND(s.mean_val::NUMERIC, 2)     AS mean,
       ROUND(s.stddev_val::NUMERIC, 2)   AS stddev,
       ROUND((m.value - s.mean_val) / NULLIF(s.stddev_val, 0), 2) AS z_score
FROM   metrics m
JOIN   stats   s ON s.metric_name  = m.metric_name
                AND s.host         = m.labels->>'host'
WHERE  m.recorded_at >= '2024-05-28'::DATE
  AND  ABS(m.value - s.mean_val) > 3 * s.stddev_val
ORDER  BY ABS(m.value - s.mean_val) / NULLIF(s.stddev_val, 0) DESC;
```

### Partition pruning verification

```sql
-- The planner should only scan metrics_2024_05, not metrics_2024_06 or default
EXPLAIN (ANALYZE FALSE, COSTS TRUE, FORMAT TEXT)
SELECT COUNT(*)
FROM   metrics
WHERE  recorded_at BETWEEN '2024-05-28' AND '2024-05-30';
-- Look for "Append" node with only metrics_2024_05 in the plan
```

### Daily summary per host and metric

```sql
SELECT DATE_TRUNC('day', recorded_at)::DATE AS day,
       metric_name,
       labels->>'host'                      AS host,
       ROUND(AVG(value)::NUMERIC, 2)       AS avg_value,
       ROUND(MIN(value)::NUMERIC, 2)       AS min_value,
       ROUND(MAX(value)::NUMERIC, 2)       AS max_value,
       COUNT(*)                            AS samples
FROM   metrics
GROUP  BY 1, 2, 3
ORDER  BY 1, 2, 3;
```

### Label-filtered queries (JSONB)

```sql
-- All metrics for a specific service
SELECT metric_name, ROUND(AVG(value)::NUMERIC, 2) AS avg_value
FROM   metrics
WHERE  labels @> '{"service": "postgres"}'
  AND  recorded_at >= '2024-05-28'
GROUP  BY metric_name;
```

## TimescaleDB comparison (blocked)

The following shows what equivalent queries look like with TimescaleDB.
These will not run in `cfp_postgres`.

```sql
-- blocked: TimescaleDB not available in cfp_postgres

-- SELECT time_bucket('5 minutes', recorded_at) AS bucket,
--        AVG(value) AS avg_cpu
-- FROM   metrics
-- WHERE  metric_name = 'cpu_percent'
--   AND  recorded_at > NOW() - INTERVAL '1 hour'
-- GROUP  BY bucket
-- ORDER  BY bucket;

-- Continuous aggregates:
-- CREATE MATERIALIZED VIEW metrics_hourly
-- WITH (timescaledb.continuous)
-- AS SELECT time_bucket('1 hour', recorded_at) AS hour,
--           AVG(value) AS avg_value
--    FROM metrics GROUP BY 1;
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- Total rows (3 metrics * 576 points each)
SELECT COUNT(*) FROM metrics;
-- Expected: 1728

-- Rows in each partition
SELECT tableoid::regclass AS partition, COUNT(*) FROM metrics GROUP BY 1;
-- Expected: all rows in metrics_2024_05 (since seed data is in May 2024)

-- Metric names
SELECT DISTINCT metric_name FROM metrics ORDER BY metric_name;
-- Expected: cpu_percent, memory_percent

-- Hosts
SELECT DISTINCT labels->>'host' AS host FROM metrics ORDER BY host;
-- Expected: db-01, web-01

-- BRIN index exists
SELECT indexname FROM pg_indexes WHERE tablename = 'metrics';
```

## Practice tasks

1. **Add a new partition.** Create `metrics_2024_07` for July 2024. Insert 10
   synthetic rows with `recorded_at` in July. Run the partition-pruning EXPLAIN
   for a July date range and confirm only the July partition is scanned.

2. **Custom time bucket.** Write a query that groups metrics into 15-minute buckets
   using `DATE_TRUNC` and integer arithmetic. Compare the output with the 5-minute
   bucket query.

3. **Alert threshold.** Write a query that returns all 5-minute buckets where the
   average `cpu_percent` for `web-01` exceeds 80%. How many such buckets exist?

4. **BRIN vs B-tree.** Add a B-tree index on `recorded_at`. Use `EXPLAIN ANALYZE`
   to compare the BRIN and B-tree index scan costs for a 1-hour query window.
   For what query patterns is BRIN preferable?

5. **Retention simulation.** Write a query that identifies rows older than 30 days.
   In a real system, how would you delete old data safely using partition dropping
   vs. DELETE? What are the trade-offs?

## MCP and agent perspective

An observability agent using this schema via MCP would:

- **Poll for anomalies** — run the z-score detection query every 5 minutes and
  alert if any metric exceeds the 3-sigma threshold.
- **Build dashboards** — the 5-minute and hourly aggregation queries feed chart
  data without needing a separate time-series database.
- **Answer ad-hoc questions** — "what was the peak CPU for web-01 yesterday?" maps
  directly to the daily summary query.
- **Efficient with partitions** — partition pruning means the planner skips months
  of data when querying a recent time window, keeping query latency low even on
  tables with billions of rows.
- **Label-based scoping** — JSONB labels allow the agent to filter by any dimension
  (host, region, service) without needing a JOIN to a separate dimension table.

## Teardown

```sql
DROP TABLE IF EXISTS metrics;   -- drops all partitions automatically
```

## References

- Table Partitioning: https://www.postgresql.org/docs/current/ddl-partitioning.html
- BRIN Indexes: https://www.postgresql.org/docs/current/brin.html
- Window Functions: https://www.postgresql.org/docs/current/tutorial-window.html
- generate_series: https://www.postgresql.org/docs/current/functions-srf.html
- TimescaleDB (reference): https://docs.timescale.com/
