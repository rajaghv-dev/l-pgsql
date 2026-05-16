-- =============================================================
-- Stage 8 / Practice 03: Query Planning with EXPLAIN
-- Target: cfp database on cfp_postgres container
-- validation: blocked — Docker not accessible;
--   re-validate against cfp_postgres when Docker Desktop WSL
--   integration is enabled
-- =============================================================

-- ---------------------------------------------------------------
-- 1. Enable pg_stat_statements (requires PostgreSQL restart if not in config)
--    On cfp_postgres, check if already enabled:
-- ---------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements'
    ) THEN
        CREATE EXTENSION pg_stat_statements;
        RAISE NOTICE 'pg_stat_statements extension created';
    ELSE
        RAISE NOTICE 'pg_stat_statements already installed';
    END IF;
END $$;

-- ---------------------------------------------------------------
-- 2. Ensure e-commerce schema exists (from Stage 7 practice 00)
--    If tables already exist this is a no-op.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categories (
    id   SERIAL PRIMARY KEY,
    name TEXT   NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS customers (
    id         SERIAL      PRIMARY KEY,
    email      TEXT        NOT NULL UNIQUE,
    full_name  TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS products (
    id          SERIAL          PRIMARY KEY,
    category_id INT             NOT NULL REFERENCES categories(id),
    name        TEXT            NOT NULL,
    sku         TEXT            NOT NULL UNIQUE,
    price       NUMERIC(10, 2)  NOT NULL CHECK (price > 0),
    attrs       JSONB,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
    id          SERIAL       PRIMARY KEY,
    customer_id INT          NOT NULL REFERENCES customers(id),
    status      TEXT         NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending','confirmed','shipped','cancelled')),
    ordered_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS order_items (
    id         SERIAL          PRIMARY KEY,
    order_id   INT             NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INT             NOT NULL REFERENCES products(id),
    qty        INT             NOT NULL CHECK (qty > 0),
    unit_price NUMERIC(10, 2)  NOT NULL CHECK (unit_price > 0),
    line_total NUMERIC(12, 2)  GENERATED ALWAYS AS (qty * unit_price) STORED,
    UNIQUE (order_id, product_id)
);

-- ---------------------------------------------------------------
-- 3. Seed e-commerce tables (if empty)
-- ---------------------------------------------------------------
INSERT INTO categories (name)
SELECT unnest(ARRAY['Books','Apparel','Electronics'])
WHERE NOT EXISTS (SELECT 1 FROM categories LIMIT 1);

INSERT INTO customers (email, full_name)
SELECT 'customer_' || i || '@shop.example.com',
       'Customer ' || i
FROM generate_series(1, 500) AS s(i)
WHERE NOT EXISTS (SELECT 1 FROM customers LIMIT 1);

INSERT INTO products (category_id, name, sku, price, attrs)
SELECT
    (i % 3) + 1,
    'Product ' || i,
    'SKU-' || LPAD(i::text, 6, '0'),
    ROUND((random() * 200 + 5)::numeric, 2),
    CASE (i % 3)
        WHEN 0 THEN jsonb_build_object('isbn', '978-' || i, 'pages', 100 + i % 500)
        WHEN 1 THEN jsonb_build_object('color', CASE i % 4 WHEN 0 THEN 'red' WHEN 1 THEN 'blue' WHEN 2 THEN 'black' ELSE 'white' END)
        ELSE        jsonb_build_object('ports', (i % 8) + 1)
    END
FROM generate_series(1, 200) AS s(i)
WHERE NOT EXISTS (SELECT 1 FROM products LIMIT 1);

-- 2000 orders
INSERT INTO orders (customer_id, status, ordered_at)
SELECT
    (i % 500) + 1,
    CASE (i % 10)
        WHEN 0 THEN 'cancelled'
        WHEN 1 THEN 'pending'
        WHEN 2 THEN 'shipped'
        ELSE        'confirmed'
    END,
    now() - ((random() * 365)::int || ' days')::interval
FROM generate_series(1, 2000) AS s(i)
WHERE NOT EXISTS (SELECT 1 FROM orders LIMIT 1);

-- order_items: 2–5 items per order
INSERT INTO order_items (order_id, product_id, qty, unit_price)
SELECT DISTINCT ON (o.id, p_id)
    o.id,
    p_id,
    (random() * 3 + 1)::int,
    (random() * 100 + 5)::numeric(10,2)
FROM orders o
CROSS JOIN LATERAL (
    SELECT (random() * 199 + 1)::int AS p_id
    FROM generate_series(1, 4)
) AS rp
WHERE NOT EXISTS (SELECT 1 FROM order_items LIMIT 1)
ON CONFLICT (order_id, product_id) DO NOTHING;

-- Remove any indexes that may already exist from prior exercises
-- (excluding PKs and unique constraints)
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN
        SELECT indexname FROM pg_indexes
        WHERE tablename IN ('orders','customers','products','order_items','idx_events')
          AND indexname NOT LIKE '%_pkey'
          AND indexname NOT LIKE '%_key'
          AND indexname NOT LIKE '%_unique%'
    LOOP
        EXECUTE 'DROP INDEX IF EXISTS ' || r.indexname;
    END LOOP;
END $$;

-- Update statistics
ANALYZE customers, products, orders, order_items;
-- idx_events should already be analyzed from practice 02

-- Reset pg_stat_statements for a clean slate
SELECT pg_stat_statements_reset();
