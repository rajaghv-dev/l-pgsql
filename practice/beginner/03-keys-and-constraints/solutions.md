# Solutions — Practice 03: Keys and Constraints

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Exercise 1 — PRIMARY KEY violation and recovery

**Will fail:**
```sql
INSERT INTO store.customers (id, name, email)
VALUES (1, 'Duplicate Alice', 'newalice@example-store.test');
-- ERROR: duplicate key value violates unique constraint "customers_pkey"
```

**Recovery (correct INSERT):**
```sql
INSERT INTO store.customers (name, email)
VALUES ('New Customer', 'newcust@example-store.test')
RETURNING id, name, email;
```

**Explanation:** Omitting `id` lets BIGSERIAL generate the next sequence value. The sequence was reset in setup.sql to `MAX(id) + 1`, so it will assign id=4 (or higher if other inserts occurred). Primary key values never need to be manually specified for surrogate keys.

---

## Exercise 2 — NOT NULL violation

**Will fail:**
```sql
INSERT INTO store.customers (name)
VALUES ('No Email Customer');
-- ERROR: null value in column "email" ... violates not-null constraint
```

**Explanation:** The `email` column is declared `NOT NULL`. Not supplying a value is equivalent to supplying NULL. PostgreSQL rejects this before the row is written. The correct fix is always to supply the required value:

```sql
INSERT INTO store.customers (name, email)
VALUES ('No Email Customer', 'noemail@example-store.test')
RETURNING id, name;
```

**Distinguishing NULL from empty string:** `''` (empty string) is NOT NULL — it is a valid value. If you want to also prevent empty strings, add a CHECK:
```sql
CONSTRAINT chk_email_nonempty CHECK (length(trim(email)) > 0)
```

---

## Exercise 3 — UNIQUE violation and ON CONFLICT

**Part A — will fail:**
```sql
INSERT INTO store.customers (name, email)
VALUES ('Alice Again', 'alice@example-store.test');
-- ERROR: duplicate key value violates unique constraint "uq_customers_email"
```

**Part B — ON CONFLICT DO NOTHING:**
```sql
INSERT INTO store.customers (name, email)
VALUES ('Alice Again', 'alice@example-store.test')
ON CONFLICT (email) DO NOTHING;
-- Returns 0 rows — silently skipped
```

**Part C — ON CONFLICT DO UPDATE (upsert):**
```sql
INSERT INTO store.customers (name, email)
VALUES ('Alice Updated', 'alice@example-store.test')
ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name
RETURNING id, name, email;
```

**Explanation of EXCLUDED:** `EXCLUDED` is a special pseudo-table that holds the values from the attempted INSERT. `EXCLUDED.name` = 'Alice Updated'. The UPDATE sets `customers.name = 'Alice Updated'` for the conflicting row.

**When to use each:**
- `DO NOTHING` — idempotent writes, retry safety
- `DO UPDATE` — upsert: "insert if new, update if exists"
- Neither (let it fail) — when a duplicate is a programming error

---

## Exercise 4 — CHECK violations

**Negative price (will fail):**
```sql
INSERT INTO store.products (name, sku, price)
VALUES ('Broken Widget', 'BRK-001', -5.00);
-- ERROR: new row for relation "products" violates check constraint "chk_products_price_pos"
```

**Invalid status (will fail):**
```sql
INSERT INTO store.products (name, sku, price, status)
VALUES ('Draft Widget', 'DFT-001', 10.00, 'ACTIVE');
-- ERROR: ... violates check constraint "chk_products_status_valid"
```

**Correct INSERT:**
```sql
INSERT INTO store.products (name, sku, price, status)
VALUES ('Draft Widget', 'DFT-001', 10.00, 'active')
RETURNING id, name, status;
```

**Making the status check case-insensitive:**
```sql
CONSTRAINT chk_products_status_valid CHECK (lower(status) IN ('active', 'discontinued', 'draft'))
```

This way `'ACTIVE'`, `'Active'`, and `'active'` all pass.

---

## Exercise 5 — FK violation: invalid parent

**Will fail:**
```sql
INSERT INTO store.orders (customer_id, status)
VALUES (9999, 'pending');
-- ERROR: insert or update on table "orders" violates foreign key constraint "fk_orders_customer"
-- DETAIL: Key (customer_id)=(9999) is not present in table "customers".
```

**Safe agent pattern — verify parent before inserting:**
```sql
DO $$
DECLARE
    v_customer_id BIGINT := 9999;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM store.customers WHERE id = v_customer_id) THEN
        RAISE EXCEPTION 'Customer % does not exist', v_customer_id;
    END IF;
    INSERT INTO store.orders (customer_id) VALUES (v_customer_id);
END $$;
```

**Or in application code:** query the customer first, handle the 0-rows case before issuing the INSERT.

---

## Exercise 6 — FK violation: RESTRICT on delete

**Will fail:**
```sql
DELETE FROM store.customers WHERE id = 1;
-- ERROR: update or delete on table "customers" violates foreign key constraint "fk_orders_customer" on table "orders"
-- DETAIL: Key (id)=(1) is still referenced from table "orders".
```

**Correct multi-step deletion:**
```sql
-- First, cancel or delete the child records
DELETE FROM store.orders WHERE customer_id = 1;
-- Then, delete the parent
DELETE FROM store.customers WHERE id = 1;
```

**Or, soft-delete instead of hard-delete:**
```sql
-- Add a deleted_at column (if not already there)
ALTER TABLE store.customers ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- "Delete" by timestamping
UPDATE store.customers SET deleted_at = now() WHERE id = 1;

-- Query active customers only
SELECT * FROM store.customers WHERE deleted_at IS NULL;
```

Soft-delete preserves order history and referential integrity.

---

## Exercise 7 — ADD CHECK constraint

```sql
ALTER TABLE store.orders
  ADD CONSTRAINT chk_orders_customer_id_positive CHECK (customer_id > 0);
```

**Verification:**
```sql
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM   pg_constraint
WHERE  conrelid = 'store.orders'::regclass AND contype = 'c';
```

**Explanation:** Adding a CHECK to an existing table validates every existing row immediately. If any row fails (e.g. `customer_id = 0`), the ALTER fails with:
```
ERROR: check constraint "chk_orders_customer_id_positive" of relation "orders" is violated by some row
```

**For large tables — use NOT VALID then validate separately:**
```sql
-- Add without immediate validation
ALTER TABLE store.orders
  ADD CONSTRAINT chk_orders_customer_id_positive
  CHECK (customer_id > 0) NOT VALID;

-- Validate separately (uses a weaker lock, allows concurrent writes)
ALTER TABLE store.orders
  VALIDATE CONSTRAINT chk_orders_customer_id_positive;
```

---

## Exercise 8 — Full constraint report

```sql
SELECT
    conrelid::regclass         AS table_name,
    conname                    AS constraint_name,
    CASE contype
        WHEN 'p' THEN 'PRIMARY KEY'
        WHEN 'u' THEN 'UNIQUE'
        WHEN 'c' THEN 'CHECK'
        WHEN 'f' THEN 'FOREIGN KEY'
        ELSE contype::text
    END                        AS type,
    pg_get_constraintdef(oid)  AS definition
FROM   pg_constraint
WHERE  conrelid IN (
    'store.customers'::regclass,
    'store.products'::regclass,
    'store.orders'::regclass
)
ORDER  BY table_name, type, constraint_name;
```

**Explanation:**
- `pg_constraint` is the raw catalog table for all constraints
- `conrelid::regclass` casts the OID to a schema-qualified table name
- `pg_get_constraintdef(oid)` reconstructs the constraint definition as SQL text
- NOT NULL is stored per-attribute in `pg_attribute.attnotnull`, not in `pg_constraint` — that is why it does not appear in this list

**NOT NULL constraints via pg_attribute:**
```sql
SELECT attname, attnotnull
FROM   pg_attribute
WHERE  attrelid = 'store.customers'::regclass
  AND  attnum > 0  -- exclude system columns
ORDER  BY attnum;
```
