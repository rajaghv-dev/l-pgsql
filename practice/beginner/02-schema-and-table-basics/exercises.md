# Exercises — Practice 02: Schema and Table Basics

Run `setup.sql` before starting.

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Exercise 1 — List all tables in the store schema

**Goal:** Use `information_schema` to list tables with their row counts.

**SQL:**
```sql
SELECT
    t.table_name,
    pg_size_pretty(pg_total_relation_size(quote_ident(t.table_schema) || '.' || quote_ident(t.table_name))) AS size
FROM information_schema.tables t
WHERE t.table_schema = 'store'
  AND t.table_type   = 'BASE TABLE'
ORDER BY t.table_name;
```

**Expected result:** Three rows: `customers`, `orders`, `products` with their sizes.

**Agent/MCP angle:** This is schema discovery. An agent connecting to an unknown database would run queries like this to map the available tables before writing any SQL.

---

## Exercise 2 — Describe a table using information_schema

**Goal:** Show all columns of `store.products` with their types and defaults.

**SQL:**
```sql
SELECT
    column_name,
    data_type,
    character_maximum_length,
    numeric_precision,
    numeric_scale,
    is_nullable,
    column_default
FROM   information_schema.columns
WHERE  table_schema = 'store'
  AND  table_name   = 'products'
ORDER  BY ordinal_position;
```

**Expected result:** Columns: id, name, sku, price, created_at with their types.

**Agent/MCP angle:** An agent must know column types before constructing INSERT/UPDATE statements. This is the programmatic equivalent of `\d tablename` in psql.

---

## Exercise 3 — CREATE a new table in the store schema

**Goal:** Create a `store.reviews` table for product reviews.

**SQL:**
```sql
CREATE TABLE IF NOT EXISTS store.reviews (
    id          BIGSERIAL     PRIMARY KEY,
    product_id  BIGINT        NOT NULL REFERENCES store.products(id) ON DELETE CASCADE,
    customer_id BIGINT        NOT NULL REFERENCES store.customers(id) ON DELETE SET NULL,
    rating      INTEGER       NOT NULL,
    body        TEXT,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);
```

**Expected result:** `CREATE TABLE`

**Note:** After creating, confirm with:
```sql
\d store.reviews
```

**Agent/MCP angle:** Creating tables programmatically with `IF NOT EXISTS` is safe for agent-driven setup scripts — they can be re-run without failure.

---

## Exercise 4 — ADD COLUMN to an existing table

**Goal:** Add a `phone` column to `store.customers`.

**SQL:**
```sql
ALTER TABLE store.customers
  ADD COLUMN IF NOT EXISTS phone VARCHAR(20);
```

**Expected result:** `ALTER TABLE`

**Verify:**
```sql
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema = 'store' AND table_name = 'customers'
ORDER BY ordinal_position;
```

**Agent/MCP angle:** Schema evolution (adding columns) should always use `ADD COLUMN IF NOT EXISTS` in scripts, making them safe to re-run.

---

## Exercise 5 — RENAME a column

**Goal:** Rename `store.customers.phone` to `store.customers.phone_number`.

**SQL:**
```sql
ALTER TABLE store.customers
  RENAME COLUMN phone TO phone_number;
```

**Expected result:** `ALTER TABLE`

**Note:** `RENAME COLUMN` does not have an `IF EXISTS` option — check first:
```sql
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'store' AND table_name = 'customers' AND column_name = 'phone';
```

**Agent/MCP angle:** Column renaming is a breaking change for queries that reference the old name. Agents should check for dependent views or functions before renaming.

---

## Exercise 6 — Query pg_catalog directly

**Goal:** Use `pg_class` to list relations in the store schema by type.

**SQL:**
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

**relkind values:** `r` = ordinary table, `i` = index, `S` = sequence

**Expected result:** Tables, their indexes, and sequences for the store schema.

**Agent/MCP angle:** `pg_catalog` is lower-level than `information_schema` but more complete. Agents that need size, OID, or internal metadata use `pg_catalog`.

---

## Exercise 7 — ALTER TABLE: change column type

**Goal:** Widen `store.products.sku` from `VARCHAR(20)` to `VARCHAR(30)`.

**SQL:**
```sql
ALTER TABLE store.products
  ALTER COLUMN sku TYPE VARCHAR(30);
```

**Expected result:** `ALTER TABLE`

**Note:** Widening VARCHAR is always safe. Narrowing can fail if existing data exceeds the new limit. Changing between incompatible types (TEXT to INTEGER) requires a USING clause.

**Agent/MCP angle:** Type changes require careful pre-checking. An agent should query existing data to confirm no rows violate the new type before attempting the change.

---

## Exercise 8 — DROP TABLE with safety

**Goal:** Drop the `store.reviews` table created in Exercise 3.

**SQL:**
```sql
DROP TABLE IF EXISTS store.reviews;
```

**Expected result:** `DROP TABLE`

**Verify it's gone:**
```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'store' AND table_name = 'reviews';
```

Expected: 0 rows.

**Agent/MCP angle:** `IF EXISTS` prevents errors when the table has already been dropped (important for idempotent cleanup scripts). An agent managing schema lifecycle must track what it has created.
