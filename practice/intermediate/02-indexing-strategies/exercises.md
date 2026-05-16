# Exercises — Indexing Strategies

For each exercise: run EXPLAIN (ANALYZE, BUFFERS) BEFORE and AFTER adding the index. Record the plan type (Seq Scan / Index Scan / Index Only Scan / Bitmap Heap Scan), the estimated rows, actual rows, and execution time.

---

## Exercise 1: Baseline — measure seq scan cost

Run these queries and record their EXPLAIN ANALYZE output before adding any indexes:

```sql
-- Q1: Lookup by email (high selectivity: ~100 of 100k rows)
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, event_type, occurred_at
FROM idx_events
WHERE user_email = 'user_42@example.com';

-- Q2: Range filter on timestamp (~30 minutes of events)
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM idx_events
WHERE occurred_at > now() - interval '30 minutes';

-- Q3: Low-cardinality status filter (~2000 of 100k rows)
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, user_email FROM idx_events WHERE status = 'failed';

-- Q4: JSONB containment (USD purchases)
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, payload FROM idx_events WHERE payload @> '{"currency": "USD"}';
```

Questions:
a) What scan type is used for all four queries?
b) What is the estimated vs. actual row count for Q3?
c) What is the `Buffers: shared hit` or `shared read` count for Q1?

---

## Exercise 2: B-tree index on email

```sql
CREATE INDEX idx_events_email_idx ON idx_events (user_email);
```

Re-run Q1 from Exercise 1.

Questions:
a) What scan type is now used?
b) What changed in the Buffers output?
c) Check the index size: `SELECT pg_size_pretty(pg_relation_size('idx_events_email_idx'));`
d) Now run Q2 (timestamp filter). Does the email index help? Why or why not?

---

## Exercise 3: BRIN index on occurred_at

```sql
CREATE INDEX idx_events_time_brin ON idx_events USING BRIN (occurred_at);
```

Re-run Q2 (timestamp range filter).

Questions:
a) Does PostgreSQL use the BRIN index? Check with EXPLAIN ANALYZE.
b) What is the size of the BRIN index vs. a B-tree index on the same column?
   ```sql
   CREATE INDEX idx_events_time_btree ON idx_events (occurred_at);
   SELECT
       pg_size_pretty(pg_relation_size('idx_events_time_brin'))   AS brin_size,
       pg_size_pretty(pg_relation_size('idx_events_time_btree'))  AS btree_size;
   ```
c) For what type of table is BRIN appropriate? Would it still work if rows were inserted out of time order?

---

## Exercise 4: GIN index on JSONB payload

```sql
CREATE INDEX idx_events_payload_gin ON idx_events USING GIN (payload);
```

Re-run Q4 (JSONB containment).

Questions:
a) What scan type is now used?
b) What is the GIN index size? Compare to the B-tree on email.
c) Test another JSONB containment query:
   ```sql
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT id, payload FROM idx_events WHERE payload @> '{"element": "btn-5"}';
   ```
   Does it use the GIN index?
d) Test a non-containment JSONB query:
   ```sql
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT id FROM idx_events WHERE payload->>'element' = 'btn-5';
   ```
   Does it use the GIN index? Why or why not?

---

## Exercise 5: Partial index for pending/failed events

```sql
CREATE INDEX idx_events_pending_failed_idx
    ON idx_events (occurred_at DESC)
    WHERE status IN ('pending', 'failed');
```

Run:
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, user_email, occurred_at
FROM idx_events
WHERE status IN ('pending', 'failed')
ORDER BY occurred_at DESC
LIMIT 20;
```

Questions:
a) Does PostgreSQL use the partial index?
b) Compare the size of this partial index vs. `idx_events_time_btree`:
   ```sql
   SELECT pg_size_pretty(pg_relation_size('idx_events_pending_failed_idx')) AS partial_size,
          pg_size_pretty(pg_relation_size('idx_events_time_btree'))          AS full_btree_size;
   ```
c) Now run the same query WITHOUT the `status` filter. Does it use the partial index?
d) Why is the partial index smaller? What rows are excluded?

---

## Exercise 6: Expression index for case-insensitive email

```sql
CREATE INDEX idx_events_lower_email ON idx_events (LOWER(user_email));
```

```sql
-- With LOWER() in WHERE — should use the expression index
EXPLAIN (ANALYZE, BUFFERS)
SELECT id FROM idx_events WHERE LOWER(user_email) = 'user_42@example.com';

-- Without LOWER() — should NOT use the expression index
EXPLAIN (ANALYZE, BUFFERS)
SELECT id FROM idx_events WHERE user_email = 'user_42@example.com';
```

Questions:
a) Which query uses the expression index?
b) Which query uses `idx_events_email_idx` (the raw column index)?
c) If your application always stores emails in lowercase, is the expression index necessary? When would it be essential?

---

## Exercise 7: Covering index with INCLUDE

```sql
CREATE INDEX idx_events_email_covering
    ON idx_events (user_email)
    INCLUDE (event_type, occurred_at);
```

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT event_type, occurred_at
FROM idx_events
WHERE user_email = 'user_42@example.com'
ORDER BY occurred_at;
```

Questions:
a) Does the plan show "Index Only Scan" or "Index Scan"?
b) What is `Heap Fetches` in the output? (ANALYZE shows this for Index Only Scans)
c) Drop the covering index and re-run. What changes?
d) When is INCLUDE worth the added index size?

---

## Exercise 8: Index usage statistics

After running all queries above, check the index usage stats:

```sql
SELECT indexrelname, idx_scan, idx_tup_read, idx_tup_fetch,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE relname = 'idx_events'
ORDER BY idx_scan DESC;
```

Questions:
a) Which index has the most scans?
b) Are there any indexes with `idx_scan = 0`? Which ones and why?
c) What is the total size of all indexes combined vs. the table size?
   ```sql
   SELECT
       pg_size_pretty(pg_total_relation_size('idx_events'))           AS table_total,
       pg_size_pretty(pg_indexes_size('idx_events'))                   AS all_indexes,
       pg_size_pretty(pg_relation_size('idx_events'))                  AS table_heap;
   ```
d) Based on idx_scan counts and sizes, which indexes would you drop from a production table?
