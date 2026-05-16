-- =============================================================================
-- Practice 03: Keys and Constraints — setup.sql
-- Idempotent: safe to run multiple times
-- Drops and recreates the store schema with full constraints
-- =============================================================================
-- Run with:
--   docker exec -i cfp_postgres psql -U cfp -d cfp < practice/beginner/03-keys-and-constraints/setup.sql
--
-- blocked: Docker not accessible; validate against cfp_postgres when available
-- =============================================================================

-- Drop and recreate to ensure a clean constrained state
-- (Practice 02 may have left partially constrained tables)
DROP TABLE IF EXISTS store.orders    CASCADE;
DROP TABLE IF EXISTS store.products  CASCADE;
DROP TABLE IF EXISTS store.customers CASCADE;

-- Recreate schema (idempotent)
CREATE SCHEMA IF NOT EXISTS store;

-- =============================================================================
-- store.customers — with NOT NULL and UNIQUE on email
-- =============================================================================
CREATE TABLE store.customers (
    id         BIGSERIAL    PRIMARY KEY,
    name       TEXT         NOT NULL,
    email      TEXT         NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_customers_email UNIQUE (email)
);

-- =============================================================================
-- store.products — with UNIQUE on sku, CHECK on price and status
-- =============================================================================
CREATE TABLE store.products (
    id         BIGSERIAL      PRIMARY KEY,
    name       TEXT           NOT NULL,
    sku        VARCHAR(20)    NOT NULL,
    price      NUMERIC(10,2)  NOT NULL,
    status     TEXT           NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ    NOT NULL DEFAULT now(),

    CONSTRAINT uq_products_sku           UNIQUE (sku),
    CONSTRAINT chk_products_price_pos    CHECK  (price > 0),
    CONSTRAINT chk_products_status_valid CHECK  (status IN ('active', 'discontinued', 'draft'))
);

-- =============================================================================
-- store.orders — with FK to customers, CHECK on status
-- =============================================================================
CREATE TABLE store.orders (
    id          BIGSERIAL   PRIMARY KEY,
    customer_id BIGINT      NOT NULL,
    status      TEXT        NOT NULL DEFAULT 'pending',
    ordered_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
        REFERENCES store.customers(id) ON DELETE RESTRICT,
    CONSTRAINT chk_orders_status_valid CHECK (status IN ('pending', 'completed', 'cancelled'))
);

-- Index FK column (not automatic)
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON store.orders (customer_id);

-- =============================================================================
-- Seed data (synthetic only)
-- =============================================================================
INSERT INTO store.customers (id, name, email) VALUES
    (1, 'Alice Andersson', 'alice@example-store.test'),
    (2, 'Bob Bjornsson',   'bob@example-store.test'),
    (3, 'Carol Carlsson',  'carol@example-store.test')
ON CONFLICT (id) DO NOTHING;

INSERT INTO store.products (id, name, sku, price, status) VALUES
    (1, 'Widget Pro',   'WGT-001', 29.99, 'active'),
    (2, 'Gadget Basic', 'GDG-001',  9.99, 'active'),
    (3, 'Old Thing',    'OLD-001',  4.99, 'discontinued')
ON CONFLICT (id) DO NOTHING;

INSERT INTO store.orders (id, customer_id, status) VALUES
    (1, 1, 'completed'),
    (2, 2, 'pending'),
    (3, 1, 'pending')
ON CONFLICT (id) DO NOTHING;

-- Reset sequences
SELECT setval(pg_get_serial_sequence('store.customers', 'id'), (SELECT MAX(id) FROM store.customers));
SELECT setval(pg_get_serial_sequence('store.products',  'id'), (SELECT MAX(id) FROM store.products));
SELECT setval(pg_get_serial_sequence('store.orders',    'id'), (SELECT MAX(id) FROM store.orders));

-- Confirm constraints
SELECT
    conname        AS constraint_name,
    contype        AS type,
    conrelid::regclass AS on_table
FROM   pg_constraint
WHERE  conrelid IN (
    'store.customers'::regclass,
    'store.products'::regclass,
    'store.orders'::regclass
)
ORDER  BY on_table, contype;
