# Solutions — Query Planning with EXPLAIN

> validation: blocked — Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled
> EXPLAIN output is representative; actual numbers vary by data distribution and system.

---

## Exercise 1: Read a seq scan plan

**a)** `Seq Scan on orders` — full table scan. No index on `customer_id` yet.

**b)** `cost=0.00..45.00 rows=4 width=20` (example):
- `0.00` = startup cost: time before the first row can be returned (0 for seq scan — it starts immediately)
- `45.00` = total cost: estimated cost to return all rows (in planner's abstract I/O units)

**c)** Estimated rows: planner guess based on statistics. Actual rows: real count. For 2000 orders across 500 customers, expect ~4 orders per customer. If estimate is far off, run `ANALYZE orders`.

**d)** `width=N` = estimated average width in bytes of each output row. Helps the planner estimate memory usage for sorts and hash tables.

**e)** `Buffers: shared hit=N` = number of 8KB pages found in PostgreSQL's shared buffer cache (no disk I/O). `shared read=N` = pages read from disk. High hit rate is good; high read rate suggests the working set doesn't fit in cache.

**f)** Yes — a Sort node appears because `ORDER BY ordered_at DESC` requires sorting the output of the seq scan. After adding a composite index `(customer_id, ordered_at DESC)`, the Sort node disappears.

---

## Exercise 2: Index after adding composite index

**a)** `Index Scan using orders_customer_id_ordered_at_idx` (or similar name).

**b)** No Sort node — the index stores rows in `(customer_id, ordered_at DESC)` order. PostgreSQL reads them in index order, which is already the desired sort order. "Order by" is satisfied for free.

**c)** Buffers drop dramatically: from N pages (full table) to ~3–5 pages (index + heap for ~4 rows).

**d)** Seq scan would still be chosen if:
- `customer_id` had a very large number of orders (say, 50% of all orders) — the selectivity would be too low
- The table were tiny (< ~100 rows)
- `random_page_cost` is set too high relative to actual storage speed

---

## Exercise 3: Estimate vs. reality on a JOIN

**a)** Common plan: `Hash Join` — builds a hash table from `order_items`, probes with `orders`. For this data size (2k orders, ~6k items), Hash Join is typical.

**b)** Discrepancies often appear at the join output when filtering with `HAVING`. The planner estimates HAVING selectivity based on statistics about `line_total` distribution.

**c)** `Batches: 2` means the hash table didn't fit in `work_mem` and spilled to disk. Control with:
```sql
SET work_mem = '64MB';  -- increase to avoid batching
```
Default `work_mem = 4MB` is conservative.

**d)** After `CREATE INDEX ON order_items (order_id)`:
- The Hash Join may switch to `Nested Loop` if order_items has a good index on `order_id` and the outer relation (orders) is small enough
- Or remain Hash Join but faster due to index-assisted probing
- `Buffers: shared hit` drops as fewer pages are scanned

---

## Exercise 4: Bitmap Heap Scan deep-dive

**a)** Without index: `Seq Scan on orders`. ~70% of rows returned (confirmed orders) → seq scan is correct choice (too many rows for index scan to be efficient).

**b)** After `CREATE INDEX ON orders (status)`: PostgreSQL may use:
- `Bitmap Heap Scan` (gathers TIDs from index, reads heap in page order) for medium selectivity
- Or still `Seq Scan` if the fraction is high enough (~70% → seq scan is likely still chosen)

**c)** With only 4 distinct values, each ~25% of rows, the planner sees that retrieving 25% of 2000 rows (500 rows) via index means 500 random heap reads — potentially slower than scanning ~25% of heap pages sequentially. The threshold is approximately 5–15% of table size where index scan becomes competitive.

**d)** Partial index plan:
```
Limit  (cost=0.29..2.10 rows=10 ...)
  ->  Index Scan Backward using orders_ordered_at_idx on orders
        Filter: (status = 'pending')
```
The `Limit` node is crucial: PostgreSQL stops after returning 10 rows — it doesn't need to process all pending orders. The combination of a sorted partial index + LIMIT is extremely efficient for "show me the latest 10 pending orders" dashboards.

---

## Exercise 5: Index Only Scan and visibility map

**a)** `Index Only Scan using customers_email_full_name_idx` (after VACUUM).

**b)** `Heap Fetches: 0` — no heap pages were read; all needed data (email, full_name) was found in the index itself. `Heap Fetches: N > 0` means some pages were not in the visibility map and required heap verification for MVCC correctness.

**c)** After UPDATE without VACUUM: `Heap Fetches` increases significantly (possibly back to seq-scan-equivalent heap reads). Dead rows from the UPDATE have invalidated many visibility map entries. Run `VACUUM customers` to restore the Index Only Scan's effectiveness.

---

## Exercise 6: pg_stat_statements

**a)** Typically the JSONB containment query on 100k rows (`SELECT COUNT(*) FROM idx_events WHERE payload @> ...`) will have highest total time if no GIN index was present.

**b)** The query with the most complex plan (full-table JOIN with aggregation) may have the highest avg_ms.

**c)** EXPLAIN ANALYZE on the slowest query will show: `Seq Scan on idx_events` for the JSONB query (no GIN index in this setup). Root cause: missing GIN index.

**d)** Fix:
```sql
CREATE INDEX ON idx_events USING GIN (payload);
ANALYZE idx_events;
SELECT pg_stat_statements_reset();
-- Re-run the slow query 10 times
```
avg_ms should drop from hundreds of ms to single-digit ms.

---

## Exercise 7: Join order and planner

**a)** Typical plan: `Hash Join` with `customers` as build side (smaller: 500 rows) and `orders` as probe side.

**b)** Outer relation = `customers` (driving the loop or building the hash). Inner = `orders` (probed).

**c)** After `CREATE INDEX ON orders (customer_id)`:
- May switch to `Nested Loop` — for each customer, do an index scan on orders by customer_id
- Or remain Hash Join if batch size favors hashing

**d)** PostgreSQL has no `USE INDEX` or join-order hint syntax. Alternatives:
- `SET join_collapse_limit = 1` — forces the written join order (session-level; diagnostic use only)
- Rewrite with CTEs (pre-PG12 CTEs act as optimization fences; PG12+ may inline them)
- `SET enable_hashjoin = off` / `enable_nestloop = off` — disable specific strategies to test alternatives

---

## Exercise 8: pg_stat_user_tables

**a)** Without any manual indexes, `orders` likely has `pct_seq = 100%` for the join and filter queries run in previous exercises.

**b)** Recommended indexes:
- `orders (customer_id)` — reduces seq scans on orders for customer-based queries
- `orders (status)` — reduces seq scans for status filters (if high selectivity expected)
- `order_items (order_id)` — reduces seq scans on order_items for join queries
- No index needed on `products` or `customers` for common queries (small tables or already using PK)

**c)** After adding indexes and resetting:
- `idx_scan` count increases for `orders` and `order_items`
- `seq_scan` count decreases
- `pct_seq` drops below 50% for tables that now have useful indexes

Key insight: `pg_stat_user_tables` shows cumulative counts since the last reset. Always reset before a fresh measurement:
```sql
SELECT pg_stat_reset();
```
