# Setup Validation — Practice 02: Schema and Table Basics

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Step 1 — Run setup.sql

```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < practice/beginner/02-schema-and-table-basics/setup.sql
```

Expected final output: a UNION ALL result showing 3 rows per table.

---

## Step 2 — Confirm schema exists

```sql
SELECT schema_name
FROM   information_schema.schemata
WHERE  schema_name = 'store';
```

Expected: one row with `schema_name = store`.

---

## Step 3 — Confirm tables exist in store schema

```sql
SELECT table_name
FROM   information_schema.tables
WHERE  table_schema = 'store'
  AND  table_type = 'BASE TABLE'
ORDER  BY table_name;
```

Expected: `customers`, `orders`, `products`.

---

## Step 4 — Inspect columns of store.customers

```sql
SELECT column_name, data_type, is_nullable, column_default
FROM   information_schema.columns
WHERE  table_schema = 'store' AND table_name = 'customers'
ORDER  BY ordinal_position;
```

Expected columns: `id` (bigint), `name` (text, NOT NULL), `email` (text, NOT NULL), `created_at` (timestamp with time zone, NOT NULL, DEFAULT now()).

---

## Step 5 — Confirm foreign key on orders

```sql
SELECT
    kcu.column_name   AS fk_column,
    ccu.table_name    AS references_table,
    ccu.column_name   AS references_column
FROM information_schema.table_constraints        tc
JOIN information_schema.key_column_usage         kcu ON kcu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints  rc  ON rc.constraint_name  = tc.constraint_name
JOIN information_schema.constraint_column_usage  ccu ON ccu.constraint_name = rc.unique_constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'store'
  AND tc.table_name   = 'orders';
```

Expected: `customer_id → customers.id`.

---

## Checklist

- [ ] `store` schema exists
- [ ] `customers`, `products`, `orders` tables exist in `store`
- [ ] Each table has correct columns and types
- [ ] `orders.customer_id` has a FK to `customers.id`
- [ ] Each table has 3 seed rows
