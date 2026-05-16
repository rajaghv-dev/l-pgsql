# Reflection — Query Planning with EXPLAIN

---

## 1. The cost model is not wall-clock time

PostgreSQL's `cost=X..Y` values are not milliseconds — they are abstract I/O units. Two plans with `cost=5000` and `cost=4500` will always have the planner choose the latter, but the real-world performance difference could be negligible or enormous depending on caching, parallelism, and hardware.

When is the cost model misleading? Describe a scenario where the cheaper plan (by cost estimate) is actually slower in practice.

---

## 2. EXPLAIN without ANALYZE is a guess

`EXPLAIN` (without ANALYZE) shows what PostgreSQL *plans* to do based on statistics. `EXPLAIN ANALYZE` shows what it *actually did*.

Describe a scenario where the plan shown by `EXPLAIN` and the actual execution shown by `EXPLAIN ANALYZE` would diverge significantly. What causes the divergence?

---

## 3. The statistics problem

PostgreSQL collects statistics with `ANALYZE` (automatically via autovacuum). The default statistics target is 100 data points per column.

For the `status` column in `orders` (only 4 distinct values), is the default statistics target adequate? What about for `customer_id` (500 distinct values in this practice)? For a `description TEXT` column with millions of distinct values?

What would you change with `ALTER TABLE ... ALTER COLUMN ... SET STATISTICS N`?

---

## 4. Index on FK columns

PostgreSQL does NOT automatically create indexes on FK columns (unlike MySQL). In the Stage 7 schema, `orders.customer_id` is an FK but has no index by default.

What queries suffer from this? What is the cost (in seq scans) of not indexing FK columns? Write a query to find all FK columns in your schema that lack an index.

Hint:
```sql
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS referenced_table
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_name = ccu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY';
-- Compare this list to pg_indexes
```

---

## 5. The Limit node

In Exercise 4, a `Limit` node at the top of the plan dramatically changes performance. Without LIMIT, PostgreSQL must process all matching rows. With LIMIT, it can stop early.

What happens to plan cost when you add `LIMIT 10` to a query that previously required a sort? How does the planner's `startup_cost` vs. `total_cost` relate to LIMIT optimization?

---

## 6. work_mem and hash join batches

In Exercise 3, `Batches: 2` means a hash join spilled to disk. `work_mem` controls the in-memory budget per sort and hash operation.

If a query has 3 hash joins, and `work_mem = 4MB`, how much memory could it use? (Hint: each node gets its own `work_mem` budget.) What is the risk of setting `work_mem = 1GB` globally?

---

## 7. pg_stat_statements in production

`pg_stat_statements` shows aggregate statistics across all executions. In production with thousands of distinct queries, how would you use it to:
- Find the "worst offender" queries (most total time)?
- Find queries with high variance (fast sometimes, slow sometimes)?
- Track whether a query improved after adding an index?
