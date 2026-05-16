# Exercises: Simple Indexes

Level: Beginner

Work through each exercise in order. Do not look at `solutions.md` until you have tried.

---

## Exercise 1: Read an EXPLAIN Plan Before Any Index

**Goal:** Understand what a sequential scan looks like in EXPLAIN output and what the cost numbers mean.

**First-principles question:** Why does PostgreSQL have to read all 50,000 rows to answer `WHERE price < 10.00`? What information is missing that would allow it to skip rows?

**Task:** Run EXPLAIN (not EXPLAIN ANALYZE) on a price filter query. Read the output and identify: scan type, estimated rows, estimated cost.

**Your SQL:**
```sql
EXPLAIN SELECT * FROM products WHERE price < 10.00;
```

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT * FROM products WHERE price < 10.00;
"
```

**Expected output (approximate — cost numbers vary):**
```
                          QUERY PLAN
-------------------------------------------------------------------
 Seq Scan on products  (cost=0.00..1193.00 rows=500 width=87)
   Filter: (price < 10.00)
```

**Interpret the output:**
- `Seq Scan` — sequential scan (reads every row)
- `cost=0.00..1193.00` — startup cost .. total cost (in arbitrary units)
- `rows=500` — estimated number of matching rows
- `width=87` — average row width in bytes
- `Filter` — the condition applied to each row after it is read

**Critical-thinking question:** The estimate says 500 rows. The actual number depends on the data. How does PostgreSQL estimate without running the query? (Hint: it uses statistics stored in `pg_stats`.)

**Creative-thinking question:** If you change the condition to `WHERE price < 100.00`, would the estimated cost go up or stay the same? Why?

**Systems-thinking question:** A sequential scan reads all 50,000 rows from disk into memory. How does this affect disk I/O if the table is much larger than RAM?

**Ontology-thinking question:** `Seq Scan` is an "access path" — a way to reach rows. What other access paths does PostgreSQL support? (Look at pg_am.)

**What this teaches:** EXPLAIN shows the query plan without running the query. Seq Scan = no useful index found.

---

## Exercise 2: Add an Index and Compare Plans

**Goal:** Create a B-tree index on `price` and observe how EXPLAIN changes.

**First-principles question:** A B-tree index keeps values sorted. Why does sorting help a range query (`price < 10.00`) but not necessarily a query like `WHERE category = 'Electronics'` (with only 8 distinct values)?

**Task:**
1. Create a B-tree index on the `price` column.
2. Run EXPLAIN on the same query from Exercise 1.
3. Compare the plan: does it show `Index Scan` or still `Seq Scan`?

**Your SQL:**
```sql
CREATE INDEX idx_products_price ON products (price);

EXPLAIN SELECT * FROM products WHERE price < 10.00;
```

**Commands:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE INDEX idx_products_price ON products (price);
"
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT * FROM products WHERE price < 10.00;
"
```

**Expected output (with index):**
```
                                  QUERY PLAN
-----------------------------------------------------------------------------
 Index Scan using idx_products_price on products  (cost=0.28..25.00 rows=500 width=87)
   Index Cond: (price < 10.00)
```

**Interpret the difference:**
- Cost dropped from ~1193 to ~25 — the planner no longer reads all rows.
- `Index Scan using idx_products_price` — found and used the index.
- `Index Cond` — condition evaluated inside the index (not as a post-filter).

**Critical-thinking question:** If you run `EXPLAIN SELECT * FROM products WHERE price < 500.00` (half the rows match), does the planner still use the index? Why or why not? (Run it and see.)

**Creative-thinking question:** Run `EXPLAIN SELECT price FROM products WHERE price < 10.00`. Would an index-only scan appear? What is needed for that?

**Systems-thinking question:** Creating an index on a live production table takes time and locks the table. How would you create this index on a production table without downtime? (Hint: look up `CREATE INDEX CONCURRENTLY`.)

**Ontology-thinking question:** The index is a secondary data structure derived from the table. How does PostgreSQL keep the index consistent when rows are inserted or updated?

**What this teaches:** Adding an index changes the access path from Seq Scan to Index Scan for selective queries.

---

## Exercise 3: When PostgreSQL Ignores the Index

**Goal:** Demonstrate that PostgreSQL will NOT use an index when the query is not selective enough.

**First-principles question:** Why would PostgreSQL prefer a sequential scan over an index scan even when an index exists?

**Task:** Run EXPLAIN on a query that matches most of the rows:

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT * FROM products WHERE price > 5.00;
"
```

Almost all prices are above 5.00 (~99% of rows), so the index does not help.

**Expected output:**
```
                       QUERY PLAN
--------------------------------------------------------
 Seq Scan on products  (cost=0.00..1193.00 rows=49750 width=87)
   Filter: (price > 5.00)
```

Even though the index exists, PostgreSQL chose Seq Scan. The cost of traversing the index + reading almost every heap page is higher than just reading all pages sequentially.

**Critical-thinking question:** What percentage of rows needs to match before PostgreSQL prefers Seq Scan over Index Scan? (There is no fixed rule — it depends on table size, page size, and the planner's cost model. Typically > 5–10% selectivity tips toward Seq Scan.)

**Creative-thinking question:** Can you force PostgreSQL to use the index anyway? (Hint: `SET enable_seqscan = off;`) What happens to the cost? Is it actually faster?

**Systems-thinking question:** Low-cardinality columns (like `category` with 8 values) are typically poor index candidates. An index on `category` would be selected only when the query is very selective (e.g., a rare category). How would you confirm this with EXPLAIN?

**What this teaches:** The query planner chooses between access paths based on estimated cost. Indexes are not always used.

---

## Exercise 4: Index on SKU — Exact Lookup

**Goal:** Create an index for exact equality lookups on the `sku` column and verify it is used.

**Task:**
1. EXPLAIN a SKU lookup without an index (to see the baseline).
2. Create an index on `sku`.
3. EXPLAIN the same query — verify Index Scan.
4. Run EXPLAIN ANALYZE to see actual vs estimated rows.

**Commands:**
```bash
# Before index
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT * FROM products WHERE sku = 'SKU-000042';
"

# Create index
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE INDEX idx_products_sku ON products (sku);
"

# After index
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN ANALYZE SELECT * FROM products WHERE sku = 'SKU-000042';
"
```

**Expected EXPLAIN ANALYZE output (with index):**
```
 Index Scan using idx_products_sku on products
   (cost=0.29..8.31 rows=1 width=87) (actual time=0.043..0.044 rows=1 loops=1)
   Index Cond: (sku = 'SKU-000042'::text)
 Planning Time: 0.234 ms
 Execution Time: 0.067 ms
```

**Critical-thinking question:** `EXPLAIN` shows estimated rows; `EXPLAIN ANALYZE` shows actual rows. If estimated = 1 and actual = 1, the statistics are accurate. When would estimated vs actual diverge significantly?

**Ontology-thinking question:** A primary key index is automatically created. Why is a separate index on `sku` still needed if `sku` is also unique? (Could you instead make `sku` the primary key or add a UNIQUE constraint? What would that do differently?)

**What this teaches:** Equality lookups on high-cardinality columns benefit greatly from an index. EXPLAIN ANALYZE adds actual timing.

---

## Exercise 5: Partial Index

**Goal:** Create a partial index that only indexes out-of-stock products.

**First-principles question:** What is a partial index? Why is it smaller and faster than a full index on the same column?

**Task:**
1. Run EXPLAIN on a query for out-of-stock products (no index exists for this pattern).
2. Create a partial index on `in_stock` where `in_stock = false`.
3. Run EXPLAIN on the same query and verify it uses the partial index.

**Commands:**
```bash
# Before partial index
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT id, sku, name FROM products WHERE in_stock = false;
"

# Create partial index
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE INDEX idx_products_out_of_stock ON products (id)
  WHERE in_stock = false;
"

# After partial index
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT id, sku, name FROM products WHERE in_stock = false;
"
```

**Expected result:** The plan changes from Seq Scan to Index Scan using the partial index.

**Critical-thinking question:** The full `in_stock` column has only 2 values (Boolean). Why is a full index on `in_stock` generally not useful, while this partial index is?

**Systems-thinking question:** In an e-commerce system, `in_stock = false` might represent only 1–5% of products. The partial index is much smaller than a full index. In what other scenarios would you use partial indexes? (Examples: active records, unconfirmed emails, pending orders.)

**What this teaches:** Partial indexes index only a subset of rows — smaller, faster, and targeted at specific query patterns.

---

## Exercise 6 (stretch): Composite Index and the Leftmost Prefix Rule

**Goal:** Create a composite index and discover which queries use it and which do not.

**Difficulty:** Stretch — only attempt after completing exercises 1–5.

**Task:**
1. Create a composite index on `(category, price)`.
2. Run EXPLAIN on three queries:
   - `WHERE category = 'Electronics'` — uses leftmost prefix
   - `WHERE category = 'Electronics' AND price < 100` — uses both columns
   - `WHERE price < 100` — does NOT use the index (skips leftmost column)
3. Compare the three plans.

**Commands:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE INDEX idx_products_cat_price ON products (category, price);
"
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT * FROM products WHERE category = 'Electronics';
  EXPLAIN SELECT * FROM products WHERE category = 'Electronics' AND price < 100;
  EXPLAIN SELECT * FROM products WHERE price < 100;
"
```

**Critical-thinking question:** The third query (price only) does not use the composite index. You already have `idx_products_price` from exercise 2. Does EXPLAIN show it using that index instead? Why?

**What this teaches:** Composite indexes follow the leftmost prefix rule — they support queries on the leading columns but not queries that skip the leftmost column.
