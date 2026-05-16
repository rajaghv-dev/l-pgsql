# Setup Validation — Practice 14

> All SQL is `-- blocked: Docker not accessible`. Review the validation patterns for when Docker is available.

---

## What to Verify After Running setup.sql

### 1. Tables exist with correct structure

```sql
-- blocked: Docker not accessible
\d documents
\d mcp_tool_calls
\d pending_approvals
```

Expected: all three tables present with UUID primary keys, TEXT constraints, TIMESTAMPTZ defaults.

---

### 2. RLS is enabled on all tables

```sql
-- blocked: Docker not accessible
SELECT tablename, rowsecurity, forcerowsecurity
FROM pg_tables
WHERE tablename IN ('documents','mcp_tool_calls','pending_approvals');
```

Expected: `rowsecurity = true`, `forcerowsecurity = true` for all three.

---

### 3. Immutability trigger is active on mcp_tool_calls

```sql
-- blocked: Docker not accessible
SELECT tgname, tgenabled
FROM pg_trigger
WHERE tgrelid = 'mcp_tool_calls'::regclass;
```

Expected: `protect_tool_calls` and `protect_tool_calls_truncate` both with `tgenabled = 'O'` (enabled).

```sql
-- blocked: Docker not accessible
-- This should RAISE EXCEPTION:
INSERT INTO mcp_tool_calls(tool_name, agent_id, success)
VALUES ('test', 'agent-1', true);

UPDATE mcp_tool_calls SET tool_name = 'modified' WHERE id = '...';
-- Expected: ERROR: mcp_tool_calls is INSERT-only. Operation UPDATE is not permitted.
```

---

### 4. Self-approval trigger is active

```sql
-- blocked: Docker not accessible
-- Insert a pending approval, then try to approve it as the same agent:
SET LOCAL app.agent_id  = 'agent-test';
SET LOCAL app.tenant_id = 'tenant-test';

-- (Assumes a document exists with id = 'some-uuid')
UPDATE pending_approvals
SET status = 'approved', reviewed_by = 'agent-test'
WHERE id = 'some-pending-id';
-- Expected: ERROR: Agent agent-test cannot approve or reject its own pending approval request.
```

---

### 5. Tool functions exist and have correct grants

```sql
-- blocked: Docker not accessible
SELECT routine_name, security_type
FROM information_schema.routines
WHERE routine_name IN ('mcp_create_draft', 'mcp_submit_archive_request');
-- Expected: both present, security_type = 'DEFINER'

SELECT grantee, privilege_type
FROM information_schema.routine_privileges
WHERE routine_name IN ('mcp_create_draft', 'mcp_submit_archive_request')
  AND grantee = 'mcp_agent_role';
-- Expected: EXECUTE for both
```

---

### 6. RLS policies are in place

```sql
-- blocked: Docker not accessible
SELECT policyname, tablename, roles, cmd
FROM pg_policies
WHERE tablename IN ('documents','mcp_tool_calls','pending_approvals')
ORDER BY tablename, policyname;
```

Expected: multiple policies per table covering SELECT, INSERT with correct USING and WITH CHECK clauses.

---

## Common Setup Failures

| Symptom | Likely cause |
|---------|-------------|
| `permission denied for table documents` | Agent role does not have EXECUTE on tool functions |
| `ERROR: new row violates row-level security policy` | SET LOCAL not called before INSERT |
| `trigger "protect_tool_calls" does not exist` | setup.sql ran with an error partway through |
| `function mcp_create_draft does not exist` | Function creation failed; check for syntax errors |
