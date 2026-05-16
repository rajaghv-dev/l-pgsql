# Setup Validation: Simple Indexes

Run each check after executing `setup.sql`. All checks must pass before starting exercises.

---

## Check 1: Table exists with correct structure

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "\d products"
```

**Expected output (abbreviated):**
```
             Table "public.products"
   Column   |            Type             | ...
------------+-----------------------------+-----
 id         | integer                     |
 sku        | text                        |
 name       | text                        |
 category   | text                        |
 price      | numeric(10,2)               |
 in_stock   | boolean                     |
 created_at | timestamp with time zone    |
Indexes:
    "products_pkey" PRIMARY KEY, btree (id)
```

**Ontology note:** The only index at this point is the primary key index on `id`. This is the baseline we will compare against.

---

## Check 2: Row count is 50,000

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "SELECT COUNT(*) FROM products;"
```

**Expected output:**
```
 count
-------
 50000
```

**Common error:** Fewer rows — `generate_series` ran but an INSERT error occurred mid-way. Drop and re-run setup.sql.

---

## Check 3: No extra indexes (baseline)

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT indexname, indexdef
  FROM pg_indexes
  WHERE tablename = 'products'
  ORDER BY indexname;
"
```

**Expected output:**
```
    indexname    |                        indexdef
-----------------+---------------------------------------------------------
 products_pkey   | CREATE UNIQUE INDEX products_pkey ON products USING btree (id)
(1 row)
```

**Why this exists:** Confirms we are starting with only the PK index — future exercises add indexes and compare plans. If you see extra indexes from a previous run, drop them:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  DROP INDEX IF EXISTS idx_products_sku;
  DROP INDEX IF EXISTS idx_products_price;
  DROP INDEX IF EXISTS idx_products_category;
  DROP INDEX IF EXISTS idx_products_in_stock;
  DROP INDEX IF EXISTS idx_products_price_in_stock;
"
```

---

## Check 4: EXPLAIN shows sequential scan (before any index)

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT * FROM products WHERE price < 10.00;
"
```

**Expected output:**
```
                       QUERY PLAN
--------------------------------------------------------
 Seq Scan on products  (cost=0.00..1193.00 rows=... ...)
   Filter: (price < 10.00)
```

**Why this exists:** Confirms EXPLAIN is working and shows the unindexed baseline plan. After adding a price index in the exercises, this same query will show an Index Scan.

---

## Setup passed

If all checks above show expected output, setup is complete.
Open `exercises.md` and begin.
