# Simple Store Example

Level: Beginner
Domain: Tiny product catalog with filtering, aggregation, and stock alerts
Synthetic data: Yes

## Overview

A single-table product catalog for a small fictional shop called "Maple & Pine
Goods". Teaches core SELECT mechanics: WHERE filters, ORDER BY, LIMIT, GROUP BY,
HAVING, and aggregate functions (SUM, COUNT, AVG, MIN, MAX). No joins required —
all the interesting queries run against one table.

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

CREATE TABLE products (
    id          SERIAL PRIMARY KEY,
    name        TEXT           NOT NULL CHECK (char_length(name) > 0),
    description TEXT           NOT NULL DEFAULT '',
    category    TEXT           NOT NULL,          -- e.g. 'stationery', 'kitchenware'
    price       NUMERIC(10,2)  NOT NULL CHECK (price >= 0),
    stock_qty   INT            NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    created_at  TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_products_category ON products (category);
CREATE INDEX idx_products_price     ON products (price);
```

## Seed data

```sql
INSERT INTO products (name, description, category, price, stock_qty) VALUES
  ('Recycled Notebook A5',
   'A5 notebook, 120 pages, 100% recycled cover.',
   'stationery', 4.99, 200),

  ('Ballpoint Pen Set',
   'Pack of 10 pens in assorted colours.',
   'stationery', 2.49, 350),

  ('Wooden Cutting Board',
   'Solid beech wood, 30x20cm, oiled finish.',
   'kitchenware', 18.99, 40),

  ('Ceramic Mug 350ml',
   'Dishwasher-safe ceramic mug with minimal design.',
   'kitchenware', 9.50, 85),

  ('Beeswax Wrap 3-Pack',
   'Reusable food wrap, assorted sizes.',
   'kitchenware', 12.00, 60),

  ('Linen Tote Bag',
   'Natural linen, 38x42cm, screen-printed logo.',
   'bags', 14.00, 120),

  ('Cork Wallet',
   'Slim cork-leather wallet, 4 card slots.',
   'accessories', 19.95, 30),

  ('Bamboo Toothbrush 4-Pack',
   'Soft bristles, biodegradable handle.',
   'personal-care', 7.99, 180),

  ('Lavender Soap Bar',
   'Cold-process soap, 100g, lavender essential oil.',
   'personal-care', 5.50, 5),      -- low stock

  ('Reusable Coffee Cup',
   'Double-walled stainless steel, 350ml, leak-proof lid.',
   'kitchenware', 22.00, 0),       -- out of stock

  ('Seed Paper Postcard Set',
   'Pack of 6 plantable postcards, wildflower seed blend.',
   'stationery', 6.99, 90),

  ('Organic Cotton Pouch',
   'Drawstring pouch, 15x20cm, undyed organic cotton.',
   'bags', 8.50, 75);
```

## Example queries

### Find affordable products (under £10)

```sql
SELECT name, category, price
FROM   products
WHERE  price < 10.00
ORDER  BY price ASC;
```

### Low-stock alert (fewer than 15 units)

```sql
SELECT name, category, stock_qty
FROM   products
WHERE  stock_qty < 15
ORDER  BY stock_qty ASC;
```

### Out-of-stock products

```sql
SELECT name, category
FROM   products
WHERE  stock_qty = 0;
```

### Products by category with item count and average price

```sql
SELECT category,
       COUNT(*)            AS products,
       ROUND(AVG(price), 2) AS avg_price,
       MIN(price)          AS cheapest,
       MAX(price)          AS most_expensive
FROM   products
GROUP  BY category
ORDER  BY products DESC;
```

### Top 3 most expensive products

```sql
SELECT name, category, price
FROM   products
ORDER  BY price DESC
LIMIT  3;
```

### Total inventory value

```sql
SELECT ROUND(SUM(price * stock_qty), 2) AS total_inventory_value
FROM   products;
```

### Categories with more than 2 products

```sql
SELECT category, COUNT(*) AS product_count
FROM   products
GROUP  BY category
HAVING COUNT(*) > 2
ORDER  BY product_count DESC;
```

### Search by name (ILIKE, case-insensitive)

```sql
SELECT name, price, stock_qty
FROM   products
WHERE  name ILIKE '%mug%';
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- 1. Total rows
SELECT COUNT(*) AS total_products FROM products;
-- Expected: 12

-- 2. Categories present
SELECT DISTINCT category FROM products ORDER BY category;
-- Expected: accessories, bags, kitchenware, personal-care, stationery

-- 3. Out-of-stock check
SELECT name FROM products WHERE stock_qty = 0;
-- Expected: Reusable Coffee Cup

-- 4. Low-stock (< 15) count
SELECT COUNT(*) FROM products WHERE stock_qty < 15;
-- Expected: 2 (Lavender Soap Bar, Cork Wallet)

-- 5. Indexes
SELECT indexname FROM pg_indexes WHERE tablename = 'products';
```

## Practice tasks

1. **Restock simulation.** Write an UPDATE that adds 50 units to every product
   in the `kitchenware` category. Verify with a SELECT.

2. **Budget basket.** Find all products under £10 in the `stationery` or `bags`
   category. What is the total price if you buy one of each?

3. **Category report.** Use GROUP BY to produce a table showing category,
   total stock value (price * stock_qty), and number of items. Sort by value descending.

4. **Pagination.** Return products 5–8 (using LIMIT and OFFSET) ordered alphabetically
   by name. What is the correct OFFSET value for "page 2" of 4 items per page?

5. **Price bands.** Using a CASE expression, label each product as 'budget' (< £8),
   'mid-range' (£8–£15), or 'premium' (> £15). Count how many products fall into
   each band.

## MCP and agent perspective

An agent using this catalog via MCP would:

- **Check stock before recommending** — query `stock_qty > 0` before suggesting
  a product to a customer.
- **Surface low-stock warnings** — run the low-stock alert query after each order
  to flag items that need reordering.
- **Answer price-range questions** — filter by price range to answer "what can I
  buy for under £15?".
- **Category browsing** — use GROUP BY + COUNT to give a shopper a category
  overview before they drill down.

The single-table design keeps agent queries simple — no join complexity while
still supporting realistic e-commerce tasks.

## Teardown

```sql
DROP INDEX IF EXISTS idx_products_price;
DROP INDEX IF EXISTS idx_products_category;
DROP TABLE IF EXISTS products;
```

## References

- PostgreSQL Aggregate Functions: https://www.postgresql.org/docs/current/functions-aggregate.html
- Pattern Matching (ILIKE): https://www.postgresql.org/docs/current/functions-matching.html
- NUMERIC type: https://www.postgresql.org/docs/current/datatype-numeric.html
