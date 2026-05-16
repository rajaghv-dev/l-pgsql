# Troubleshooting: Simple Indexes

Common errors encountered in this practice session and how to fix them.

---

## Error 1: Index not used after creation (still shows Seq Scan)

**Trigger:** You create an index and run EXPLAIN — it still shows Seq Scan.

**Cause (most common):** Your query matches too many rows. The planner decides Seq Scan is cheaper. This is correct behavior, not a bug.

**Diagnosis:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT * FROM products WHERE price > 5.00;
  -- Most rows match → Seq Scan is expected
  EXPLAIN SELECT * FROM products WHERE price < 10.00;
  -- Few rows match → Index Scan expected
"
```

**Fix:** Ensure your query is selective (matches < ~5% of rows). If it is not selective, the index is not useful for this query — that is expected.

---

## Error 2: `index "idx_products_price" already exists`

**Trigger:** Running setup.sql or CREATE INDEX a second time.

**Cause:** The index was created in a previous session. setup.sql drops the TABLE (and its indexes), but if you ran CREATE INDEX manually outside setup.sql, it may still exist.

**Fix:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  DROP INDEX IF EXISTS idx_products_price;
  CREATE INDEX idx_products_price ON products (price);
"
```

Or re-run setup.sql to start fresh:
```bash
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/05-simple-indexes/setup.sql
```

---

## Error 3: EXPLAIN ANALYZE outputs actual rows = 0

**Symptom:** `(actual time=... rows=0 loops=1)` — the query ran but found nothing.

**Cause:** The SKU or value you searched for does not exist in the generated data.

**Diagnosis:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT sku FROM products LIMIT 5;
"
```

**Fix:** Use an exact SKU from the table. The setup generates SKUs as 'SKU-000001' through 'SKU-050000':
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN ANALYZE SELECT * FROM products WHERE sku = 'SKU-000001';
"
```

---

## Error 4: Partial index not used

**Symptom:** After creating `idx_products_out_of_stock WHERE in_stock = false`, the plan still shows Seq Scan.

**Cause:** Your query does not include `WHERE in_stock = false`. Partial indexes only apply when the query's WHERE matches the index's WHERE condition.

**Fix:** Ensure the query includes `WHERE in_stock = false`:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  -- This WILL use the partial index
  EXPLAIN SELECT id, sku FROM products WHERE in_stock = false;

  -- This will NOT (no in_stock filter)
  EXPLAIN SELECT id, sku FROM products WHERE price < 10.00;
"
```

---

## Error 5: EXPLAIN shows Bitmap Heap Scan instead of Index Scan

**Symptom:** EXPLAIN shows `Bitmap Index Scan` + `Bitmap Heap Scan` — not what you expected.

**Cause:** This is correct and expected for queries that match a moderate number of rows. PostgreSQL uses a bitmap to batch index lookups, then fetches heap pages. It is between Index Scan (very selective) and Seq Scan (not selective). Not an error.

**Interpretation:**
- `Bitmap Index Scan` — builds a bitmap of matching page locations using the index
- `Bitmap Heap Scan` — fetches those heap pages using the bitmap

This is more efficient than Index Scan for moderate selectivity because it fetches each heap page only once.

---

## Setup troubleshooting

**Problem:** `setup.sql` is slow (takes > 30 seconds)
**Cause:** Inserting 50,000 rows + computing RANDOM() for each row.
**Fix:** This is expected. The generation takes 5–15 seconds on typical hardware. Wait for it to complete.

**Problem:** Row count is less than 50,000
**Fix:** An INSERT error occurred mid-way. Re-run setup.sql (it drops and recreates the table).

**Problem:** Container is not running
**Fix:**
```bash
docker ps | grep cfp_postgres
docker compose -f /mnt/d/wsl/l-pgsql/tools/dashboards/docker-compose.yml up -d cfp_postgres
```
