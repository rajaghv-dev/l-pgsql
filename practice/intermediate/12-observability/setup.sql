-- Practice 12: Observability with pg_stat_statements
-- STATUS: blocked — Docker not accessible in this session
-- Run with: docker exec cfp_postgres psql -U cfp -d cfp -f setup.sql
--
-- Note: pg_stat_statements requires shared_preload_libraries setup.
-- See: scripts/dashboards/enable-pg-stat-statements.sh

-- ============================================================
-- Enable extensions
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- ============================================================
-- Observability helper view — top queries by total time
-- ============================================================

CREATE OR REPLACE VIEW v_top_queries AS
SELECT
    queryid,
    calls,
    ROUND(total_exec_time::numeric, 2)   AS total_ms,
    ROUND(mean_exec_time::numeric, 2)    AS mean_ms,
    ROUND((100 * total_exec_time / NULLIF(SUM(total_exec_time) OVER (), 0))::numeric, 1) AS pct_total,
    rows,
    shared_blks_hit,
    shared_blks_read,
    ROUND(
        100.0 * shared_blks_hit / NULLIF(shared_blks_hit + shared_blks_read, 0),
        1
    )                                    AS cache_hit_pct,
    LEFT(query, 100)                     AS query_snippet
FROM pg_stat_statements
WHERE query NOT ILIKE '%pg_stat_statements%'
ORDER BY total_exec_time DESC;

-- ============================================================
-- Observability helper view — table health
-- ============================================================

CREATE OR REPLACE VIEW v_table_health AS
SELECT
    relname AS table_name,
    n_live_tup,
    n_dead_tup,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
    last_autovacuum::date,
    last_autoanalyze::date,
    seq_scan,
    idx_scan,
    ROUND(100.0 * idx_scan / NULLIF(seq_scan + idx_scan, 0), 1) AS idx_scan_pct
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- ============================================================
-- Workload generator — to populate pg_stat_statements
-- ============================================================
-- Run these queries after setup to create interesting stats

-- (Run several times to build up call counts)
-- SELECT * FROM customers WHERE id = 1;
-- SELECT * FROM orders WHERE status = 'pending' ORDER BY created_at;
-- SELECT SUM(amount) FROM orders GROUP BY status;
-- SELECT c.name, COUNT(o.id), SUM(o.amount) FROM customers c LEFT JOIN orders o ON c.id = o.customer_id GROUP BY c.name;

SELECT 'pg_stat_statements' AS ext,
       COUNT(*) AS tracked_queries
FROM pg_stat_statements;
