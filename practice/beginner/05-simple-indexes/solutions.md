# Solutions: Simple Indexes

Level: Beginner

Read `exercises.md` and attempt the exercises before opening this file.

---

## Solution: Exercise 1 — Read EXPLAIN Plan

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT * FROM products WHERE price < 10.00;
"
```

**Output:**
```
                          QUERY PLAN
-----------------------------------------------------------------------
 Seq Scan on products  (cost=0.00..1193.00 rows=500 width=87)
   Filter: (price < 10.00)
```

**Why this works:** No index on `price` exists. PostgreSQL's only access path is a sequential scan — read all 50,000 rows, apply the filter. The high total cost (1193) reflects reading the entire table.

**Key learning:** Seq Scan = no useful index. The cost estimate is based on `pg_class.relpages` (number of table pages) × `seq_page_cost` (default 1.0).

---

## Solution: Exercise 2 — Add Index and Compare

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE INDEX idx_products_price ON products (price);
"
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT * FROM products WHERE price < 10.00;
"
```

**Output (with index):**
```
                                    QUERY PLAN
----------------------------------------------------------------------------------
 Index Scan using idx_products_price on products  (cost=0.29..25.00 rows=500 width=87)
   Index Cond: (price < 10.00)
```

**Why this works:** The B-tree index on `price` keeps values sorted. PostgreSQL can find the boundary (price = 10.00) in the index and read only the rows on the "less than" side. Cost drops from 1193 to ~25.

**Key learning:** An index turns O(n) into O(log n). The cost improvement is dramatic for selective queries.

**Variation:** Test with a wider range:
```bash
EXPLAIN SELECT * FROM products WHERE price < 500.00;
# Likely still a Seq Scan — too many rows match (about half)
```

---

## Solution: Exercise 3 — When PostgreSQL Ignores the Index

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT * FROM products WHERE price > 5.00;
"
```

**Output:**
```
                       QUERY PLAN
--------------------------------------------------------
 Seq Scan on products  (cost=0.00..1193.00 rows=49750 width=87)
   Filter: (price > 5.00)
```

**Why this works:** Almost all rows have `price > 5.00`. Using the index would require reading ~50,000 index entries + fetching ~50,000 heap pages — more total I/O than just reading the table sequentially. The planner correctly prefers Seq Scan.

**Key learning:** The query planner chooses the cheapest plan. Indexes are not always the winner — selectivity matters.

**Force the index (demonstration only — not recommended in production):**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SET enable_seqscan = off;
  EXPLAIN SELECT * FROM products WHERE price > 5.00;
  RESET enable_seqscan;
"
```
The cost with the forced index will be higher than the Seq Scan cost — confirming the planner made the right choice.

---

## Solution: Exercise 4 — Index on SKU

```bash
# Baseline (before index)
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT * FROM products WHERE sku = 'SKU-000042';
"

# Create index
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE INDEX idx_products_sku ON products (sku);
"

# With index + actual timing
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN ANALYZE SELECT * FROM products WHERE sku = 'SKU-000042';
"
```

**Output (with EXPLAIN ANALYZE):**
```
 Index Scan using idx_products_sku on products
   (cost=0.29..8.31 rows=1 width=87) (actual time=0.043..0.045 rows=1 loops=1)
   Index Cond: (sku = 'SKU-000042'::text)
 Planning Time: 0.189 ms
 Execution Time: 0.067 ms
```

**Key learning:** Equality on a high-cardinality column (50,000 distinct SKUs) is the ideal index case — extremely selective. EXPLAIN ANALYZE adds `actual time` and `actual rows` — confirming the estimate was accurate.

---

## Solution: Exercise 5 — Partial Index

```bash
# Baseline
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT id, sku, name FROM products WHERE in_stock = false;
"

# Create partial index
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE INDEX idx_products_out_of_stock ON products (id)
  WHERE in_stock = false;
"

# With partial index
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT id, sku, name FROM products WHERE in_stock = false;
"
```

**Output (with partial index):**
```
 Index Scan using idx_products_out_of_stock on products
   (cost=0.28..25.14 rows=10000 width=...) (...)
   Index Cond: (in_stock = false)
```

**Why this works:** The partial index contains only the ~10,000 rows where `in_stock = false` (20% of the table from setup — every 5th row). The index is much smaller than a full index and is immediately useful for the common query pattern "find out-of-stock products."

**Why a full index on `in_stock` would be poor:**
A full index on a Boolean column has only 2 distinct values — every query for `in_stock = true` would match ~40,000 rows (80%), which would trigger a Seq Scan preference anyway. The partial index targets only the minority case (false = 20%), making it selective and therefore useful.

---

## Solution: Exercise 6 (stretch) — Composite Index

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE INDEX idx_products_cat_price ON products (category, price);
"

# Query 1: leftmost column only
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT * FROM products WHERE category = 'Electronics';
"

# Query 2: both columns
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT * FROM products WHERE category = 'Electronics' AND price < 100;
"

# Query 3: non-leftmost column only
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT * FROM products WHERE price < 100;
"
```

**Results:**
- Query 1: `Index Scan using idx_products_cat_price` — leftmost prefix used.
- Query 2: `Index Scan using idx_products_cat_price` — both columns used (very efficient).
- Query 3: `Index Scan using idx_products_price` (the single-column index from exercise 2) — the composite index is not used because `price` is not the leftmost column.

**Key learning:** Composite indexes support queries on the leading column(s). A query that only filters on a non-leading column must use a different index or fall back to Seq Scan.
