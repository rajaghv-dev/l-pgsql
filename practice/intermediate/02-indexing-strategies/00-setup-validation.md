# Setup Validation — Indexing Strategies

> **Validation status**: blocked — Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled.

## Row count

```sql
SELECT COUNT(*) FROM idx_events;
-- Expected: 100000
```

## Distribution check

```sql
SELECT * FROM idx_events_summary;
-- Expected approximate distribution:
-- click/processed  ~62700, click/pending ~8400, click/failed ~1400
-- view/processed   ~7600, ...
-- purchase/...
-- logout/...
```

## Data ordering (for BRIN validation)

```sql
-- Confirm data is inserted in roughly ascending occurred_at order
SELECT MIN(occurred_at), MAX(occurred_at),
       MAX(occurred_at) - MIN(occurred_at) AS span
FROM idx_events;
-- Expected: span of approximately 27 hours (100000 seconds)
```

## Initial index state (only PK should exist)

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'idx_events'
ORDER BY indexname;
-- Expected: only idx_events_pkey
```

## Sample EXPLAIN before any indexes (should show Seq Scan)

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM idx_events WHERE user_email = 'user_42@example.com';
-- Expected plan: Seq Scan on idx_events
-- Note cost, actual rows, and Buffers hit count
```

## JSONB containment query (no GIN index yet)

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM idx_events WHERE payload @> '{"currency": "USD"}';
-- Expected: Seq Scan (no GIN index yet)
-- Note the cost — will compare after adding GIN
```
