-- Practice 11: Audit Triggers
-- STATUS: blocked — Docker not accessible in this session
-- Run with: docker exec cfp_postgres psql -U cfp -d cfp -f setup.sql

-- ============================================================
-- Schema
-- ============================================================

DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

CREATE TABLE customers (
    id         SERIAL PRIMARY KEY,
    name       TEXT NOT NULL,
    email      TEXT UNIQUE NOT NULL,
    tier       TEXT NOT NULL DEFAULT 'standard' CHECK (tier IN ('standard','premium','enterprise')),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    amount      NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    status      TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','processing','shipped','delivered','cancelled')),
    notes       TEXT,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- Audit log table
-- ============================================================

CREATE TABLE audit_log (
    id          BIGSERIAL PRIMARY KEY,
    table_name  TEXT NOT NULL,
    operation   TEXT NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
    record_id   TEXT,               -- the PK of the affected row (as text)
    old_data    JSONB,
    new_data    JSONB,
    changed_by  TEXT NOT NULL DEFAULT current_user,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    session_context JSONB           -- capture app.tenant_id and other session vars
);

CREATE INDEX ON audit_log (table_name, changed_at DESC);
CREATE INDEX ON audit_log (record_id);

-- ============================================================
-- Generic audit trigger function
-- ============================================================

CREATE OR REPLACE FUNCTION generic_audit_fn()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    _record_id TEXT;
    _context   JSONB;
BEGIN
    -- Extract primary key as text (works for single-column int PKs)
    _record_id := CASE TG_OP
        WHEN 'DELETE' THEN (row_to_json(OLD) ->> 'id')
        ELSE (row_to_json(NEW) ->> 'id')
    END;

    -- Capture session context
    _context := jsonb_build_object(
        'tenant_id', current_setting('app.tenant_id', TRUE),
        'application', current_setting('application_name', TRUE)
    );

    INSERT INTO audit_log (table_name, operation, record_id, old_data, new_data, session_context)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        _record_id,
        CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE row_to_json(OLD)::jsonb END,
        CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE row_to_json(NEW)::jsonb END,
        _context
    );

    RETURN NEW;
END;
$$;

-- Attach audit trigger to customers and orders
CREATE TRIGGER customers_audit
AFTER INSERT OR UPDATE OR DELETE ON customers
FOR EACH ROW EXECUTE FUNCTION generic_audit_fn();

CREATE TRIGGER orders_audit
AFTER INSERT OR UPDATE OR DELETE ON orders
FOR EACH ROW EXECUTE FUNCTION generic_audit_fn();

-- ============================================================
-- Seed data
-- ============================================================

INSERT INTO customers (name, email, tier) VALUES
    ('Alice Smith', 'alice@example.com', 'standard'),
    ('Bob Jones', 'bob@example.com', 'premium'),
    ('Charlie Corp', 'charlie@corp.example', 'enterprise');

INSERT INTO orders (customer_id, amount, status) VALUES
    (1, 99.99, 'pending'),
    (1, 249.00, 'shipped'),
    (2, 1200.00, 'delivered'),
    (3, 45000.00, 'processing');

-- Verify
SELECT 'customers' AS tbl, COUNT(*) FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'audit_log', COUNT(*) FROM audit_log;
-- audit_log should have 7 rows (3 customers + 4 orders)
