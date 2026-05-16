-- =============================================================================
-- Practice 02: Schema and Table Basics — setup.sql
-- Idempotent: safe to run multiple times
-- =============================================================================
-- Run with:
--   docker exec -i cfp_postgres psql -U cfp -d cfp < practice/beginner/02-schema-and-table-basics/setup.sql
--
-- blocked: Docker not accessible; validate against cfp_postgres when available
-- =============================================================================

-- Create the store schema
CREATE SCHEMA IF NOT EXISTS store;

-- Customers table
CREATE TABLE IF NOT EXISTS store.customers (
    id         BIGSERIAL   PRIMARY KEY,
    name       TEXT        NOT NULL,
    email      TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Products table
CREATE TABLE IF NOT EXISTS store.products (
    id         BIGSERIAL      PRIMARY KEY,
    name       TEXT           NOT NULL,
    sku        VARCHAR(20)    NOT NULL,
    price      NUMERIC(10,2)  NOT NULL,
    created_at TIMESTAMPTZ    NOT NULL DEFAULT now()
);

-- Orders table
CREATE TABLE IF NOT EXISTS store.orders (
    id          BIGSERIAL   PRIMARY KEY,
    customer_id BIGINT      NOT NULL REFERENCES store.customers(id) ON DELETE RESTRICT,
    status      TEXT        NOT NULL DEFAULT 'pending',
    ordered_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed: customers (ON CONFLICT DO NOTHING for idempotency)
INSERT INTO store.customers (id, name, email) VALUES
    (1, 'Alice Andersson',  'alice@example-store.test'),
    (2, 'Bob Bjornsson',    'bob@example-store.test'),
    (3, 'Carol Carlsson',   'carol@example-store.test')
ON CONFLICT (id) DO NOTHING;

-- Seed: products
INSERT INTO store.products (id, name, sku, price) VALUES
    (1, 'Widget Pro',    'WGT-001', 29.99),
    (2, 'Gadget Basic',  'GDG-001',  9.99),
    (3, 'Thingamajig',   'TMJ-001', 49.99)
ON CONFLICT (id) DO NOTHING;

-- Seed: orders
INSERT INTO store.orders (id, customer_id, status) VALUES
    (1, 1, 'completed'),
    (2, 2, 'pending'),
    (3, 1, 'pending')
ON CONFLICT (id) DO NOTHING;

-- Reset sequences
SELECT setval(pg_get_serial_sequence('store.customers', 'id'), (SELECT MAX(id) FROM store.customers));
SELECT setval(pg_get_serial_sequence('store.products',  'id'), (SELECT MAX(id) FROM store.products));
SELECT setval(pg_get_serial_sequence('store.orders',    'id'), (SELECT MAX(id) FROM store.orders));

-- Confirm setup
SELECT 'store.customers' AS tbl, COUNT(*) FROM store.customers
UNION ALL
SELECT 'store.products',         COUNT(*) FROM store.products
UNION ALL
SELECT 'store.orders',           COUNT(*) FROM store.orders;
