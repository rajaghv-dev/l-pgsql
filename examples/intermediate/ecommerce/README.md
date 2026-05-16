# E-Commerce Example

Level: Intermediate
Domain: Full e-commerce model with category hierarchy, product attributes, reviews, and FTS
Synthetic data: Yes

## Overview

A realistic e-commerce schema for a fictional retailer called "Verdant Market".
Demonstrates `ltree` for hierarchical product categories, `JSONB` for flexible
product attributes, full-text search on product descriptions, and a complete
order lifecycle. An AI agent can search products, check inventory, and create
orders without needing to know the exact attribute schema.

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- Requires: ltree extension
CREATE EXTENSION IF NOT EXISTS ltree;

-- Category hierarchy using ltree
-- e.g. 'home', 'home.kitchen', 'home.kitchen.cookware'
CREATE TABLE categories (
    id      SERIAL PRIMARY KEY,
    path    LTREE  NOT NULL UNIQUE,
    label   TEXT   NOT NULL
);

CREATE INDEX idx_categories_path ON categories USING GIST (path);

-- Customers
CREATE TABLE customers (
    id          SERIAL PRIMARY KEY,
    name        TEXT   NOT NULL,
    email       TEXT   NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Products
CREATE TABLE products (
    id              SERIAL PRIMARY KEY,
    category_id     INT            REFERENCES categories(id),
    name            TEXT           NOT NULL,
    description     TEXT           NOT NULL DEFAULT '',
    price           NUMERIC(10,2)  NOT NULL CHECK (price >= 0),
    stock_qty       INT            NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    attributes      JSONB          NOT NULL DEFAULT '{}',
    -- attributes examples:
    --   {"colour": "red", "size": "M", "material": "cotton"}
    --   {"weight_g": 350, "dimensions_cm": [12, 8, 5]}
    search_vec      TSVECTOR,
    created_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_products_category   ON products (category_id);
CREATE INDEX idx_products_search_vec ON products USING GIN (search_vec);
CREATE INDEX idx_products_attributes ON products USING GIN (attributes);

-- Keep search_vec up to date
CREATE OR REPLACE FUNCTION products_search_vec_update()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.search_vec :=
        setweight(to_tsvector('english', coalesce(NEW.name,        '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.description, '')), 'B');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_products_search_vec
BEFORE INSERT OR UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION products_search_vec_update();

-- Orders
CREATE TABLE orders (
    id              SERIAL PRIMARY KEY,
    customer_id     INT            NOT NULL REFERENCES customers(id),
    status          TEXT           NOT NULL DEFAULT 'pending'
                                   CHECK (status IN ('pending','paid','shipped','cancelled')),
    total_amount    NUMERIC(10,2)  NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_customer_id ON orders (customer_id);

-- Order line items
CREATE TABLE order_items (
    id          SERIAL PRIMARY KEY,
    order_id    INT            NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id  INT            NOT NULL REFERENCES products(id),
    quantity    INT            NOT NULL CHECK (quantity > 0),
    unit_price  NUMERIC(10,2)  NOT NULL CHECK (unit_price >= 0)
);

CREATE INDEX idx_order_items_order_id   ON order_items (order_id);
CREATE INDEX idx_order_items_product_id ON order_items (product_id);

-- Product reviews
CREATE TABLE product_reviews (
    id          SERIAL PRIMARY KEY,
    product_id  INT     NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    customer_id INT     NOT NULL REFERENCES customers(id),
    rating      INT     NOT NULL CHECK (rating BETWEEN 1 AND 5),
    body        TEXT    NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (product_id, customer_id)   -- one review per customer per product
);

CREATE INDEX idx_reviews_product_id ON product_reviews (product_id);
```

## Seed data

```sql
-- Categories (ltree paths)
INSERT INTO categories (path, label) VALUES
  ('home',                        'Home'),
  ('home.kitchen',                'Kitchen'),
  ('home.kitchen.cookware',       'Cookware'),
  ('home.kitchen.appliances',     'Appliances'),
  ('home.textile',                'Textiles'),
  ('clothing',                    'Clothing'),
  ('clothing.outerwear',          'Outerwear'),
  ('clothing.basics',             'Basics'),
  ('stationery',                  'Stationery'),
  ('stationery.notebooks',        'Notebooks');

-- Customers
INSERT INTO customers (name, email) VALUES
  ('Alice Smith',   'alice@example-verdant.test'),
  ('Bob Nakamura',  'bob@example-verdant.test'),
  ('Carol Jenkins', 'carol@example-verdant.test'),
  ('David Osei',    'david@example-verdant.test'),
  ('Eve Larsson',   'eve@example-verdant.test');

-- Products (trigger sets search_vec automatically)
INSERT INTO products (category_id, name, description, price, stock_qty, attributes) VALUES
  (3, 'Cast Iron Skillet 26cm',
   'Pre-seasoned cast iron skillet. Even heat distribution. Oven safe to 260°C.',
   34.99, 45,
   '{"material": "cast iron", "diameter_cm": 26, "oven_safe": true}'),

  (3, 'Stainless Steel Saucepan 2L',
   'Tri-ply stainless steel, induction compatible, drip-free pouring rim.',
   29.50, 30,
   '{"material": "stainless steel", "capacity_l": 2, "induction": true}'),

  (4, 'Handheld Milk Frother',
   'Battery-powered frother for lattes and cappuccinos. Stainless steel whisk.',
   12.00, 80,
   '{"colour": "silver", "battery": "AA x2", "whisk_material": "stainless steel"}'),

  (5, 'Organic Linen Napkins Set of 4',
   'Stonewashed linen napkins in muted sage green. Machine washable.',
   22.00, 60,
   '{"colour": "sage green", "material": "linen", "quantity": 4, "care": "machine wash"}'),

  (7, 'Waxed Cotton Field Jacket',
   'Water-resistant waxed cotton jacket with interior map pocket. Unisex fit.',
   95.00, 20,
   '{"material": "waxed cotton", "colour": "olive", "fit": "unisex", "waterproof": true}'),

  (8, 'Merino Wool T-Shirt',
   'Lightweight 170gsm merino wool tee. Anti-odour, moisture-wicking.',
   48.00, 55,
   '{"material": "merino wool", "gsm": 170, "colours": ["navy","grey","white"]}'),

  (9, 'Recycled Paper Notebook A5',
   'A5 notebook, 192 pages, 90gsm recycled paper, thread-sewn binding.',
   9.50, 150,
   '{"size": "A5", "pages": 192, "paper_gsm": 90, "binding": "thread-sewn"}'),

  (10,'Dot-Grid Journal',
   'Hardcover dot-grid journal, 240 pages, lay-flat binding, ribbon bookmark.',
   14.00, 90,
   '{"pages": 240, "grid": "dot", "cover": "hardcover", "bookmark": true}');

-- Orders
INSERT INTO orders (customer_id, status, total_amount) VALUES
  (1, 'paid',      57.49),   -- Alice: skillet + frother
  (2, 'shipped',   95.00),   -- Bob: field jacket
  (3, 'pending',   23.50),   -- Carol: notebook + napkins partial
  (4, 'cancelled', 48.00),   -- David: merino tee (cancelled)
  (1, 'paid',      14.00);   -- Alice: dot-grid journal

-- Order items
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
  (1, 1, 1, 34.99),   -- order 1: skillet
  (1, 3, 1, 12.00),   -- order 1: frother
  (2, 5, 1, 95.00),   -- order 2: field jacket
  (3, 7, 1,  9.50),   -- order 3: notebook
  (4, 6, 1, 48.00),   -- order 4: merino tee (cancelled)
  (5, 8, 1, 14.00);   -- order 5: dot-grid journal

-- Reviews
INSERT INTO product_reviews (product_id, customer_id, rating, body) VALUES
  (1, 1, 5, 'Fantastic skillet. Seasons beautifully after a few uses.'),
  (1, 2, 4, 'Great quality, heavier than expected but worth it.'),
  (5, 2, 5, 'Jacket is superb. Kept me dry in a downpour.'),
  (7, 3, 4, 'Good paper quality. Wish it had a hardcover option.'),
  (3, 4, 3, 'Works fine but battery life is short.');
```

## Example queries

### Full-text search on products

```sql
SELECT id, name, price,
       ts_rank(search_vec, query) AS rank
FROM   products,
       plainto_tsquery('english', 'linen machine washable') AS query
WHERE  search_vec @@ query
ORDER  BY rank DESC;
```

### Find products in a category and all its subcategories (ltree)

```sql
-- All products in 'home.kitchen' and below
SELECT p.id, p.name, c.path, p.price
FROM   products  p
JOIN   categories c ON c.id = p.category_id
WHERE  c.path <@ 'home.kitchen'    -- <@ means "is descendant of"
ORDER  BY c.path, p.price;
```

### Category breadcrumb (ancestors)

```sql
-- Ancestors of 'home.kitchen.cookware'
SELECT id, path, label
FROM   categories
WHERE  'home.kitchen.cookware' ~ (path::TEXT || '.*')::lquery
   OR  path = 'home.kitchen.cookware';
```

### Products with a specific JSONB attribute

```sql
-- All products where induction = true
SELECT name, price, attributes->>'material' AS material
FROM   products
WHERE  (attributes->>'induction')::BOOLEAN = TRUE;
```

### Low-stock products

```sql
SELECT name, stock_qty
FROM   products
WHERE  stock_qty < 30
ORDER  BY stock_qty ASC;
```

### Customer order history with totals

```sql
SELECT c.name,
       COUNT(o.id)       AS order_count,
       SUM(o.total_amount) AS lifetime_spend
FROM   customers c
LEFT   JOIN orders o ON o.customer_id = c.id
GROUP  BY c.id, c.name
ORDER  BY lifetime_spend DESC NULLS LAST;
```

### Average rating and review count per product

```sql
SELECT p.name,
       COUNT(r.id)            AS review_count,
       ROUND(AVG(r.rating), 1) AS avg_rating
FROM   products      p
LEFT   JOIN product_reviews r ON r.product_id = p.id
GROUP  BY p.id, p.name
ORDER  BY avg_rating DESC NULLS LAST, review_count DESC;
```

### Order details with line items

```sql
SELECT o.id         AS order_id,
       c.name       AS customer,
       o.status,
       p.name       AS product,
       oi.quantity,
       oi.unit_price,
       oi.quantity * oi.unit_price AS line_total
FROM   orders       o
JOIN   customers    c  ON c.id  = o.customer_id
JOIN   order_items  oi ON oi.order_id  = o.id
JOIN   products     p  ON p.id  = oi.product_id
ORDER  BY o.id, p.name;
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

SELECT COUNT(*) FROM categories;       -- Expected: 10
SELECT COUNT(*) FROM customers;        -- Expected: 5
SELECT COUNT(*) FROM products;         -- Expected: 8
SELECT COUNT(*) FROM orders;           -- Expected: 5
SELECT COUNT(*) FROM order_items;      -- Expected: 6
SELECT COUNT(*) FROM product_reviews;  -- Expected: 5

-- search_vec populated by trigger
SELECT COUNT(*) FROM products WHERE search_vec IS NOT NULL;
-- Expected: 8

-- ltree path types work
SELECT path FROM categories WHERE path <@ 'home';
-- Expected: home, home.kitchen, home.kitchen.cookware, home.kitchen.appliances, home.textile
```

## Practice tasks

1. **JSONB filtering.** Find all products where `attributes->>'material'` is `'linen'`
   or `'merino wool'`. What is the combined stock quantity?

2. **Category tree.** Add a new category `'home.kitchen.bakeware'` with label
   `'Bakeware'`. Insert one product into it. Then query all products under `'home'`
   using `<@`.

3. **Order total reconciliation.** For each order, compute the sum of
   `quantity * unit_price` from `order_items` and compare it with `orders.total_amount`.
   Are there any discrepancies?

4. **Top-rated products.** Write a query that returns products with at least 2 reviews
   and an average rating of 4 or higher. Join to the category name.

5. **Inventory deduction.** Write a transaction that creates a new order for customer
   id=3, adds an order item (product_id=4, qty=2), and decrements `products.stock_qty`
   by 2. Use BEGIN/COMMIT.

## MCP and agent perspective

An AI agent shopping assistant would:

- **Search by keyword** — FTS query on `search_vec` returns ranked product matches
  for natural-language queries like "waterproof jacket".
- **Browse categories** — `ltree <@` traversal lets the agent list all products
  in a category subtree without knowing every subcategory name.
- **Filter by attribute** — JSONB `@>` queries let the agent answer "show me
  induction-compatible cookware" dynamically.
- **Place orders** — INSERT into `orders` and `order_items`, UPDATE `stock_qty`
  inside a transaction.
- **Summarise reviews** — aggregate query gives the agent a star-rating summary
  before making a recommendation.

## Teardown

```sql
DROP TABLE IF EXISTS product_reviews;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS categories;
DROP EXTENSION IF EXISTS ltree;
```

## References

- ltree extension: https://www.postgresql.org/docs/current/ltree.html
- JSONB operators: https://www.postgresql.org/docs/current/functions-json.html
- Full-Text Search: https://www.postgresql.org/docs/current/textsearch.html
- tsvector triggers: https://www.postgresql.org/docs/current/textsearch-features.html#TEXTSEARCH-UPDATE-TRIGGERS
