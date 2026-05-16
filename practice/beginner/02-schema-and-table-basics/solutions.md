# Solutions — Practice 02: Schema and Table Basics

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Exercise 1 — List all tables in the store schema

```sql
SELECT
    t.table_name,
    pg_size_pretty(pg_total_relation_size(
        quote_ident(t.table_schema) || '.' || quote_ident(t.table_name)
    )) AS size
FROM information_schema.tables t
WHERE t.table_schema = 'store'
  AND t.table_type   = 'BASE TABLE'
ORDER BY t.table_name;
```

**Explanation:**
- `pg_total_relation_size` includes the table + all its indexes and TOAST
- `quote_ident` safely quotes identifiers to handle reserved words or unusual names
- `information_schema.tables` is the standard SQL view; works across database systems

**Alternative using pg_catalog (PostgreSQL-specific, but simpler):**
```sql
SELECT relname, pg_size_pretty(pg_total_relation_size(oid)) AS size
FROM   pg_class
WHERE  relnamespace = 'store'::regnamespace AND relkind = 'r'
ORDER  BY relname;
```

---

## Exercise 2 — Describe a table

```sql
SELECT
    column_name, data_type, character_maximum_length,
    numeric_precision, numeric_scale, is_nullable, column_default
FROM   information_schema.columns
WHERE  table_schema = 'store' AND table_name = 'products'
ORDER  BY ordinal_position;
```

**Explanation:**
- `ordinal_position` preserves the order columns were defined
- `data_type` uses SQL standard type names (e.g. `character varying` instead of `VARCHAR`)
- `numeric_precision` and `numeric_scale` are populated for NUMERIC types, NULL for TEXT

**psql shorthand:** `\d store.products` — shows constraints too.

---

## Exercise 3 — CREATE store.reviews

```sql
CREATE TABLE IF NOT EXISTS store.reviews (
    id          BIGSERIAL   PRIMARY KEY,
    product_id  BIGINT      NOT NULL REFERENCES store.products(id)  ON DELETE CASCADE,
    customer_id BIGINT      NOT NULL REFERENCES store.customers(id) ON DELETE SET NULL,
    rating      INTEGER     NOT NULL,
    body        TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**Explanation:**
- `ON DELETE CASCADE` on `product_id`: if a product is deleted, its reviews go too
- `ON DELETE SET NULL` on `customer_id`: if a customer is deleted, the review stays but the author becomes anonymous
- `body TEXT` with no `NOT NULL` — review body is optional
- `rating INTEGER` with no CHECK yet — Exercise 3 in practice/03 will add that constraint

---

## Exercise 4 — ADD COLUMN

```sql
ALTER TABLE store.customers
  ADD COLUMN IF NOT EXISTS phone VARCHAR(20);
```

**Explanation:**
- `IF NOT EXISTS` (PostgreSQL 9.6+) makes this safe to re-run
- Adding a nullable column (no NOT NULL, no DEFAULT) is an instant metadata-only operation in PostgreSQL — no table rewrite needed
- Adding a NOT NULL column with no DEFAULT requires a full table scan to check existing rows — use `DEFAULT 'value'` to make it fast

**Fast pattern for adding a NOT NULL column to a large table:**
```sql
-- Step 1: add as nullable
ALTER TABLE store.customers ADD COLUMN phone_verified BOOLEAN;
-- Step 2: backfill
UPDATE store.customers SET phone_verified = false WHERE phone_verified IS NULL;
-- Step 3: add NOT NULL
ALTER TABLE store.customers ALTER COLUMN phone_verified SET NOT NULL;
```

---

## Exercise 5 — RENAME COLUMN

```sql
ALTER TABLE store.customers
  RENAME COLUMN phone TO phone_number;
```

**Explanation:**
- This is a metadata-only operation — instant, no row rewrite
- Any views, functions, or application queries that reference `phone` will break immediately
- To check for dependencies before renaming:

```sql
SELECT dependent_ns.nspname, dependent_view.relname
FROM   pg_depend
JOIN   pg_rewrite    ON pg_depend.objid = pg_rewrite.oid
JOIN   pg_class      AS dependent_view ON pg_rewrite.ev_class = dependent_view.oid
JOIN   pg_namespace  AS dependent_ns   ON dependent_ns.oid = dependent_view.relnamespace
JOIN   pg_attribute  ON pg_depend.refobjid = pg_attribute.attrelid
                     AND pg_depend.refobjsubid = pg_attribute.attnum
WHERE  pg_attribute.attname = 'phone'
  AND  pg_depend.refobjid = 'store.customers'::regclass;
```

---

## Exercise 6 — Query pg_catalog

```sql
SELECT
    c.relname   AS name,
    c.relkind   AS kind,
    pg_size_pretty(pg_relation_size(c.oid)) AS size
FROM   pg_class     c
JOIN   pg_namespace n ON n.oid = c.relnamespace
WHERE  n.nspname = 'store'
ORDER  BY c.relkind, c.relname;
```

**Explanation:**
- `pg_class` holds all relations: tables (`r`), indexes (`i`), sequences (`S`), views (`v`), etc.
- `pg_namespace` maps namespace OID to name
- `pg_relation_size` returns the size of just the main relation file (not indexes)

Each BIGSERIAL column creates a sequence. So `customers_id_seq`, `products_id_seq`, `orders_id_seq` should appear as `S` rows.

---

## Exercise 7 — ALTER COLUMN TYPE

```sql
ALTER TABLE store.products
  ALTER COLUMN sku TYPE VARCHAR(30);
```

**Explanation:**
- Safe because VARCHAR(30) is wider than VARCHAR(20) — all existing values fit
- PostgreSQL validates this at ALTER time — if any existing row had a 25-char SKU, narrowing to VARCHAR(20) would fail

**For type changes that require data conversion:**
```sql
ALTER TABLE store.products
  ALTER COLUMN year TYPE TEXT USING year::TEXT;
-- The USING clause provides the conversion expression
```

---

## Exercise 8 — DROP TABLE IF EXISTS

```sql
DROP TABLE IF EXISTS store.reviews;
```

**Explanation:**
- `IF EXISTS` prevents an error if the table does not exist — essential for re-runnable scripts
- `DROP TABLE` without CASCADE will fail if another table has a FK referencing this one
- `DROP TABLE store.reviews CASCADE` would also drop dependent FKs — use carefully

**Drop a schema and all its contents:**
```sql
DROP SCHEMA IF EXISTS store CASCADE;
-- Use with extreme caution — deletes all tables, data, functions in the schema
```
