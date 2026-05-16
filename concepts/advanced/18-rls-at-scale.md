# Row-Level Security at Scale

Level: Advanced

## One-line intuition
RLS is declarative data partitioning by identity — when it works correctly, it is invisible; when it performs badly or has a security gap, it is catastrophic — and the gap between "RLS enabled" and "RLS correctly implemented" is wider than most engineers expect.

## Why this exists
Multi-tenant SaaS applications need to ensure Tenant A cannot see Tenant B's data. The naive approach is to add `WHERE tenant_id = $current_tenant` to every query. This is fragile: any query that misses the clause leaks data. RLS enforces the clause at the database level — it cannot be forgotten, bypassed by application bugs, or disabled per-query by a standard user. It is the database's enforcement of data isolation.

## First-principles explanation

### RLS basics
```sql
-- blocked: Docker not accessible
-- Enable RLS on a table
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Create a SELECT policy (all other commands denied by default)
CREATE POLICY orders_select_policy ON orders
    FOR SELECT
    USING (tenant_id = current_setting('app.tenant_id')::bigint);

-- Separate INSERT policy
CREATE POLICY orders_insert_policy ON orders
    FOR INSERT
    WITH CHECK (tenant_id = current_setting('app.tenant_id')::bigint);

-- Combined policy for all operations
CREATE POLICY orders_tenant_policy ON orders
    USING (tenant_id = current_setting('app.tenant_id')::bigint)
    WITH CHECK (tenant_id = current_setting('app.tenant_id')::bigint);
```

`USING`: the filter applied to existing rows (SELECT, UPDATE, DELETE source).
`WITH CHECK`: the constraint applied to modified rows (INSERT, UPDATE destination).

### The app.tenant_id pattern
The standard pattern for multi-tenant SaaS:

**Application sets context on every connection acquisition**:
```sql
-- blocked: Docker not accessible
-- Set in PgBouncer pass-through, or application connection pool:
SET LOCAL app.tenant_id = '42';
-- All subsequent queries in this transaction see only tenant 42's rows
```

**Database policy uses the setting**:
```sql
-- blocked: Docker not accessible
CREATE POLICY tenant_isolation ON orders
    USING (tenant_id = current_setting('app.tenant_id')::bigint);
```

**Connection pool consideration**: In transaction-mode pooling (PgBouncer transaction mode), `SET LOCAL` is safe because it resets at transaction end. In session-mode pooling, `SET` (without LOCAL) persists across transactions — a session returned to the pool with the wrong tenant_id set is a security vulnerability. Always use `SET LOCAL` in transaction-mode pooling.

### Policy performance: the index alignment problem

**The problem**: RLS policies add implicit WHERE clauses. If the implicit clause is not satisfied by an existing index, every query on the table becomes a sequential scan — regardless of other indexes.

```sql
-- blocked: Docker not accessible
-- Policy: tenant_id = current_setting(...)::bigint
-- Without an index on tenant_id: seq scan for every tenant query
-- With a B-tree index on tenant_id: index scan per tenant

-- Correct index for RLS policy:
CREATE INDEX idx_orders_tenant ON orders (tenant_id);

-- Even better: composite index covering common query patterns
CREATE INDEX idx_orders_tenant_created ON orders (tenant_id, created_at DESC);
```

The planner treats the RLS USING clause exactly like a regular WHERE clause. Statistics on `tenant_id` must be accurate (run ANALYZE) for the planner to choose the right plan. If one tenant has 90% of rows and others have 0.01%, statistics imbalance can cause poor plans for small tenants.

### Security definer functions in RLS
```sql
-- blocked: Docker not accessible
-- A SECURITY DEFINER function runs as the function owner, not the caller
-- Use to read a permissions table without exposing it to the tenant
CREATE FUNCTION get_user_tenant_id(user_id bigint)
RETURNS bigint
LANGUAGE sql SECURITY DEFINER STABLE AS $$
    SELECT tenant_id FROM user_tenants WHERE id = user_id;
$$;

-- RLS policy using the function
CREATE POLICY orders_policy ON orders
    USING (tenant_id = get_user_tenant_id(current_setting('app.user_id')::bigint));
```

**SECURITY DEFINER risk**: the function runs with the owner's privileges. A SQL injection vulnerability in a SECURITY DEFINER function can escalate privileges to the function owner. Always:
- Grant EXECUTE on SECURITY DEFINER functions only to specific roles
- Use parameterized queries (not string concatenation) inside
- Mark as STABLE or IMMUTABLE for planner optimization

### BYPASSRLS
```sql
-- blocked: Docker not accessible
-- Roles with BYPASSRLS ignore all RLS policies
-- This is automatically granted to superuser
-- Check who has it:
SELECT rolname FROM pg_roles WHERE rolbypassrls;

-- Never grant BYPASSRLS to application roles
-- Reserve for: database admin role (for maintenance queries)
```

A role with BYPASSRLS can read all tenants' data without restriction. This is appropriate for database administrators and VACUUM-type operations, but catastrophic if granted to an application role.

### Per-policy vs per-table design

**Multiple policies on one table** (for different operations):
```sql
-- blocked: Docker not accessible
CREATE POLICY read_own_data ON orders FOR SELECT
    USING (tenant_id = current_setting('app.tenant_id')::bigint);

CREATE POLICY admin_read_all ON orders FOR SELECT
    TO admin_role
    USING (true);  -- admins see all rows

CREATE POLICY insert_check ON orders FOR INSERT
    WITH CHECK (tenant_id = current_setting('app.tenant_id')::bigint
                AND created_at >= now() - interval '1 minute');  -- anti-backdating
```

Multiple policies on the same operation are ORed together (permissive policies) by default. Use `AS RESTRICTIVE` for AND behavior:
```sql
-- blocked: Docker not accessible
-- RESTRICTIVE: all policies must pass (AND)
CREATE POLICY data_classification ON orders AS RESTRICTIVE
    USING (classification_level <= current_setting('app.clearance_level')::int);
```

### RLS with views
```sql
-- blocked: Docker not accessible
-- Views owned by a SECURITY DEFINER user bypass RLS
-- Views owned by the current user inherit RLS checks

-- Safe: view with SECURITY INVOKER (default) applies RLS
CREATE VIEW my_orders AS SELECT * FROM orders;
-- SECURITY INVOKER: RLS applies for whoever calls the view

-- Dangerous: SECURITY DEFINER view bypasses RLS
CREATE VIEW all_orders SECURITY DEFINER AS SELECT * FROM orders;
-- SECURITY DEFINER: view runs as owner (may have BYPASSRLS)
```

Always specify `SECURITY INVOKER` explicitly on views over RLS-protected tables to avoid accidental RLS bypass.

### Multi-tenant SaaS architecture patterns

**Pattern 1: Single database, RLS isolation** (most common)
- All tenants in the same schema
- RLS enforces isolation
- Efficient: shared infrastructure, no tenant-specific provisioning
- Risk: RLS misconfiguration exposes all tenants

**Pattern 2: Schema per tenant**
- Each tenant gets a separate schema
- No RLS needed (schema-level isolation)
- Requires connection routing (which schema?)
- Harder to run cross-tenant analytics
- Maximum isolation, maximum operational complexity

**Pattern 3: Database per tenant**
- Maximum isolation (separate connection, separate buffers)
- Separate pg_hba.conf entries per tenant
- Only feasible for small tenant counts (< 100)

For most SaaS: Pattern 1 (RLS) + connection pooler + `SET LOCAL app.tenant_id` on connect.

### RLS performance monitoring
```sql
-- blocked: Docker not accessible
-- Check if RLS is enabled on a table
SELECT relname, relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE relname = 'orders';

-- View all policies
SELECT schemaname, tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'orders';

-- Check EXPLAIN for RLS filter being applied
EXPLAIN SELECT * FROM orders;
-- Should show: Filter: (tenant_id = (current_setting('app.tenant_id'))::bigint)
```

## Micro-concepts
- **`relrowsecurity`**: in `pg_class` — whether RLS is enabled on the table.
- **`relforcerowsecurity`**: forces RLS even for the table owner. Default off — table owners bypass RLS. Set `on` for strict enforcement.
- **Permissive vs Restrictive policies**: permissive (default) → OR. Restrictive (`AS RESTRICTIVE`) → AND. Policies of the same type within permissive are ORed; all restrictive policies must pass in addition to at least one permissive passing.
- **Policy target role**: `TO role_name` limits which role the policy applies to. If omitted, applies to all roles (except those with BYPASSRLS).
- **`current_setting(name, missing_ok)`**: `missing_ok = true` returns NULL instead of error if the setting is not set. Use to handle connections that haven't set `app.tenant_id`.
- **`pg_enable_rls()`**: not a function — use `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: RLS adds an automatic WHERE clause to every query. Enable it, create a policy, and tenants are isolated.

**Intermediate view**: RLS requires an index on the tenant_id column for performance. Use `SET LOCAL app.tenant_id` in transaction-mode pooling. BYPASSRLS is dangerous — monitor who has it.

**Advanced view**: RLS performance is a function of index alignment and statistics accuracy. The USING clause adds a filter evaluated for every row candidate — if this filter is not index-supported, you have a guaranteed sequential scan on every query. Policy stacking (multiple policies, permissive + restrictive) creates complex logic that is hard to audit and test. SECURITY DEFINER functions in RLS policies are a privilege escalation risk if not carefully reviewed. Views over RLS tables require explicit `SECURITY INVOKER` to avoid accidentally bypassing RLS. The `relforcerowsecurity` flag must be set if table owners should not bypass RLS — by default, the table owner sees all rows.

## Mental model
RLS is a transparent one-way mirror in each room of the database. From inside Tenant A's mirror, they see only their own rows — the other tenants' rows are invisible. From the database administrator's perspective (with BYPASSRLS), all rooms are visible. The mirror's optics (the policy condition) must be aligned with an index (the corridor map) to find the right rows quickly, otherwise every query searches the whole building.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_policies`, `pg_class` (relrowsecurity), `pg_roles` (rolbypassrls).

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Show all RLS policies in the database
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
ORDER BY tablename;

-- Tables with RLS enabled
SELECT relname, relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE relrowsecurity = true AND relkind = 'r';

-- Test as a specific role (verify isolation)
SET ROLE app_user;
SET LOCAL app.tenant_id = '1';
SELECT count(*) FROM orders;  -- should only see tenant 1's orders
RESET ROLE;
```

**Non-SQL / hybrid view**: Application frameworks: Django has no native RLS integration — use middleware that sets `app.tenant_id`. Rails: `acts_as_tenant` gem + connection hook. Prisma: middleware to set the tenant context before each query.

## Design principle
**RLS enforces isolation at the database level — test it adversarially**: Don't test that Tenant A can see their own data; test that Tenant A cannot see Tenant B's data by explicitly connecting as a Tenant A role and querying known Tenant B row IDs. Include RLS bypass tests in your security test suite.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: RLS protects data at query time but not at COPY, `pg_dump`, or physical backup time. A `pg_dump` run as a superuser exports all tenant data. Physical backups (pg_basebackup) are entirely outside RLS's scope. Backup access control is a separate concern — restrict backup tool credentials, encrypt backup files, and audit backup execution.

**Creative**: Use RLS to enforce data classification on a shared table:
```sql
-- blocked: Docker not accessible
CREATE POLICY classification_filter ON sensitive_data AS RESTRICTIVE
    USING (classification <= current_setting('app.user_clearance')::int);
```
This adds a clearance-level filter in addition to (AND, using RESTRICTIVE) any other policies. Combining tenant isolation (permissive) with data classification (restrictive) in the same table creates a two-factor data access model.

**Systems**: RLS policies are evaluated for every row that could potentially be returned. For a query like `SELECT count(*) FROM orders`, every row is checked against the policy. If the tenant_id index is not used (e.g., the policy expression is not index-eligible), this degrades to O(total_rows). At 1 billion rows across 10,000 tenants, a misaligned RLS policy causes every query to scan the entire billion-row table. This is a catastrophic failure mode. Always EXPLAIN queries on RLS-protected tables and verify index use.

## MCP and agent perspective
In multi-agent systems, each agent can be a "tenant" isolated by RLS. Set `app.agent_id = current_agent_id` on connect. The agent's memory, action log, and working memory are isolated to its own ID. Cross-agent data access (e.g., a supervisor agent reading all sub-agent logs) is handled by a privileged role that bypasses RLS, with all cross-agent access logged. This provides strong isolation without separate database instances per agent.

## Ontology perspective
RLS is an ontological access boundary: it defines the observable universe for each connected identity. From Tenant A's perspective, the orders table contains only A's orders — Tenant B's rows do not exist in A's observable reality. This is a form of information partition at the data layer. The critical insight: the boundary is enforced by the database's execution engine, not by application logic — it is a fundamental ontological constraint, not a voluntary convention.

## Practice session

**Exercise 1 — Enable RLS and create a basic policy**:
```sql
-- blocked: Docker not accessible
CREATE TABLE tenant_data (
    id serial PRIMARY KEY,
    tenant_id bigint NOT NULL,
    value text
);
ALTER TABLE tenant_data ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON tenant_data
    USING (tenant_id = current_setting('app.tenant_id', true)::bigint);
```

**Exercise 2 — Test isolation**: Verify tenants can't cross-read.
```sql
-- blocked: Docker not accessible
INSERT INTO tenant_data (tenant_id, value) VALUES (1, 'tenant1 data'), (2, 'tenant2 data');
SET LOCAL app.tenant_id = '1';
SELECT * FROM tenant_data;  -- should see only tenant 1's row
SET LOCAL app.tenant_id = '2';
SELECT * FROM tenant_data;  -- should see only tenant 2's row
```

**Exercise 3 — Check EXPLAIN for index use**:
```sql
-- blocked: Docker not accessible
CREATE INDEX idx_tenant_data_tid ON tenant_data (tenant_id);
SET LOCAL app.tenant_id = '1';
EXPLAIN SELECT * FROM tenant_data;
-- Verify: Index Scan on idx_tenant_data_tid, not Seq Scan
```

**Exercise 4 — Admin bypass**: Create admin role.
```sql
-- blocked: Docker not accessible
CREATE ROLE admin_role BYPASSRLS LOGIN PASSWORD 'admin_pass';
GRANT SELECT ON tenant_data TO admin_role;
-- Admin can see all rows (BYPASSRLS)
SET ROLE admin_role;
SELECT * FROM tenant_data;
RESET ROLE;
```

**Exercise 5 — Force RLS for table owner**:
```sql
-- blocked: Docker not accessible
-- Table owner bypasses RLS by default
ALTER TABLE tenant_data FORCE ROW LEVEL SECURITY;
-- Now even owner is subject to policies
```

## References
- PostgreSQL Documentation: [Row Security Policies](https://www.postgresql.org/docs/16/ddl-rowsecurity.html)
- PostgreSQL Documentation: [CREATE POLICY](https://www.postgresql.org/docs/16/sql-createpolicy.html)
- PostgreSQL Documentation: [Role Attributes — BYPASSRLS](https://www.postgresql.org/docs/16/sql-createrole.html)
- Citus Data: [Multi-tenant Applications with RLS](https://www.citusdata.com/blog/2016/08/10/how-to-write-a-custom-postgres-foreign-data-wrapper/)
- Luc Deerix: [PostgreSQL RLS Performance](https://www.percona.com/blog/2018/09/10/row-level-security-in-postgresql/)
- PgBouncer transaction mode: https://www.pgbouncer.org/config.html
