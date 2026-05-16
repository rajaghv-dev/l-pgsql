# Setup Validation — Practice 12

**Status: blocked — Docker not accessible in this session**

## pg_stat_statements setup
This extension requires `shared_preload_libraries = 'pg_stat_statements'` in postgresql.conf and a database restart. In cfp_postgres:

```bash
# Check if already loaded
docker exec cfp_postgres psql -U cfp -d cfp -c \
  "SELECT extname FROM pg_extension WHERE extname = 'pg_stat_statements';"

# If not loaded, run the setup script
# (see scripts/dashboards/enable-pg-stat-statements.sh)
```

## Validation queries

```sql
-- blocked: Docker not accessible

-- 1. pg_stat_statements is available
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_statements';

-- 2. Can query pg_stat_statements
SELECT COUNT(*) FROM pg_stat_statements;

-- 3. pg_stat_activity accessible
SELECT pid, state, LEFT(query, 50) FROM pg_stat_activity WHERE state != 'idle';

-- 4. Helper views exist
SELECT viewname FROM pg_views WHERE schemaname = 'public'
  AND viewname IN ('v_top_queries', 'v_table_health');
```
