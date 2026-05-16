# Troubleshooting — Schema Design

---

## Error: relation "X" does not exist

**Cause**: Running a query before `setup.sql` has been executed, or the schema was dropped.

**Fix**:
```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < setup.sql
```

---

## Error: duplicate key value violates unique constraint "customers_email_key"

**Cause**: Attempting to insert a customer with an email that already exists.

**Fix**: Check existing emails first:
```sql
SELECT email FROM customers;
```

---

## Error: insert or update on table "orders" violates foreign key constraint

**Cause**: Referencing a `customer_id` that does not exist in `customers`.

**Fix**: Insert the customer first, then the order.

---

## Error: new row violates check constraint "products_price_check"

**Cause**: Inserting a product with `price <= 0`.

**Fix**: Ensure price is a positive number. Prices of exactly 0 are also rejected (use `price >= 0` in the constraint if free products are valid for your domain).

---

## Generated column error: cannot insert into column "line_total"

**Cause**: Attempting to set `line_total` explicitly in an INSERT or UPDATE.

**Fix**: Remove `line_total` from your column list. It is managed by PostgreSQL.
```sql
-- Wrong:
INSERT INTO order_items (order_id, product_id, qty, unit_price, line_total) VALUES ...;
-- Correct:
INSERT INTO order_items (order_id, product_id, qty, unit_price) VALUES ...;
```

---

## JSONB query returning no rows unexpectedly

**Cause**: JSONB containment operator `@>` is case-sensitive and type-sensitive.

**Fix**: Match the exact JSON type. `'{"pages": 286}'` (integer) differs from `'{"pages": "286"}'` (string).
```sql
-- Correct for integer value:
SELECT * FROM products WHERE attrs @> '{"pages": 286}';
-- Wrong if stored as integer:
SELECT * FROM products WHERE attrs @> '{"pages": "286"}';
```

---

## EXPLAIN not showing index scan on attrs column

**Cause**: Table is small (< ~1000 rows); PostgreSQL chooses seq scan because it's cheaper.

**Fix**: This is correct behavior. To force index usage for demonstration:
```sql
SET enable_seqscan = off;
EXPLAIN SELECT * FROM products WHERE attrs @> '{"color": "black"}';
SET enable_seqscan = on;  -- always reset
```

---

## Window function syntax error in Exercise 2

**Cause**: `SUM(...) OVER (PARTITION BY ...)` syntax is unfamiliar.

**Fix**: Window functions require `OVER (PARTITION BY ...)`. They cannot be used in WHERE clauses. Use a subquery or CTE if you need to filter on the window result.

---

## ON DELETE CASCADE not working

**Cause**: The FK may have been defined without CASCADE, or the delete is on the child table (CASCADE only goes from parent → child).

**Fix**: Check the FK definition:
```sql
SELECT pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'order_items'::regclass AND contype = 'f';
```
