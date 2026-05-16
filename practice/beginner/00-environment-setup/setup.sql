-- =============================================================================
-- Practice 00: Environment Setup — connection test
-- =============================================================================
-- This file contains no CREATE TABLE statements.
-- It runs a simple connection-test query.
-- Run with:
--   docker exec cfp_postgres psql -U cfp -d cfp -f /path/to/setup.sql
--
-- blocked: Docker not accessible; validate against cfp_postgres when available
-- =============================================================================

-- Verify connection: show server version and current database/user
SELECT
    version()              AS pg_version,
    current_database()     AS database_name,
    current_user           AS connected_user,
    now()                  AS server_time;
