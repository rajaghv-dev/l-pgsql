# Exercises — Row-Level Security and Multi-Tenancy

**Status: blocked — Docker not accessible in this session**

## Exercise 1: Set tenant context and observe isolation

```sql
-- blocked: Docker not accessible

-- Session as Acme tenant
BEGIN;
SET LOCAL app.tenant_id = 'aaaaaaaa-0000-0000-0000-000000000001';
SELECT name FROM projects;
-- Expected: only Acme's project
SELECT title, status FROM tasks;
-- Expected: only Acme's tasks (2 rows)
COMMIT;

-- Session as BetaCo tenant
BEGIN;
SET LOCAL app.tenant_id = 'bbbbbbbb-0000-0000-0000-000000000002';
SELECT name FROM projects;
-- Expected: only BetaCo's project
COMMIT;
```

## Exercise 2: Attempt cross-tenant access

```sql
-- blocked: Docker not accessible

-- As Acme, try to read BetaCo's project by ID
BEGIN;
SET LOCAL app.tenant_id = 'aaaaaaaa-0000-0000-0000-000000000001';
SELECT * FROM projects WHERE id = '22222222-0000-0000-0000-000000000002';
-- Expected: 0 rows (RLS filters it out silently — no error, just empty)
COMMIT;
```

## Exercise 3: Attempt cross-tenant insert

```sql
-- blocked: Docker not accessible

-- As Acme, try to insert a task with BetaCo's tenant_id
BEGIN;
SET LOCAL app.tenant_id = 'aaaaaaaa-0000-0000-0000-000000000001';
INSERT INTO tasks (project_id, tenant_id, title)
VALUES (
    '22222222-0000-0000-0000-000000000002',
    'bbbbbbbb-0000-0000-0000-000000000002',
    'Acme hacking BetaCo'
);
-- Expected: ERROR — WITH CHECK policy rejects the insert
ROLLBACK;
```

## Exercise 4: current_setting with fallback

```sql
-- blocked: Docker not accessible

-- Without SET LOCAL, current_setting raises an error by default
-- The second argument TRUE makes it return NULL instead of erroring
SELECT current_setting('app.tenant_id', TRUE);
-- Returns NULL (no error) when not set

-- The policy uses TRUE (lenient mode):
-- USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid)
-- When NULL, UUID cast of NULL = NULL, so no rows match — safe default
```

## Exercise 5: FORCE ROW LEVEL SECURITY

```sql
-- blocked: Docker not accessible

-- Demonstrate that FORCE makes even the table owner respect policies
-- Connect as the 'cfp' role (table owner)

-- Without FORCE, table owner bypasses RLS
ALTER TABLE projects DISABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
-- (no FORCE)
SELECT COUNT(*) FROM projects;  -- sees ALL rows as table owner

-- With FORCE, table owner also filtered
ALTER TABLE projects FORCE ROW LEVEL SECURITY;
BEGIN;
-- No tenant set
SELECT COUNT(*) FROM projects;  -- returns 0 or error
COMMIT;
```

## Exercise 6: Inspect policies

```sql
-- blocked: Docker not accessible

-- View all active policies
SELECT
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- See how RLS is encoded in EXPLAIN
BEGIN;
SET LOCAL app.tenant_id = 'aaaaaaaa-0000-0000-0000-000000000001';
EXPLAIN SELECT * FROM projects;
-- Should show: Filter: (tenant_id = current_setting('app.tenant_id', true)::uuid)
COMMIT;
```

## Reflection questions
1. Why does RLS return 0 rows (not an error) for cross-tenant queries?
2. What is the difference between `ENABLE ROW LEVEL SECURITY` and `FORCE ROW LEVEL SECURITY`?
3. Why use `current_setting('app.tenant_id', TRUE)` (lenient mode) rather than `current_setting('app.tenant_id')` in policies?
4. How does transaction-mode PgBouncer interact with `SET LOCAL`? When would session-mode pooling break tenant isolation?
