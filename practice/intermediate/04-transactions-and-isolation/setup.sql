-- Practice 04: Transactions and Isolation Levels
-- STATUS: blocked — Docker not accessible in this session
-- Run with: docker exec cfp_postgres psql -U cfp -d cfp -f setup.sql

-- ============================================================
-- Schema
-- ============================================================

DROP TABLE IF EXISTS transfers CASCADE;
DROP TABLE IF EXISTS bank_accounts CASCADE;

CREATE TABLE bank_accounts (
    id          SERIAL PRIMARY KEY,
    owner       TEXT NOT NULL,
    balance     NUMERIC(12, 2) NOT NULL CHECK (balance >= 0),
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE transfers (
    id          SERIAL PRIMARY KEY,
    from_id     INT REFERENCES bank_accounts(id),
    to_id       INT REFERENCES bank_accounts(id),
    amount      NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    note        TEXT,
    created_at  TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- Seed data — synthetic accounts
-- ============================================================

INSERT INTO bank_accounts (owner, balance) VALUES
    ('Alice',   1000.00),
    ('Bob',     500.00),
    ('Charlie', 2500.00),
    ('Diana',   750.00),
    ('Eve',     0.00);

-- One initial transfer to populate the transfers table
INSERT INTO transfers (from_id, to_id, amount, note)
VALUES (1, 2, 100.00, 'initial test transfer');

-- ============================================================
-- Indexes
-- ============================================================

CREATE INDEX ON transfers (from_id);
CREATE INDEX ON transfers (to_id);
CREATE INDEX ON transfers (created_at);

-- ============================================================
-- Verify
-- ============================================================

SELECT 'bank_accounts' AS tbl, COUNT(*) FROM bank_accounts
UNION ALL
SELECT 'transfers', COUNT(*) FROM transfers;
