# Exercises — Practice 03: Keys and Constraints

Run `setup.sql` before starting. Each exercise intentionally triggers a constraint or demonstrates how to work with one.

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Exercise 1 — Trigger a PRIMARY KEY violation

**Goal:** See what happens when you try to INSERT a row with a duplicate primary key.

**SQL (will fail):**
```sql
INSERT INTO store.customers (id, name, email)
VALUES (1, 'Duplicate Alice', 'newalice@example-store.test');
```

**Expected error:**
```
ERROR:  duplicate key value violates unique constraint "customers_pkey"
DETAIL:  Key (id)=(1) already exists.
```

**Recovery:** Do not specify `id` — let BIGSERIAL assign it:
```sql
INSERT INTO store.customers (name, email)
VALUES ('New Customer', 'newcust@example-store.test')
RETURNING id, name, email;
```

**Agent/MCP angle:** An agent should never specify an explicit `id` on INSERT unless it has a UUID strategy. Always let the database assign surrogate keys.

---

## Exercise 2 — Trigger a NOT NULL violation

**Goal:** Attempt to insert a customer without a required field.

**SQL (will fail):**
```sql
INSERT INTO store.customers (name)
VALUES ('No Email Customer');
```

**Expected error:**
```
ERROR:  null value in column "email" of relation "customers" violates not-null constraint
DETAIL:  Failing row contains (6, No Email Customer, null, ...).
```

**Agent/MCP angle:** The error message names the column. An agent can parse `pg_constraint.conname` or the error string to identify which field is missing and prompt for it.

---

## Exercise 3 — Trigger a UNIQUE violation and recover with ON CONFLICT

**Goal 1:** See the UNIQUE violation error. **Goal 2:** Use `ON CONFLICT DO NOTHING` to skip duplicates gracefully.

**SQL — part A (will fail):**
```sql
INSERT INTO store.customers (name, email)
VALUES ('Alice Again', 'alice@example-store.test');
```

**Expected error:**
```
ERROR:  duplicate key value violates unique constraint "uq_customers_email"
DETAIL:  Key (email)=(alice@example-store.test) already exists.
```

**SQL — part B (succeeds silently):**
```sql
INSERT INTO store.customers (name, email)
VALUES ('Alice Again', 'alice@example-store.test')
ON CONFLICT (email) DO NOTHING;
```

**SQL — part C (upsert: update on conflict):**
```sql
INSERT INTO store.customers (name, email)
VALUES ('Alice Updated', 'alice@example-store.test')
ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name
RETURNING id, name, email;
```

**Agent/MCP angle:** Agents writing data should use `ON CONFLICT DO NOTHING` for idempotent writes, or `ON CONFLICT DO UPDATE` for upserts. This avoids errors on retry.

---

## Exercise 4 — Trigger a CHECK violation

**Goal:** Attempt to insert a product with a negative price and with an invalid status.

**SQL (will fail — negative price):**
```sql
INSERT INTO store.products (name, sku, price)
VALUES ('Broken Widget', 'BRK-001', -5.00);
```

**Expected error:**
```
ERROR:  new row for relation "products" violates check constraint "chk_products_price_pos"
DETAIL:  Failing row contains (7, Broken Widget, BRK-001, -5.00, active, ...).
```

**SQL (will fail — invalid status):**
```sql
INSERT INTO store.products (name, sku, price, status)
VALUES ('Draft Widget', 'DFT-001', 10.00, 'ACTIVE');
```

**Expected error:**
```
ERROR:  new row for relation "products" violates check constraint "chk_products_status_valid"
```

**Note:** `'ACTIVE'` (uppercase) fails because the CHECK uses case-sensitive comparison.

**Agent/MCP angle:** An agent should normalize status values to lowercase before INSERT. Alternatively, a more robust constraint would use `lower(status) IN (...)`.

---

## Exercise 5 — Trigger a FK violation: insert child with invalid parent

**Goal:** Attempt to create an order referencing a non-existent customer.

**SQL (will fail):**
```sql
INSERT INTO store.orders (customer_id, status)
VALUES (9999, 'pending');
```

**Expected error:**
```
ERROR:  insert or update on table "orders" violates foreign key constraint "fk_orders_customer"
DETAIL:  Key (customer_id)=(9999) is not present in table "customers".
```

**Agent/MCP angle:** Before creating child records, an agent should verify the parent exists:
```sql
SELECT id FROM store.customers WHERE id = 9999;
-- If no rows returned, abort and report the missing parent.
```

---

## Exercise 6 — Trigger a FK violation: delete parent with children

**Goal:** Attempt to delete a customer who has orders (ON DELETE RESTRICT).

**SQL (will fail):**
```sql
DELETE FROM store.customers WHERE id = 1;
```

**Expected error:**
```
ERROR:  update or delete on table "customers" violates foreign key constraint "fk_orders_customer" on table "orders"
DETAIL:  Key (id)=(1) is still referenced from table "orders".
```

**Correct approach — cancel or complete orders first:**
```sql
-- Cancel Alice's pending orders before deleting her
UPDATE store.orders SET status = 'cancelled' WHERE customer_id = 1 AND status = 'pending';
-- Now soft-delete (preferred over hard delete for order history)
-- Or delete the orders and then the customer:
DELETE FROM store.orders WHERE customer_id = 1;
DELETE FROM store.customers WHERE id = 1;
```

**Agent/MCP angle:** RESTRICT is the safest default. An agent encountering this error must decide: cancel orders, reassign them, or block the customer deletion.

---

## Exercise 7 — Add a new constraint to an existing table

**Goal:** Add a CHECK constraint to ensure `store.orders.customer_id` is always positive (defense in depth alongside the FK).

**SQL:**
```sql
ALTER TABLE store.orders
  ADD CONSTRAINT chk_orders_customer_id_positive CHECK (customer_id > 0);
```

**Expected result:** `ALTER TABLE`

**Verify:**
```sql
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM   pg_constraint
WHERE  conrelid = 'store.orders'::regclass AND contype = 'c';
```

**Note:** Adding a CHECK to an existing table with data validates ALL existing rows. If any row fails, the ALTER fails.

**Agent/MCP angle:** When an agent adds constraints post-hoc, it should first run:
```sql
SELECT COUNT(*) FROM store.orders WHERE customer_id <= 0;
```
If the count is non-zero, the constraint will fail and must be addressed first.

---

## Exercise 8 — List all constraints with definitions

**Goal:** Produce a full constraint report for the store schema.

**SQL:**
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

**Expected result:** A complete list of all constraints across the three tables.

**Agent/MCP angle:** This query is the agent's "schema audit" — it reveals all enforced rules. Before writing a complex migration, an agent would run this to understand what rules it must preserve or update.
