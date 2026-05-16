# Troubleshooting — Indexing Strategies

---

## Seq Scan still used after creating an index

**Cause 1: Table is small** — the planner prefers seq scan when the table fits in shared_buffers and an index lookup would be more work than a sequential read.
**Fix**: This practice uses 100k rows; seq scan should not be chosen for selective queries. If it is, force an index scan to compare:
```sql
SET enable_seqscan = off;
EXPLAIN (ANALYZE, BUFFERS) <your query>;
SET enable_seqscan = on;
```

**Cause 2: Stale statistics** — ANALYZE was not run after bulk insert.
**Fix**:
```sql
ANALYZE idx_events;
```

**Cause 3: Low selectivity** — query returns too many rows (e.g., `status = 'processed'` returns 90% of rows). Seq scan is correctly chosen.
**Fix**: This is correct behavior. Use a partial index or accept the seq scan.

---

## GIN index not used for `payload->>'key' = 'value'`

**Cause**: The `->>'key'` operator is an extraction, not a containment check. GIN indexes support `@>` (containment) but not `->>'key'` equality directly.

**Fix**: Create an expression index:
```sql
CREATE INDEX ON idx_events ((payload->>'element'));
-- Query: WHERE payload->>'element' = 'btn-5'  → uses this index
```

Or rewrite the query using containment:
```sql
WHERE payload @> '{"element": "btn-5"}'
-- Uses GIN index ✓
```

---

## Index Only Scan not appearing after creating a covering index

**Cause**: The visibility map is not current — PostgreSQL must verify visibility from the heap.
**Fix**:
```sql
VACUUM idx_events;
EXPLAIN (ANALYZE, BUFFERS) <your query>;
-- Now Heap Fetches should be 0
```

---

## BRIN index not being used

**Cause 1**: The range condition (`occurred_at > now() - interval '30 minutes'`) returns a large fraction of blocks. BRIN's block-level filtering is coarse — if the condition hits many blocks, the planner may prefer a seq scan.

**Cause 2**: Data is not physically ordered by `occurred_at`. BRIN provides no benefit if rows are randomly distributed across pages.

**Diagnostic**:
```sql
SET enable_seqscan = off;
EXPLAIN (ANALYZE, BUFFERS) SELECT COUNT(*) FROM idx_events
WHERE occurred_at > now() - interval '30 minutes';
SET enable_seqscan = on;
-- Compare cost with BRIN forced vs. seq scan
```

---

## Expression index not matching query

**Cause**: The query expression does not exactly match the index expression.

```sql
-- Index: LOWER(user_email)
-- Query: WHERE user_email ILIKE 'User_42@example.com'  ← different expression
-- Query: WHERE LOWER(user_email) = LOWER('User_42@example.com')  ← matches ✓
```

**Fix**: Ensure the query uses the exact same function call and argument types as the index.

---

## Index size larger than expected

**Cause**: Dead tuples in the index from updates. GIN indexes accumulate pending entries before they are merged.

**Fix**:
```sql
VACUUM ANALYZE idx_events;
-- Check bloat
SELECT * FROM pgstatindex('idx_events_payload_gin');
-- If avg_leaf_density is low (< 50%), consider REINDEX
REINDEX INDEX CONCURRENTLY idx_events_payload_gin;
```

---

## generate_series insert is slow

**Cause**: With no parallel workers or low `work_mem`, the 100k row insert may be slow.

**Fix**: This is a one-time cost. If it takes more than 30 seconds, check if `autovacuum` is running concurrently on the table. It shouldn't block — but it can slow things down.

```sql
-- Check if autovacuum is running
SELECT pid, query FROM pg_stat_activity WHERE query LIKE '%autovacuum%';
```
