# Troubleshooting — RLS and Multi-Tenancy

## ERROR: unrecognized configuration parameter "app.tenant_id"
**Cause:** The `app.` namespace is not always pre-registered. In some PostgreSQL versions, non-standard GUC namespaces require explicit configuration.
**Fix:** This is usually not an issue in PostgreSQL 16. If you see this error, use `ALTER DATABASE cfp SET app.tenant_id = '';` to pre-register the variable, or use the lenient form: `current_setting('app.tenant_id', TRUE)`.

## RLS returns 0 rows even when tenant context is set
**Cause:** UUID format mismatch, wrong tenant_id value, or `SET LOCAL` ran outside a transaction.
**Diagnosis:**
```sql
SELECT current_setting('app.tenant_id', TRUE);
-- Verify this matches a real tenant ID:
SELECT id FROM tenants WHERE id = current_setting('app.tenant_id', TRUE)::uuid;
```
**Fix:** Ensure SET LOCAL is inside BEGIN/COMMIT, and the ID matches exactly (UUID format is case-sensitive).

## ERROR: new row violates row-level security policy
**Cause:** Inserting a row with `tenant_id` that doesn't match the current session's `app.tenant_id`.
**Fix:** The application should always set `tenant_id = current_setting('app.tenant_id')::uuid` in INSERT statements.

## Table owner can see all rows
**Cause:** `FORCE ROW LEVEL SECURITY` not enabled — table owner bypasses policies.
**Fix:** `ALTER TABLE projects FORCE ROW LEVEL SECURITY;`

## Queries are slow after enabling RLS
**Cause:** No index on `tenant_id` column — the policy adds a filter that performs a sequential scan.
**Fix:** `CREATE INDEX ON projects (tenant_id);` and the same for all tenant-scoped tables.

## RLS not working in PgBouncer session mode
**Cause:** In session mode, connections persist across transactions. `SET LOCAL` resets on COMMIT, but if the next transaction doesn't set context, it may use the previous session's context (from another client).
**Fix:** Use PgBouncer in transaction mode, or set `app.tenant_id` at the start of EVERY transaction, or use `RESET app.tenant_id` at the end of each transaction to prevent stale context.

## Materialized view not respecting RLS
**Cause:** Matviews snapshot data at refresh time. The refresh runs as the refreshing role (often superuser), which bypasses RLS — all tenants' data is captured.
**Fix:** Do not use matviews for tenant-scoped data unless you create one matview per tenant (and refresh each separately). For cross-tenant aggregates, use the superuser role intentionally and secure the matview with separate RLS.
