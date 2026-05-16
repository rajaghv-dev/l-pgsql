# Setup Validation — Constraint-Driven Design

> **Validation status**: blocked — Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled.

## Row counts

```sql
SELECT 'customers'    AS tbl, COUNT(*) FROM customers
UNION ALL
SELECT 'categories',          COUNT(*) FROM categories
UNION ALL
SELECT 'products',            COUNT(*) FROM products
UNION ALL
SELECT 'orders',              COUNT(*) FROM orders
UNION ALL
SELECT 'order_items',         COUNT(*) FROM order_items
UNION ALL
SELECT 'rooms',               COUNT(*) FROM rooms
UNION ALL
SELECT 'reservations',        COUNT(*) FROM reservations;
```

Expected: customers=4 (3 active + 1 soft-deleted), categories=3, products=3, orders=2, order_items=3, rooms=2, reservations=3.

---

## Partial unique index — email

```sql
-- Should SUCCEED: alice's old account is soft-deleted, so a new alice can register
INSERT INTO customers (email, full_name)
    VALUES ('alice@example.com', 'Alice Re-registered');
-- Verify:
SELECT id, email, full_name, deleted_at FROM customers WHERE email = 'alice@example.com';
-- Expect 3 rows: old deleted, current active, new active (if re-registration not already blocked by business logic)
-- NOTE: the partial index allows multiple rows with same email when deleted_at IS NOT NULL
```

```sql
-- Should FAIL: bob already has an active account
INSERT INTO customers (email, full_name) VALUES ('bob@example.com', 'Duplicate Bob');
-- Expected error: duplicate key value violates unique constraint "customers_active_email_idx"
```

---

## CHECK constraint — price

```sql
-- Should FAIL
INSERT INTO products (category_id, name, sku, price) VALUES (1, 'Free', 'FREE-001', 0);
-- Expected: new row violates check constraint "price_must_be_positive"
```

---

## CHECK constraint — order status

```sql
-- Should FAIL
INSERT INTO orders (customer_id, status) VALUES (1, 'exploded');
-- Expected: new row violates check constraint "valid_order_status"
```

---

## CHECK constraint — qty

```sql
-- Should FAIL
INSERT INTO order_items (order_id, product_id, qty, unit_price) VALUES (1, 2, 0, 9.99);
-- Expected: new row violates check constraint "qty_must_be_positive"
```

---

## EXCLUDE constraint — overlapping reservations

```sql
-- Should FAIL: Conference Room A is already booked 09:00–11:00
INSERT INTO reservations (room_id, guest, during)
    VALUES (1, 'Eve', '[2026-06-01 10:00, 2026-06-01 12:00)');
-- Expected: conflicting key value violates exclusion constraint "no_overlapping_reservations"
```

```sql
-- Should SUCCEED: same time but different room
INSERT INTO reservations (room_id, guest, during)
    VALUES (2, 'Eve', '[2026-06-01 13:00, 2026-06-01 14:00)');
```

---

## DEFERRABLE FK — order_items

```sql
-- Should SUCCEED: insert order_items referencing a not-yet-committed order
-- (demonstrates DEFERRABLE INITIALLY DEFERRED behavior)
BEGIN;
  -- Insert the item first (order 999 doesn't exist yet — FK deferred)
  INSERT INTO order_items (order_id, product_id, qty, unit_price)
      VALUES (999, 1, 1, 39.99);
  -- Now insert the order
  INSERT INTO orders (id, customer_id, status)
      VALUES (999, 1, 'pending');
COMMIT;  -- FK check happens here — should pass

-- Cleanup
DELETE FROM order_items WHERE order_id = 999;
DELETE FROM orders WHERE id = 999;
```

---

## Inspect constraints via catalog

```sql
SELECT conname, contype, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'products'::regclass
ORDER BY contype;
```
