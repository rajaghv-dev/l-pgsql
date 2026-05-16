# Troubleshooting — Practice 02: Schema and Table Basics

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Error 1 — schema "store" does not exist

**Symptom:**
```
ERROR:  schema "store" does not exist
LINE 1: CREATE TABLE store.customers (...)
```

**Cause:** The schema was not created before the table, or `CREATE SCHEMA IF NOT EXISTS store` was skipped.

**Fix:** Run setup.sql from the beginning, which creates the schema before any tables:
```sql
CREATE SCHEMA IF NOT EXISTS store;
```

---

## Error 2 — table "store.orders" depends on table "store.customers"

**Symptom:**
```
ERROR:  cannot drop table store.customers because other objects depend on it
DETAIL:  constraint orders_customer_id_fkey on table store.orders depends on table store.customers
```

**Cause:** Attempting to `DROP TABLE store.customers` while `store.orders` has a foreign key referencing it.

**Fix (safe):** Drop the child table first, then the parent:
```sql
DROP TABLE IF EXISTS store.orders;
DROP TABLE IF EXISTS store.customers;
```

**Fix (nuclear):** Drop with CASCADE — also drops the FK constraint on orders:
```sql
DROP TABLE store.customers CASCADE;
```

---

## Error 3 — column "if" does not exist (IF NOT EXISTS typo)

**Symptom:**
```
ERROR:  syntax error at or near "NOT"
```

**Cause:** Typo in the ALTER TABLE syntax. `ADD COLUMN IF NOT EXISTS` is only valid in PostgreSQL 9.6+. Older syntax: `ADD COLUMN` (without IF NOT EXISTS).

**Fix:**
```sql
-- Correct (PostgreSQL 9.6+)
ALTER TABLE store.customers ADD COLUMN IF NOT EXISTS phone VARCHAR(20);

-- If the version is older:
-- First check if column exists, then add only if not present
```

---

## Error 4 — cannot alter type of column used by an index

**Symptom:**
```
ERROR:  column "sku" cannot be cast automatically to type integer
```

**Cause:** Attempting to change a column type to an incompatible type (e.g. VARCHAR to INTEGER) without a USING clause.

**Fix:**
```sql
-- Provide a USING clause with the conversion expression
ALTER TABLE store.products
  ALTER COLUMN year TYPE TEXT USING year::TEXT;
```

---

## Error 5 — permission denied for schema store

**Symptom:**
```
ERROR:  permission denied for schema store
```

**Cause:** The connected user (`cfp`) does not have USAGE or CREATE privilege on the `store` schema.

**Fix (as superuser):**
```sql
GRANT USAGE  ON SCHEMA store TO cfp;
GRANT CREATE ON SCHEMA store TO cfp;
```

In this repo, the `cfp` user owns the `cfp` database, so this should not occur. Check if the schema was created by a different user.

---

## Error 6 — relation "store.customers" already exists

**Symptom:**
```
ERROR:  relation "customers" already exists
```

**Cause:** Running a CREATE TABLE without `IF NOT EXISTS` when the table already exists.

**Fix:** Always use `IF NOT EXISTS` in setup scripts:
```sql
CREATE TABLE IF NOT EXISTS store.customers (...);
```

---

## Error 7 — column "phone" of relation "customers" does not exist (when renaming)

**Symptom:**
```
ERROR:  column "phone" of relation "customers" does not exist
```

**Cause:** The column was already renamed in a previous run of the exercise, or it was never added.

**Fix:** Check the current column names:
```sql
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'store' AND table_name = 'customers'
ORDER BY ordinal_position;
```

---

## Error 8 — null value in column violates not-null constraint (when adding NOT NULL column)

**Symptom:**
```
ERROR:  column "phone_verified" of relation "customers" contains null values
```

**Cause:** Adding a `NOT NULL` column without a DEFAULT to a table that already has rows.

**Fix:** Either provide a DEFAULT:
```sql
ALTER TABLE store.customers ADD COLUMN phone_verified BOOLEAN NOT NULL DEFAULT false;
```

Or follow the multi-step pattern: add nullable → backfill → add NOT NULL constraint.
