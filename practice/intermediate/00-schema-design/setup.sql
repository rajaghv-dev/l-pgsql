-- =============================================================
-- Stage 7 / Practice 00: Schema Design — E-Commerce Order System
-- Target: cfp database on cfp_postgres container
-- validation: blocked — Docker not accessible;
--   re-validate against cfp_postgres when Docker Desktop WSL
--   integration is enabled
-- =============================================================

-- Clean up previous runs
DROP TABLE IF EXISTS order_items  CASCADE;
DROP TABLE IF EXISTS orders       CASCADE;
DROP TABLE IF EXISTS products     CASCADE;
DROP TABLE IF EXISTS categories   CASCADE;
DROP TABLE IF EXISTS customers    CASCADE;

-- ---------------------------------------------------------------
-- 1. customers
-- ---------------------------------------------------------------
CREATE TABLE customers (
    id         SERIAL       PRIMARY KEY,
    email      TEXT         NOT NULL UNIQUE,
    full_name  TEXT         NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------
-- 2. categories  (normalizes product category name)
-- ---------------------------------------------------------------
CREATE TABLE categories (
    id   SERIAL PRIMARY KEY,
    name TEXT   NOT NULL UNIQUE
);

-- ---------------------------------------------------------------
-- 3. products
--    attrs JSONB handles variable per-category attributes
--    (e.g., {"color":"red","size":"M"} for apparel;
--           {"isbn":"978-...","pages":320} for books)
-- ---------------------------------------------------------------
CREATE TABLE products (
    id          SERIAL          PRIMARY KEY,
    category_id INT             NOT NULL REFERENCES categories(id),
    name        TEXT            NOT NULL,
    sku         TEXT            NOT NULL UNIQUE,
    price       NUMERIC(10, 2)  NOT NULL CHECK (price > 0),
    attrs       JSONB,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------
-- 4. orders
-- ---------------------------------------------------------------
CREATE TABLE orders (
    id          SERIAL       PRIMARY KEY,
    customer_id INT          NOT NULL REFERENCES customers(id),
    status      TEXT         NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending','confirmed','shipped','cancelled')),
    ordered_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------
-- 5. order_items  (M:N between orders and products, with qty/price)
--    unit_price captured at order time (prices may change later)
--    line_total is a generated column — controlled denormalization
-- ---------------------------------------------------------------
CREATE TABLE order_items (
    id          SERIAL          PRIMARY KEY,
    order_id    INT             NOT NULL REFERENCES orders(id)   ON DELETE CASCADE,
    product_id  INT             NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    qty         INT             NOT NULL CHECK (qty > 0),
    unit_price  NUMERIC(10, 2)  NOT NULL CHECK (unit_price > 0),
    line_total  NUMERIC(12, 2)  GENERATED ALWAYS AS (qty * unit_price) STORED,
    UNIQUE (order_id, product_id)
);

-- Indexes to support common queries
CREATE INDEX ON orders       (customer_id);
CREATE INDEX ON orders       (status);
CREATE INDEX ON order_items  (order_id);
CREATE INDEX ON order_items  (product_id);
CREATE INDEX ON products     USING GIN (attrs);

-- ---------------------------------------------------------------
-- Seed data
-- ---------------------------------------------------------------
INSERT INTO categories (name) VALUES
    ('Books'),
    ('Apparel'),
    ('Electronics');

INSERT INTO customers (email, full_name) VALUES
    ('alice@example.com',   'Alice Patel'),
    ('bob@example.com',     'Bob Martínez'),
    ('charlie@example.com', 'Charlie Kim');

INSERT INTO products (category_id, name, sku, price, attrs) VALUES
    (1, 'PostgreSQL: Up & Running', 'BOOK-PG-001', 39.99,
        '{"isbn":"978-1491963418","pages":286,"author":"Regina Obe"}'),
    (2, 'Developer Hoodie',         'APP-HOOD-BLK', 59.99,
        '{"color":"black","sizes":["S","M","L","XL"]}'),
    (3, 'USB-C Hub 7-port',         'ELEC-HUB-7P', 49.99,
        '{"ports":7,"max_watts":100}'),
    (1, 'Learning SQL',             'BOOK-SQL-002', 34.99,
        '{"isbn":"978-0596520830","pages":344,"author":"Alan Beaulieu"}');

INSERT INTO orders (customer_id, status) VALUES
    (1, 'confirmed'),
    (1, 'shipped'),
    (2, 'pending'),
    (3, 'cancelled');

INSERT INTO order_items (order_id, product_id, qty, unit_price) VALUES
    (1, 1, 1, 39.99),
    (1, 3, 2, 49.99),
    (2, 2, 1, 59.99),
    (3, 4, 3, 34.99),
    (4, 1, 1, 39.99);
