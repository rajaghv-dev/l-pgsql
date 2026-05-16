-- Practice 05: MVCC and Locking
-- STATUS: blocked — Docker not accessible in this session
-- Run with: docker exec cfp_postgres psql -U cfp -d cfp -f setup.sql

-- ============================================================
-- Extensions
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pageinspect;

-- ============================================================
-- Schema
-- ============================================================

DROP TABLE IF EXISTS job_queue CASCADE;
DROP TABLE IF EXISTS mvcc_demo CASCADE;
DROP TABLE IF EXISTS lock_demo CASCADE;

-- Table for demonstrating xmin/xmax and dead tuples
CREATE TABLE mvcc_demo (
    id      SERIAL PRIMARY KEY,
    name    TEXT NOT NULL,
    value   INT  NOT NULL
);

-- Table for lock contention and deadlock demos
CREATE TABLE lock_demo (
    id      SERIAL PRIMARY KEY,
    owner   TEXT NOT NULL,
    amount  NUMERIC(12, 2) NOT NULL CHECK (amount >= 0)
);

-- Task queue for SKIP LOCKED demo
CREATE TABLE job_queue (
    id          SERIAL PRIMARY KEY,
    task        TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','processing','done','failed')),
    worker_id   TEXT,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- Seed data
-- ============================================================

INSERT INTO mvcc_demo (name, value) VALUES
    ('alpha', 10), ('beta', 20), ('gamma', 30);

INSERT INTO lock_demo (owner, amount) VALUES
    ('Acct-A', 1000.00),
    ('Acct-B', 800.00),
    ('Acct-C', 600.00);

INSERT INTO job_queue (task) VALUES
    ('send-email-001'),
    ('generate-report-002'),
    ('process-payment-003'),
    ('send-email-004'),
    ('sync-inventory-005'),
    ('send-email-006'),
    ('generate-report-007'),
    ('process-payment-008');

-- ============================================================
-- Verify
-- ============================================================

SELECT 'mvcc_demo' AS tbl, COUNT(*) FROM mvcc_demo
UNION ALL
SELECT 'lock_demo', COUNT(*) FROM lock_demo
UNION ALL
SELECT 'job_queue', COUNT(*) FROM job_queue;
