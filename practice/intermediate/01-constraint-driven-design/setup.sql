-- =============================================================
-- Stage 7 / Practice 01: Constraint-Driven Design
-- Target: cfp database on cfp_postgres container
-- validation: blocked — Docker not accessible;
--   re-validate against cfp_postgres when Docker Desktop WSL
--   integration is enabled
-- =============================================================

-- Clean up
DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS rooms        CASCADE;
DROP TABLE IF EXISTS order_items  CASCADE;
DROP TABLE IF EXISTS orders       CASCADE;
DROP TABLE IF EXISTS products     CASCADE;
DROP TABLE IF EXISTS categories   CASCADE;
DROP TABLE IF EXISTS customers    CASCADE;

-- Required for EXCLUDE constraint
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------------------------------------------------------------
-- customers — soft-delete pattern
--   email must be unique among active (non-deleted) customers only
-- ---------------------------------------------------------------
CREATE TABLE customers (
    id         SERIAL       PRIMARY KEY,
    email      TEXT         NOT NULL,
    full_name  TEXT         NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ            -- NULL = active; non-NULL = soft-deleted

    -- No UNIQUE constraint here — we use a partial unique index instead
    -- (see below) so deleted customers don't block re-registration.
);

-- Partial unique index: email must be unique only among active customers
CREATE UNIQUE INDEX customers_active_email_idx
    ON customers(email)
    WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------
-- categories
-- ---------------------------------------------------------------
CREATE TABLE categories (
    id   SERIAL PRIMARY KEY,
    name TEXT   NOT NULL UNIQUE
);

-- ---------------------------------------------------------------
-- products — price must be positive; sku must be globally unique
-- ---------------------------------------------------------------
CREATE TABLE products (
    id          SERIAL          PRIMARY KEY,
    category_id INT             NOT NULL
                    REFERENCES categories(id) ON DELETE RESTRICT,
    name        TEXT            NOT NULL,
    sku         TEXT            NOT NULL,
    price       NUMERIC(10, 2)  NOT NULL
                    CONSTRAINT price_must_be_positive CHECK (price > 0),
    attrs       JSONB,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT products_sku_unique UNIQUE (sku)
);

-- ---------------------------------------------------------------
-- orders — status is a closed set of values
-- ---------------------------------------------------------------
CREATE TABLE orders (
    id          SERIAL       PRIMARY KEY,
    customer_id INT          NOT NULL
                    REFERENCES customers(id) ON DELETE RESTRICT,
    status      TEXT         NOT NULL DEFAULT 'pending'
                    CONSTRAINT valid_order_status
                    CHECK (status IN ('pending','confirmed','shipped','cancelled')),
    ordered_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------
-- order_items — FK to orders is deferred (useful for batch inserts)
-- ---------------------------------------------------------------
CREATE TABLE order_items (
    id          SERIAL          PRIMARY KEY,
    order_id    INT             NOT NULL,
    product_id  INT             NOT NULL
                    REFERENCES products(id) ON DELETE RESTRICT,
    qty         INT             NOT NULL
                    CONSTRAINT qty_must_be_positive CHECK (qty > 0),
    unit_price  NUMERIC(10, 2)  NOT NULL
                    CONSTRAINT unit_price_must_be_positive CHECK (unit_price > 0),
    line_total  NUMERIC(12, 2)  GENERATED ALWAYS AS (qty * unit_price) STORED,

    CONSTRAINT order_items_order_fk
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED,

    CONSTRAINT one_product_per_order UNIQUE (order_id, product_id)
);

-- ---------------------------------------------------------------
-- Booking sub-system: rooms and reservations
--   EXCLUDE prevents overlapping reservations for the same room
-- ---------------------------------------------------------------
CREATE TABLE rooms (
    id   SERIAL PRIMARY KEY,
    name TEXT   NOT NULL UNIQUE,
    capacity INT NOT NULL CHECK (capacity > 0)
);

CREATE TABLE reservations (
    id        SERIAL       PRIMARY KEY,
    room_id   INT          NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    guest     TEXT         NOT NULL,
    during    TSRANGE      NOT NULL,

    CONSTRAINT no_overlapping_reservations
        EXCLUDE USING GIST (room_id WITH =, during WITH &&)
);

-- Indexes
CREATE INDEX ON orders       (customer_id);
CREATE INDEX ON order_items  (order_id);
CREATE INDEX ON order_items  (product_id);
CREATE INDEX ON reservations (room_id);

-- ---------------------------------------------------------------
-- Seed data
-- ---------------------------------------------------------------
INSERT INTO categories (name) VALUES ('Books'), ('Apparel'), ('Electronics');

INSERT INTO customers (email, full_name) VALUES
    ('alice@example.com',   'Alice Patel'),
    ('bob@example.com',     'Bob Martínez'),
    ('charlie@example.com', 'Charlie Kim');

-- Simulate a soft-deleted customer (same email as alice, now deleted)
INSERT INTO customers (email, full_name, deleted_at) VALUES
    ('alice@example.com', 'Old Alice Account', now() - interval '30 days');

INSERT INTO products (category_id, name, sku, price, attrs) VALUES
    (1, 'PostgreSQL: Up & Running', 'BOOK-PG-001', 39.99,
        '{"isbn":"978-1491963418","pages":286}'),
    (2, 'Developer Hoodie',         'APP-HOOD-BLK', 59.99,
        '{"color":"black"}'),
    (3, 'USB-C Hub 7-port',         'ELEC-HUB-7P', 49.99,
        '{"ports":7}');

INSERT INTO orders (customer_id, status) VALUES
    (1, 'confirmed'),
    (2, 'pending');

INSERT INTO order_items (order_id, product_id, qty, unit_price) VALUES
    (1, 1, 2, 39.99),
    (1, 3, 1, 49.99),
    (2, 2, 1, 59.99);

INSERT INTO rooms (name, capacity) VALUES
    ('Conference Room A', 10),
    ('Meeting Room B', 4);

INSERT INTO reservations (room_id, guest, during) VALUES
    (1, 'Alice Patel',  '[2026-06-01 09:00, 2026-06-01 11:00)'),
    (1, 'Bob Martínez', '[2026-06-01 13:00, 2026-06-01 15:00)'),
    (2, 'Charlie Kim',  '[2026-06-01 09:00, 2026-06-01 10:00)');
