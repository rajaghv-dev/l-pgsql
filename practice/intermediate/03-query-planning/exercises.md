# Exercises — Query Planning with EXPLAIN

For each exercise: read the plan carefully, answer the questions, then apply the fix and compare the before/after plans.

---

## Exercise 1: Read a seq scan plan

Run:
```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, status, ordered_at
FROM orders
WHERE customer_id = 42
ORDER BY ordered_at DESC;
```

a) What is the plan type? (Seq Scan / Index Scan / other)
b) Find the `cost=X..Y` values. What do X and Y represent?
c) What is the estimated row count vs. the actual row count?
d) What is `width=N`? What does it measure?
e) What does `Buffers: shared hit=N` tell you?
f) Is there a Sort node? Why or why not?

---

## Exercise 2: Add an index and re-read the plan

Add an index that would help the query in Exercise 1:

```sql
CREATE INDEX ON orders (customer_id, ordered_at DESC);
ANALYZE orders;
```

Re-run the same EXPLAIN from Exercise 1.

a) What plan type is used now?
b) Is there a Sort node? Explain why the index removes the need for a sort.
c) Compare `Buffers` before and after. What changed?
d) Is there a scenario where PostgreSQL would still choose a seq scan over this index?

---

## Exercise 3: Estimate vs. reality — find a bad estimate

Run:
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.id, o.status, SUM(oi.line_total) AS order_total
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.id, o.status
HAVING SUM(oi.line_total) > 200;
```

a) What join algorithm is used?
b) Compare the estimated vs. actual row counts at each node. Is there a large discrepancy?
c) What does a Hash Join: `Batches: 2` mean (if you see it)? What controls this?
d) Add the missing FK indexes and re-run:
   ```sql
   CREATE INDEX ON order_items (order_id);
   ANALYZE order_items;
   ```
   How does the plan change?

---

## Exercise 4: Bitmap Heap Scan deep-dive

Run:
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, customer_id, ordered_at
FROM orders
WHERE status = 'confirmed';
```

(No index on status yet.)

a) What is the plan? How many rows does `status = 'confirmed'` return (~70% of orders)?
b) Create an index and re-run:
   ```sql
   CREATE INDEX ON orders (status);
   ANALYZE orders;
   ```
   What plan is used now?
c) For a column with very low cardinality (e.g., only 4 distinct values, each representing ~25% of rows), when would PostgreSQL prefer a Seq Scan over an Index Scan even with an index?
d) Create a partial index and re-run:
   ```sql
   CREATE INDEX ON orders (ordered_at DESC) WHERE status = 'pending';
   ANALYZE orders;
   ```
   Run:
   ```sql
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT id, ordered_at FROM orders WHERE status = 'pending'
   ORDER BY ordered_at DESC LIMIT 10;
   ```
   What plan is used? Why is a Limit node important here?

---

## Exercise 5: Index Only Scan and the visibility map

```sql
CREATE INDEX ON customers (email) INCLUDE (full_name);
VACUUM customers;

EXPLAIN (ANALYZE, BUFFERS)
SELECT email, full_name FROM customers WHERE email LIKE 'customer_4%';
```

a) What scan type is used?
b) What is `Heap Fetches`? What does 0 mean vs. non-zero?
c) Run a large UPDATE on customers then re-run EXPLAIN (without VACUUM). Does the Index Only Scan degrade?
   ```sql
   UPDATE customers SET full_name = full_name || ' (updated)' WHERE id % 2 = 0;
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT email, full_name FROM customers WHERE email LIKE 'customer_4%';
   ```

---

## Exercise 6: pg_stat_statements — find the slowest queries

Run a variety of queries to populate pg_stat_statements, then:

```sql
-- Run these to build up statistics:
SELECT COUNT(*) FROM orders WHERE status = 'pending';
SELECT COUNT(*) FROM idx_events WHERE payload @> '{"currency": "USD"}';
SELECT * FROM orders WHERE customer_id = 1 ORDER BY ordered_at DESC;
SELECT o.id, SUM(oi.line_total) FROM orders o
    JOIN order_items oi ON oi.order_id = o.id GROUP BY o.id;
-- Repeat each query 10 times to get meaningful totals
```

Then:
```sql
SELECT LEFT(query, 100)       AS query_snippet,
       calls,
       ROUND(mean_exec_time::numeric, 3) AS avg_ms,
       ROUND(total_exec_time::numeric, 1) AS total_ms,
       rows
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat%'
ORDER BY total_exec_time DESC
LIMIT 5;
```

a) Which query has the highest `total_exec_time`?
b) Which has the highest `avg_ms`?
c) For the slowest query, run EXPLAIN ANALYZE and identify the root cause (missing index, bad estimate, etc.).
d) Fix the root cause and verify the improvement.

---

## Exercise 7: Join order and planner behavior

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.full_name, COUNT(o.id) AS order_count
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
GROUP BY c.id, c.full_name
ORDER BY order_count DESC
LIMIT 10;
```

a) What join algorithm and join order does the planner choose?
b) Which table is the "outer" and which is the "inner" in the join?
c) Add indexes and re-run:
   ```sql
   CREATE INDEX ON orders (customer_id);
   ANALYZE orders, customers;
   ```
   Does the join algorithm change?
d) Why can't you use a query hint to force a specific join order in PostgreSQL? What is the alternative?

---

## Exercise 8: pg_stat_user_tables — identify tables with high seq_scan

```sql
SELECT relname,
       seq_scan,
       idx_scan,
       n_live_tup,
       ROUND(seq_scan::numeric / NULLIF(seq_scan + idx_scan, 0) * 100, 1)
           AS pct_seq
FROM pg_stat_user_tables
WHERE relname IN ('orders', 'customers', 'products', 'order_items', 'idx_events')
ORDER BY seq_scan DESC;
```

a) Which table has the highest `pct_seq`?
b) For each table with `pct_seq > 50%` and `n_live_tup > 1000`, what index would reduce seq scans?
c) After adding your recommended indexes, reset stats and re-run the workload:
   ```sql
   SELECT pg_stat_reset();
   -- Re-run your query workload from Exercise 6
   -- Then re-run the pg_stat_user_tables query above
   ```
   Did `pct_seq` decrease?
