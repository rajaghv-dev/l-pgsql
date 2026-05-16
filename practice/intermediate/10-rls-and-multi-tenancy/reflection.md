# Reflection — RLS and Multi-Tenancy

## Key takeaways
- RLS moves tenant isolation from application code into the database engine — it cannot be bypassed by application bugs or direct psql sessions.
- Always use `FORCE ROW LEVEL SECURITY` for tenant-scoped tables.
- `SET LOCAL app.tenant_id = '...'` within transactions is the standard context-passing pattern.
- Always index the `tenant_id` column — the RLS filter runs on every query and needs the index.
- Use `current_setting('app.tenant_id', TRUE)` (lenient mode) to avoid errors when context is not set.

## Architecture pattern
```
Application request
  → Extract tenant JWT / session token
  → Acquire DB connection
  → BEGIN
  → SET LOCAL app.tenant_id = '<id>'
  → Execute queries (all auto-filtered by RLS)
  → COMMIT / ROLLBACK
  → Return connection to pool
```

## When RLS is not enough
- Cross-tenant analytics (admin queries need BYPASSRLS role, not RLS bypass)
- Materialized views (do not respect RLS — refresh snapshots all data)
- Logical replication consumers (replication role bypasses RLS)

## What to explore next
- Concept 17: Audit triggers — complement RLS with complete audit trail
- Concept 19: pg_stat_statements — measure RLS policy overhead
- Practice 11: Audit triggers — who changed what, even with RLS in place
