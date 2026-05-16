# Multi-Tenant SaaS Example

Level: Intermediate
Domain: Row-Level Security for tenant isolation in a SaaS application
Synthetic data: Yes

## Overview

A minimal SaaS application for a fictional project management tool called
"Workstream". Three tables — `tenants`, `users`, and `documents` — demonstrate
PostgreSQL Row-Level Security (RLS) enforcing tenant isolation at the database
level. Tenant context is passed via `current_setting('app.tenant_id')` so
application code only needs to set one session variable; all SQL then returns
only that tenant's data automatically.

Key concepts: RLS policies, `current_setting()`, `SET LOCAL` within transactions,
bypassing RLS as superuser, role-based access.

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- Tenants registry (not RLS-protected; managed by superuser/ops only)
CREATE TABLE tenants (
    id    SERIAL PRIMARY KEY,
    name  TEXT   NOT NULL UNIQUE,
    plan  TEXT   NOT NULL DEFAULT 'starter'
                 CHECK (plan IN ('starter','pro','enterprise'))
);

-- Users (one tenant per user in this simple model)
CREATE TABLE users (
    id          SERIAL PRIMARY KEY,
    tenant_id   INT     NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email       TEXT    NOT NULL UNIQUE,
    role        TEXT    NOT NULL DEFAULT 'member'
                        CHECK (role IN ('admin','member','viewer')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Users can see all users within their tenant
CREATE POLICY users_tenant_isolation ON users
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::INT);

CREATE INDEX idx_users_tenant_id ON users (tenant_id);

-- Documents (the main application data)
CREATE TABLE documents (
    id          SERIAL PRIMARY KEY,
    tenant_id   INT     NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    title       TEXT    NOT NULL,
    content     TEXT    NOT NULL DEFAULT '',
    created_by  INT     REFERENCES users(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- Documents are only visible to the matching tenant
CREATE POLICY documents_tenant_isolation ON documents
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::INT);

-- For INSERT: enforce that the tenant_id on the new row matches the session
CREATE POLICY documents_tenant_insert ON documents
    AS RESTRICTIVE
    WITH CHECK (tenant_id = current_setting('app.tenant_id', TRUE)::INT);

CREATE INDEX idx_documents_tenant_id ON documents (tenant_id);
CREATE INDEX idx_documents_created_by ON documents (created_by);
```

## Seed data

```sql
-- Tenants
INSERT INTO tenants (name, plan) VALUES
  ('Acme Corp',       'enterprise'),
  ('Blue Sky Ltd',    'pro'),
  ('Cedar Analytics', 'starter');

-- Users
INSERT INTO users (tenant_id, email, role) VALUES
  -- Acme Corp (tenant 1)
  (1, 'alice@acme.example',   'admin'),
  (1, 'bob@acme.example',     'member'),
  (1, 'charlie@acme.example', 'viewer'),

  -- Blue Sky Ltd (tenant 2)
  (2, 'diana@bluesky.example', 'admin'),
  (2, 'evan@bluesky.example',  'member'),

  -- Cedar Analytics (tenant 3)
  (3, 'fiona@cedar.example',   'admin');

-- Documents for Acme Corp (tenant 1)
SET app.tenant_id = '1';
INSERT INTO documents (tenant_id, title, content, created_by) VALUES
  (1, 'Q3 Roadmap',          'Feature priorities for Q3 2024.',               1),
  (1, 'Onboarding Guide',    'Steps for new employee onboarding at Acme.',    2),
  (1, 'Security Policy',     'Password and access control requirements.',     1);

-- Documents for Blue Sky Ltd (tenant 2)
SET app.tenant_id = '2';
INSERT INTO documents (tenant_id, title, content, created_by) VALUES
  (2, 'Product Vision 2025',  'Long-term vision for the Blue Sky platform.',  4),
  (2, 'Sprint 42 Notes',      'Notes from sprint planning on 2024-06-10.',    5);

-- Documents for Cedar Analytics (tenant 3)
SET app.tenant_id = '3';
INSERT INTO documents (tenant_id, title, content, created_by) VALUES
  (3, 'Data Governance Charter', 'Policies for data quality and ownership.', 6);
```

## Example queries

### View your tenant's documents

```sql
SET app.tenant_id = '1';   -- Acting as Acme Corp

SELECT id, title, created_at
FROM   documents
ORDER  BY created_at DESC;
-- Returns only tenant_id = 1 rows (3 rows)
```

### View your tenant's users

```sql
SET app.tenant_id = '1';

SELECT id, email, role
FROM   users
ORDER  BY role;
-- Returns only Acme Corp users
```

### Confirm cross-tenant isolation (RLS silently filters)

```sql
SET app.tenant_id = '1';

-- Explicit filter for tenant 2 — still returns 0 rows
SELECT COUNT(*) FROM documents WHERE tenant_id = 2;

-- Cross-tenant user lookup — returns 0 rows
SELECT email FROM users WHERE tenant_id = 2;
```

### SET LOCAL: tenant context scoped to a transaction

```sql
BEGIN;
  SET LOCAL app.tenant_id = '2';   -- context only lasts this transaction

  SELECT id, title FROM documents;  -- sees Blue Sky Ltd documents

  INSERT INTO documents (tenant_id, title, content, created_by)
  VALUES (2, 'New Design Doc', 'Rough draft of UI redesign.', 4);
COMMIT;
-- After COMMIT, app.tenant_id reverts to whatever it was before
```

### Superuser bypass to view all tenants (admin portal)

```sql
-- As superuser, set the role to bypass RLS:
-- SET ROLE postgres;   -- superuser role bypasses RLS by default
-- Or use BYPASSRLS attribute:
-- ALTER USER myapp BYPASSRLS;

-- Example admin query (requires BYPASSRLS or superuser):
SELECT d.id, t.name AS tenant, d.title
FROM   documents d
JOIN   tenants   t ON t.id = d.tenant_id
ORDER  BY t.name, d.id;
```

### Tenant plan breakdown

```sql
-- This is a superuser/ops query (no RLS on tenants table)
SELECT plan, COUNT(*) AS tenant_count
FROM   tenants
GROUP  BY plan
ORDER  BY tenant_count DESC;
```

### WITH CHECK insert violation (wrong tenant_id)

```sql
SET app.tenant_id = '1';

-- This INSERT would violate the WITH CHECK policy:
-- INSERT INTO documents (tenant_id, title, content, created_by)
-- VALUES (2, 'Injected doc', 'Bad content', 1);
-- ERROR: new row violates row-level security policy "documents_tenant_insert" for table "documents"
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- Superuser: total rows
SELECT COUNT(*) FROM tenants;    -- Expected: 3
SELECT COUNT(*) FROM users;      -- Expected: 6
SELECT COUNT(*) FROM documents;  -- Expected: 6

-- RLS is enabled on both application tables
SELECT tablename, rowsecurity
FROM   pg_tables
WHERE  tablename IN ('users', 'documents');

-- Policies exist
SELECT policyname, tablename, cmd
FROM   pg_policies
WHERE  tablename IN ('users', 'documents')
ORDER  BY tablename, policyname;

-- Tenant 2 sees exactly 2 documents
SET app.tenant_id = '2';
SELECT COUNT(*) FROM documents;
-- Expected: 2
```

## Practice tasks

1. **Add a new tenant.** Insert a new tenant `('Starpath Inc', 'pro')`. Add two
   users and two documents for it. Verify that `SET app.tenant_id` to that tenant's
   id returns only Starpath documents.

2. **Role-aware policy.** Modify the `documents` RLS policy so that users with
   `role = 'viewer'` can read documents but cannot INSERT or UPDATE. Hint: you'll
   need a separate policy per command (`FOR SELECT`, `FOR INSERT`, etc.) and a way
   to look up the current user's role.

3. **SET LOCAL scoping.** Run the `SET LOCAL` transaction example above. After
   COMMIT, check `current_setting('app.tenant_id', TRUE)`. Is it still `'2'` or
   has it reverted? Explain the difference between `SET` and `SET LOCAL`.

4. **WITH CHECK violation.** Set `app.tenant_id = '1'`. Attempt to insert a
   document with `tenant_id = 2`. Document the error message PostgreSQL returns.
   Why is the `WITH CHECK` policy important even when `USING` is also set?

5. **Admin dashboard query.** As superuser (bypassing RLS), write a query that
   returns, for each tenant: name, plan, number of users, and number of documents.
   Use CTEs or subqueries.

## MCP and agent perspective

An agent operating in a multi-tenant SaaS context via MCP would:

- **Receive `tenant_id` at session start** — the server-side MCP handler sets
  `app.tenant_id` once, before any agent query. The agent never sees or manipulates
  tenant context directly.
- **Cannot leak data between tenants** — even if a prompt injection tries to query
  another tenant's data, RLS silently returns 0 rows.
- **Cannot insert into wrong tenant** — the `WITH CHECK` policy blocks inserts
  with a mismatched `tenant_id`, protecting against confused-deputy attacks.
- **Transparent to the agent** — the agent writes simple SQL (`SELECT * FROM documents`)
  and the database handles isolation. No JOIN to a tenant filter table required.
- **Admin agent bypasses RLS** — a separate admin agent running with `BYPASSRLS`
  can query all tenants for billing, auditing, and support purposes.

## Teardown

```sql
DROP TABLE IF EXISTS documents;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS tenants;
```

## References

- Row-Level Security: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- current_setting(): https://www.postgresql.org/docs/current/functions-admin.html
- SET LOCAL: https://www.postgresql.org/docs/current/sql-set.html
- BYPASSRLS: https://www.postgresql.org/docs/current/sql-createrole.html
