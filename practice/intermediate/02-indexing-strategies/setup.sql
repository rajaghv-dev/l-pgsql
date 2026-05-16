-- =============================================================
-- Stage 8 / Practice 02: Indexing Strategies
-- Target: cfp database on cfp_postgres container
-- validation: blocked — Docker not accessible;
--   re-validate against cfp_postgres when Docker Desktop WSL
--   integration is enabled
-- =============================================================

-- Clean up
DROP TABLE IF EXISTS idx_events CASCADE;

-- ---------------------------------------------------------------
-- events table: simulates a click-stream / audit log
-- ---------------------------------------------------------------
CREATE TABLE idx_events (
    id          BIGSERIAL    PRIMARY KEY,
    user_email  TEXT         NOT NULL,
    event_type  TEXT         NOT NULL,   -- 'click', 'view', 'purchase', 'logout'
    status      TEXT         NOT NULL,   -- 'processed', 'pending', 'failed'
    occurred_at TIMESTAMPTZ  NOT NULL,
    payload     JSONB                    -- variable per event_type
);

-- ---------------------------------------------------------------
-- Generate 100,000 rows
-- email: 1,000 distinct users (cycling)
-- event_type: 4 values (skewed toward 'click')
-- status: 'processed' ~90%, 'pending' ~8%, 'failed' ~2%
-- occurred_at: spread over last 365 days, inserted in time order
-- payload: varies by event_type
-- ---------------------------------------------------------------
INSERT INTO idx_events (user_email, event_type, status, occurred_at, payload)
SELECT
    'user_' || (i % 1000) || '@example.com'           AS user_email,

    CASE (i % 10)
        WHEN 0 THEN 'purchase'
        WHEN 1 THEN 'logout'
        WHEN 2 THEN 'view'
        ELSE        'click'
    END                                                AS event_type,

    CASE
        WHEN i % 50 = 0 THEN 'failed'
        WHEN i % 12 = 0 THEN 'pending'
        ELSE                 'processed'
    END                                                AS status,

    now() - (((100000 - i) || ' seconds')::interval)  AS occurred_at,

    CASE (i % 10)
        WHEN 0 THEN jsonb_build_object(
                        'product_id', (i % 200) + 1,
                        'amount',     ROUND((random() * 200 + 5)::numeric, 2),
                        'currency',   'USD')
        WHEN 1 THEN jsonb_build_object('session_duration_s', (i % 3600))
        WHEN 2 THEN jsonb_build_object('page', '/page/' || (i % 50),
                                       'referrer', 'https://example.com')
        ELSE        jsonb_build_object('element', 'btn-' || (i % 20),
                                       'page', '/page/' || (i % 50))
    END                                                AS payload

FROM generate_series(1, 100000) AS s(i);

-- Update statistics immediately after bulk load
ANALYZE idx_events;

-- ---------------------------------------------------------------
-- Checkpoint: NO INDEXES yet (except PK)
-- Exercises will add indexes step by step and observe plan changes
-- ---------------------------------------------------------------

-- Helper view: event counts by type and status
CREATE OR REPLACE VIEW idx_events_summary AS
SELECT event_type, status, COUNT(*) AS cnt
FROM idx_events
GROUP BY event_type, status
ORDER BY event_type, status;
