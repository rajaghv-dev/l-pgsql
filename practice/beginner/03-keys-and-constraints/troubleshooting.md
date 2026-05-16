# Troubleshooting — Practice 03: Keys and Constraints

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Error 1 — duplicate key value violates unique constraint

**Symptom:**
```
ERROR:  duplicate key value violates unique constraint "uq_customers_email"
DETAIL:  Key (email)=(alice@example-store.test) already exists.
```

**Cause:** Attempting to INSERT a value that already exists in a UNIQUE-constrained column.

**Fix:**
- Use `ON CONFLICT (email) DO NOTHING` for idempotent writes
- Use `ON CONFLICT (email) DO UPDATE SET ...` for upserts
- Or query first to check existence:
  ```sql
  SELECT id FROM store.customers WHERE email = 'alice@example-store.test';
  ```

---

## Error 2 — new row violates check constraint

**Symptom:**
```
ERROR:  new row for relation "products" violates check constraint "chk_products_price_pos"
DETAIL:  Failing row contains (null, Widget, WGT-999, -1.00, active, ...).
```

**Cause:** The inserted/updated value failed the CHECK expression.

**Fix:**
1. Read the constraint definition: `SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'chk_products_price_pos';`
2. Correct the value before inserting: ensure price > 0.

---

## Error 3 — violates foreign key constraint on INSERT

**Symptom:**
```
ERROR:  insert or update on table "orders" violates foreign key constraint "fk_orders_customer"
DETAIL:  Key (customer_id)=(9999) is not present in table "customers".
```

**Cause:** `customer_id = 9999` does not exist in `store.customers`.

**Fix:**
1. Verify the customer exists: `SELECT id FROM store.customers WHERE id = 9999;`
2. If not found: create the customer first, or use a valid existing customer_id.

---

## Error 4 — violates foreign key constraint on DELETE

**Symptom:**
```
ERROR:  update or delete on table "customers" violates foreign key constraint "fk_orders_customer" on table "orders"
DETAIL:  Key (id)=(1) is still referenced from table "orders".
```

**Cause:** Attempting to delete a parent row that has children (ON DELETE RESTRICT).

**Fix:**
1. Find the children: `SELECT id FROM store.orders WHERE customer_id = 1;`
2. Delete/cancel children first: `DELETE FROM store.orders WHERE customer_id = 1;`
3. Then delete the parent: `DELETE FROM store.customers WHERE id = 1;`

Or use soft-delete: `UPDATE store.customers SET deleted_at = now() WHERE id = 1;`

---

## Error 5 — check constraint is violated by some row (on ALTER)

**Symptom:**
```
ERROR:  check constraint "chk_price_positive" of relation "products" is violated by some row
```

**Cause:** Attempting to ADD a CHECK constraint to a table that already has rows violating it.

**Fix:**
1. Find violating rows: `SELECT * FROM store.products WHERE price <= 0;`
2. Fix the data: `UPDATE store.products SET price = 0.01 WHERE price <= 0;`
3. Then add the constraint.

Or use NOT VALID to skip existing row validation:
```sql
ALTER TABLE store.products
  ADD CONSTRAINT chk_price_pos CHECK (price > 0) NOT VALID;
-- Validate later (allows concurrent writes):
ALTER TABLE store.products VALIDATE CONSTRAINT chk_price_pos;
```

---

## Error 6 — there is no unique constraint matching given keys for ON CONFLICT

**Symptom:**
```
ERROR:  there is no unique constraint matching given keys for referenced table "customers"
```
(or similar for ON CONFLICT)

**Cause:** `ON CONFLICT (column)` requires the specified column to have a UNIQUE constraint or index. If no UNIQUE constraint exists on `email`, ON CONFLICT fails.

**Fix:**
```sql
-- Add the missing unique constraint
ALTER TABLE store.customers
  ADD CONSTRAINT uq_customers_email UNIQUE (email);
-- Then retry the INSERT ... ON CONFLICT (email) ...
```

---

## Error 7 — null value in column violates not-null constraint (on UPDATE)

**Symptom:**
```
ERROR:  null value in column "status" of relation "orders" violates not-null constraint
```

**Cause:** An UPDATE is setting a NOT NULL column to NULL.

```sql
UPDATE store.orders SET status = NULL WHERE id = 1;  -- fails
```

**Fix:** Provide a valid non-null value:
```sql
UPDATE store.orders SET status = 'cancelled' WHERE id = 1;
```

---

## Error 8 — cannot drop constraint: other objects depend on it

**Symptom:**
```
ERROR:  cannot drop constraint "uq_customers_email" on table "customers" because other objects depend on it
```

**Cause:** A FOREIGN KEY in another table references this UNIQUE constraint (not common, but possible with non-PK unique constraints used as FK targets).

**Fix:** Use CASCADE to drop dependent objects, or identify and drop dependencies first:
```sql
ALTER TABLE store.customers DROP CONSTRAINT uq_customers_email CASCADE;
```
