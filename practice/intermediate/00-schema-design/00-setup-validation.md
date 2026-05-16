# Setup Validation — Schema Design

> **Validation status**: blocked — Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled.

## How to run

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "<query>"
```

## Expected row counts

| Table | Expected rows |
|---|---|
| categories | 3 |
| customers | 3 |
| products | 4 |
| orders | 4 |
| order_items | 5 |

```sql
SELECT 'categories'  AS tbl, COUNT(*) FROM categories
UNION ALL
SELECT 'customers',         COUNT(*) FROM customers
UNION ALL
SELECT 'products',          COUNT(*) FROM products
UNION ALL
SELECT 'orders',            COUNT(*) FROM orders
UNION ALL
SELECT 'order_items',       COUNT(*) FROM order_items;
```

## Constraint checks

### UNIQUE on customers.email
```sql
-- Should raise: duplicate key value violates unique constraint "customers_email_key"
INSERT INTO customers (email, full_name) VALUES ('alice@example.com', 'Duplicate Alice');
```

### CHECK on products.price
```sql
-- Should raise: new row violates check constraint "products_price_check"
INSERT INTO products (category_id, name, sku, price) VALUES (1, 'Bad', 'X', -1.00);
```

### CHECK on orders.status
```sql
-- Should raise: new row violates check constraint "orders_status_check"
INSERT INTO orders (customer_id, status) VALUES (1, 'exploded');
```

### Generated column line_total
```sql
-- Expect line_total = 3 * 34.99 = 104.97 for order_item with order_id=3
SELECT qty, unit_price, line_total FROM order_items WHERE order_id = 3;
-- Expected: qty=3, unit_price=34.99, line_total=104.97
```

### FK cascade: deleting an order deletes its items
```sql
-- Insert a throwaway order then delete it
INSERT INTO orders (customer_id, status) VALUES (1, 'pending') RETURNING id;
-- Use the returned id:
INSERT INTO order_items (order_id, product_id, qty, unit_price) VALUES (<id>, 1, 1, 9.99);
DELETE FROM orders WHERE id = <id>;
-- Verify no orphaned items remain:
SELECT COUNT(*) FROM order_items WHERE order_id = <id>;  -- expect 0
```

## GIN index on products.attrs

```sql
-- Should use index scan (verify with EXPLAIN)
EXPLAIN SELECT * FROM products WHERE attrs @> '{"color": "black"}';
```
