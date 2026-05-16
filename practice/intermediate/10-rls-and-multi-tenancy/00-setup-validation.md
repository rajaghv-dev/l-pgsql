# Setup Validation — Practice 10

**Status: blocked — Docker not accessible in this session**

```sql
-- blocked: Docker not accessible

-- 1. RLS is enabled on both tables
SELECT relname, relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE relname IN ('projects', 'tasks');
-- Expected: relrowsecurity = true, relforcerowsecurity = true

-- 2. Policies exist
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename;
-- Expected: 2 policies (one per table)

-- 3. Without tenant context, no rows visible
SELECT COUNT(*) FROM projects;
-- Expected: 0 (or ERROR if current_setting returns null)

-- 4. With tenant context, rows visible
BEGIN;
SET LOCAL app.tenant_id = 'aaaaaaaa-0000-0000-0000-000000000001';
SELECT name FROM projects;
-- Expected: only 'Acme Project Alpha'
COMMIT;
```
