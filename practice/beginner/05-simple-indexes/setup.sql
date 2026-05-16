-- Practice: Simple Indexes
-- Level: Beginner
-- Purpose: Products table with 50,000 generated rows. No indexes initially.
-- Run with: docker exec cfp_postgres psql -U cfp -d cfp -f /path/to/setup.sql
-- blocked: Docker not accessible; validate against cfp_postgres when available

-- ─── Tear down (idempotent re-run) ────────────────────────────────────────────
DROP TABLE IF EXISTS products CASCADE;

-- ─── Schema ───────────────────────────────────────────────────────────────────
CREATE TABLE products (
    id         SERIAL PRIMARY KEY,
    sku        TEXT NOT NULL,
    name       TEXT NOT NULL,
    category   TEXT NOT NULL,
    price      NUMERIC(10, 2) NOT NULL,
    in_stock   BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE products IS 'Synthetic product catalog for index practice.';
COMMENT ON COLUMN products.sku IS 'Stock-keeping unit — unique product identifier.';
COMMENT ON COLUMN products.category IS 'Product category — low cardinality (8 values).';
COMMENT ON COLUMN products.price IS 'Unit price in USD.';
COMMENT ON COLUMN products.in_stock IS 'True if any stock is available.';

-- ─── Generate 50,000 rows ─────────────────────────────────────────────────────
-- Uses generate_series to create synthetic data.
-- Categories: 8 distinct values (low cardinality — to demonstrate index selectivity).
-- Prices: range from 1.00 to 999.99.
-- in_stock: ~80% true (most products available).

INSERT INTO products (sku, name, category, price, in_stock, created_at)
SELECT
    'SKU-' || LPAD(i::text, 6, '0')                      AS sku,
    'Product ' || i                                        AS name,
    (ARRAY['Electronics', 'Books', 'Clothing', 'Home',
           'Sports', 'Toys', 'Food', 'Tools']
    )[(i % 8) + 1]                                         AS category,
    ROUND((RANDOM() * 998 + 1)::numeric, 2)               AS price,
    (i % 5 != 0)                                           AS in_stock,
    now() - (RANDOM() * INTERVAL '730 days')              AS created_at
FROM generate_series(1, 50000) AS i;

-- ─── Verification ─────────────────────────────────────────────────────────────
DO $$
BEGIN
    ASSERT (SELECT COUNT(*) FROM products) = 50000,
        'Expected 50000 rows in products';
    ASSERT (SELECT COUNT(DISTINCT category) FROM products) = 8,
        'Expected 8 distinct categories';
    RAISE NOTICE 'setup.sql: OK — % rows in products, % distinct categories',
        (SELECT COUNT(*) FROM products),
        (SELECT COUNT(DISTINCT category) FROM products);
END;
$$;
