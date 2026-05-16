# Solutions — Schema Design

> validation: blocked — Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

---

## Exercise 1: Entity-relationship diagram

```
customers (1) ──FK──< orders (1) ──FK──< order_items >──FK── products
                                                              │
categories (1) ──FK──────────────────────────────────────────┘
```

| Relationship | Cardinality | FK location | ON DELETE |
|---|---|---|---|
| customers → orders | 1:N | orders.customer_id | RESTRICT (default) |
| orders → order_items | 1:N | order_items.order_id | CASCADE |
| products → order_items | 1:N (products side) / M:N overall | order_items.product_id | RESTRICT |
| categories → products | 1:N | products.category_id | RESTRICT (default) |

The `order_items` table is the junction/resolution table for the M:N between `orders` and `products`, augmented with `qty` and `unit_price`.

---

## Exercise 2: Query across all tables

```sql
SELECT
    c.full_name,
    o.id           AS order_id,
    o.status,
    p.name         AS product_name,
    oi.qty,
    oi.line_total,
    SUM(oi.line_total) OVER (PARTITION BY o.id) AS order_grand_total
FROM orders o
JOIN customers   c  ON c.id  = o.customer_id
JOIN order_items oi ON oi.order_id = o.id
JOIN products    p  ON p.id  = oi.product_id
WHERE o.status IN ('confirmed', 'shipped')
ORDER BY c.full_name, o.id;
```

Note: `SUM(...) OVER (PARTITION BY o.id)` is a window function — it adds the grand total to every row for that order without collapsing rows.

---

## Exercise 3: Normalization violations

**a) Violations:**
- **3NF** (transitive dependency): `customer_name` depends on `order_id → customer_id → customer_name`, not directly on `order_id`. Similarly for `category_name` depending on `product_name`.
- **2NF**: If `(order_id, product_name)` were used as a composite key, `customer_name` would depend only on `order_id`, not the full key.

**b) Anomalies:**
- **Update anomaly**: If customer "Alice Patel" changes her name, every row in `orders_flat` with her orders must be updated. Miss one and the data is inconsistent.
- **Insertion anomaly**: You cannot record a new customer until they place at least one order (you need an order_id to insert).
- **Deletion anomaly**: Deleting the only order for a customer destroys all knowledge of that customer's name.

**c) How `setup.sql` avoids them:**
- Customer name lives only in `customers.full_name`. Orders reference `customer_id`. No duplication.
- A customer can exist without an order.
- Deleting an order does not delete the customer.

---

## Exercise 4: Denormalization debate

**a)** `unit_price` in `order_items` is correct because product prices change over time. If `order_items` referenced `products.price` via FK, updating a product's price would retroactively change historical order totals — a major business integrity problem. Capturing price at order time is deliberate snapshot denormalization.

**b)** Yes. `unit_price` in `order_items` is a copy of `products.price` at a specific moment. It is controlled, documented denormalization with a clear business reason (historical accuracy).

**c)** Example: a generated `vat_amount` column:
```sql
-- Assuming 20% VAT stored as a constant
ALTER TABLE order_items
    ADD COLUMN vat_amount NUMERIC(12,2)
        GENERATED ALWAYS AS (line_total * 0.20) STORED;
```

---

## Exercise 5: Many-to-many product tags

**a)** M:N — one product can have many tags; one tag can apply to many products.

**b)** Junction table implementation:
```sql
CREATE TABLE tags (
    id    SERIAL PRIMARY KEY,
    label TEXT   NOT NULL UNIQUE
);

CREATE TABLE product_tags (
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    tag_id     INT NOT NULL REFERENCES tags(id)     ON DELETE CASCADE,
    PRIMARY KEY (product_id, tag_id)
);

CREATE INDEX ON product_tags (tag_id);  -- supports "all products for a tag"
```

**c)** Query for "bestseller" products:
```sql
SELECT p.name
FROM products p
JOIN product_tags pt ON pt.product_id = p.id
JOIN tags t          ON t.id = pt.tag_id
WHERE t.label = 'bestseller';
```

**d)** Array alternative:
```sql
ALTER TABLE products ADD COLUMN tags TEXT[];
CREATE INDEX ON products USING GIN (tags);
-- Query:
SELECT name FROM products WHERE 'bestseller' = ANY(tags);
```
Gains: simpler query, no junction table, no JOIN.
Loses: no FK integrity (can store tags that don't exist), no CASCADE on tag deletion, harder to query "all products for a tag" without scanning all products.

---

## Exercise 6: Schema evolution — shipping address

| Criterion | Option A (5 cols) | Option B (JSONB) | Option C (addresses table) |
|---|---|---|---|
| `WHERE country = 'US'` | Simple indexed column | `WHERE shipping_address->>'country' = 'US'` (indexable with expression index) | JOIN to addresses, then filter |
| Enforce country present | `NOT NULL` constraint | `CHECK ((shipping_address ? 'country'))` | NOT NULL on addresses.country |
| Add new field later | ALTER TABLE (migration) | No migration needed | ALTER TABLE addresses |
| **Recommended** | | | |

**Recommendation**: Option A for a stable, well-known address format with regulatory requirements (you may need to index/report on country, state). Option B if addresses are genuinely variable (international formats differ widely). Option C only if addresses are reused across entities (customers, warehouses, suppliers).

For an e-commerce order system: **Option A** — known fields, need for filtering, clear NOT NULL requirements.

---

## Exercise 7: Cardinality error fix

**a)** Storing `category_name TEXT` violates 3NF: `category_name` is a property of `categories`, not of the product-category association. It creates a transitive dependency.

**b)** If the "Electronics" category is renamed to "Tech", every row in `products_categories` with `category_name = 'Electronics'` must be updated. Miss any row and the data is inconsistent.

**c)** Correct DDL:
```sql
CREATE TABLE products_categories (
    product_id  INT NOT NULL REFERENCES products(id)    ON DELETE CASCADE,
    category_id INT NOT NULL REFERENCES categories(id)  ON DELETE RESTRICT,
    PRIMARY KEY (product_id, category_id)
);
```
(Though in `setup.sql`, we use a simpler single-category design with `products.category_id` — this DDL would be for a multi-category design.)

---

## Exercise 8: Analytical queries

**Customer with highest total spend:**
```sql
SELECT c.full_name, SUM(oi.line_total) AS total_spent
FROM customers c
JOIN orders o      ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
GROUP BY c.id, c.full_name
ORDER BY total_spent DESC
LIMIT 1;
```

**Product in most orders:**
```sql
SELECT p.name, COUNT(DISTINCT oi.order_id) AS order_count
FROM products p
JOIN order_items oi ON oi.product_id = p.id
GROUP BY p.id, p.name
ORDER BY order_count DESC
LIMIT 1;
```

**Average order value:**
```sql
SELECT ROUND(AVG(order_total), 2) AS avg_order_value
FROM (
    SELECT order_id, SUM(line_total) AS order_total
    FROM order_items
    GROUP BY order_id
) AS order_totals;
```
