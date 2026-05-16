# Row-Level Security and Tenant Isolation

Level: Intermediate

## One-line intuition
RLS lets the database itself decide which rows each user can see or modify — zero-trust enforcement at the data layer.

## Why this exists
Multi-tenant applications store data for many customers in the same tables. Without database-level isolation, a bug or missing WHERE clause in application code can expose one tenant's data to another. RLS moves the enforcement into PostgreSQL itself, so every query — from any access path — is automatically filtered.

## First-principles explanation
Row-Level Security is a PostgreSQL feature where policies — boolean SQL expressions — are attached to a table. When RLS is enabled on a table, every SELECT, INSERT, UPDATE, and DELETE is automatically augmented with the policy's WHERE expression. A row is visible or modifiable only if the policy evaluates to true for that row and the current session context. Policies use `current_user`, `current_setting()`, or application-set session variables (via `SET LOCAL`) to determine the tenant identity. The superuser and table owner bypass RLS by default; you can force it with `FORCE ROW LEVEL SECURITY`.

## Micro-concepts
- **`ALTER TABLE t ENABLE ROW LEVEL SECURITY`** — activates RLS enforcement on the table
- **`ALTER TABLE t FORCE ROW LEVEL SECURITY`** — applies RLS even to the table owner role
- **`CREATE POLICY`** — defines a boolean filter for a specific command (SELECT, INSERT, UPDATE, DELETE) or role
- **`USING` clause** — filters which rows are visible (SELECT, UPDATE, DELETE target rows)
- **`WITH CHECK` clause** — filters which rows can be written (INSERT new rows, UPDATE result rows)
- **`current_setting('app.tenant_id')`** — reads a session variable set by the application
- **`SET LOCAL app.tenant_id = '...'`** — sets a session variable scoped to the current transaction; resets on COMMIT/ROLLBACK
- **`BYPASSRLS` role attribute** — grants the role ability to bypass RLS; use only for superuser-equivalent admin roles
- **`SECURITY DEFINER` function** — runs with the function creator's privileges; bypasses RLS unless explicitly re-enabled
- **`pg_policies`** — system catalog listing all RLS policies

## Beginner view
Imagine a filing cabinet where each folder has a lock. RLS gives each user a key that only opens their folders — even if they know other folders exist, they simply cannot see inside them.

## Intermediate view
The standard multi-tenant pattern: add a `tenant_id` column to every tenant-scoped table. Enable RLS. Create a policy `USING (tenant_id = current_setting('app.tenant_id')::uuid)`. In the application, after acquiring a connection, run `SET LOCAL app.tenant_id = '<id>'` inside every transaction. This makes tenant leakage a database error, not an application bug. Use separate PostgreSQL roles per tenant for stronger isolation, but `SET LOCAL` is simpler with connection poolers.

## Advanced view
RLS policies are inlined into every query plan — check with `EXPLAIN` to see the added filter. Policy overhead is usually negligible but can affect index selection if the planner misestimates selectivity. Use `LEAKPROOF` functions in policies to prevent side-channel data exposure. Be careful with `SECURITY DEFINER` functions — they bypass RLS unless you explicitly re-enable it inside them. For write-heavy workloads, policy evaluation adds per-row CPU cost; benchmark on realistic data volumes.

## Mental model
RLS is an invisible WHERE clause that the database appends to every query on your behalf — you cannot forget it because you cannot turn it off at the query level.

## PostgreSQL view
```sql
-- List all policies
SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public';

-- Check if RLS is enabled
SELECT relname, relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE relname IN ('orders', 'users');
```

## SQL view
```sql
-- Enable RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders FORCE ROW LEVEL SECURITY; -- even for table owner

-- Tenant isolation policy
CREATE POLICY tenant_isolation ON orders
  USING (tenant_id = current_setting('app.tenant_id')::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

-- Application sets context at the start of each transaction
BEGIN;
SET LOCAL app.tenant_id = 'a1b2c3d4-0000-0000-0000-000000000001';
SELECT * FROM orders; -- only sees rows for this tenant
COMMIT;

-- Admin bypass (run as superuser or use BYPASSRLS role attribute)
SET row_security = off; -- superuser only

-- blocked: Docker not accessible; validate against cfp_postgres when available
```

## Non-SQL or hybrid view
RLS integrates cleanly with JSONB columns. A policy can filter on a JSONB field: `USING ((metadata->>'tenant_id')::uuid = current_setting('app.tenant_id')::uuid)`. This is useful when tenant context is embedded in document-style data, though it prevents index use on the JSONB field — prefer a dedicated indexed column for RLS predicates.

## Design principle
Always pair `ENABLE ROW LEVEL SECURITY` with `FORCE ROW LEVEL SECURITY` on tenant-scoped tables — without FORCE, the table owner role (often the migration user) bypasses all policies and can accidentally expose all tenants' data.

## Critical thinking
If your connection pooler uses a single long-lived PostgreSQL role and `SET LOCAL app.tenant_id` within transactions, what happens if a transaction is aborted mid-way and the connection is reused? Is tenant context truly reset?

## Creative thinking
Could RLS be used to implement time-based data visibility — rows are only visible after their `publish_at` timestamp passes — without any application-layer logic?

## Systems thinking
RLS interacts with materialized views (policies do not apply to MATVIEWs — data is snapshotted at refresh time), logical replication (the replication user typically bypasses RLS), and pgBouncer (transaction-mode pooling is compatible with `SET LOCAL`; session-mode requires careful connection lifecycle management).

## MCP and agent perspective
RLS is a critical safety boundary for AI agents operating on multi-tenant databases. An agent must always establish tenant context before querying, and must not be granted `BYPASSRLS` or superuser privileges. Agent audit trails should record both the tenant context and the role used, to detect privilege escalation.

## Ontology perspective
RLS is the enforcement arm of the ontological principle of data sovereignty: each tenant's data is that tenant's property, and no other tenant can access it. The `tenant_id` column is an ontological partition key — it encodes the ownership relation (`belongs_to`) between every row and a tenant entity.

`current_setting('app.tenant_id')` is the session's ontological identity claim. The database trusts this claim for filtering but should not grant it elevated privileges. The combination of RLS + audit triggers creates a complete access-control and auditability framework: RLS restricts what can be seen, audit triggers record what was touched.

Policies that use `current_setting` implement a form of contextual ontology: the visible world changes based on the context (tenant identity) in which it is viewed. This is similar to the ontological concept of "perspective" — facts are the same, but their visibility depends on the observer's position.

## Practice session
See `practice/intermediate/10-rls-and-multi-tenancy/` for hands-on exercises with tenant isolation policies.

## References
- PostgreSQL docs — Row Security Policies: https://www.postgresql.org/docs/16/ddl-rowsecurity.html
- PostgreSQL docs — CREATE POLICY: https://www.postgresql.org/docs/16/sql-createpolicy.html
- PostgreSQL docs — pg_policies: https://www.postgresql.org/docs/16/view-pg-policies.html
- "Row Level Security in PostgreSQL" (Citus): https://www.citusdata.com/blog/2016/08/10/row-level-security/
- "Multi-tenancy with Row Level Security" (Supabase): https://supabase.com/docs/guides/auth/row-level-security
