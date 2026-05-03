#!/usr/bin/env bash
# Enable pg_stat_statements in cfp_postgres.
# Requires a container restart. Run once, then bring dashboards up.

set -euo pipefail

CONTAINER=cfp_postgres
PSQL="docker exec $CONTAINER psql -U cfp -d cfp"

echo "==> Enabling pg_stat_statements in shared_preload_libraries..."
$PSQL -c "ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';"

echo "==> Restarting $CONTAINER..."
docker restart "$CONTAINER"

echo "==> Waiting for PostgreSQL to be ready..."
until docker exec "$CONTAINER" pg_isready -U cfp -d cfp -q; do
  sleep 1
done

echo "==> Creating pg_stat_statements extension..."
$PSQL -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

echo "==> Verifying..."
$PSQL -c "SELECT count(*) AS tracked_queries FROM pg_stat_statements;"

echo "DONE — pg_stat_statements is active."
