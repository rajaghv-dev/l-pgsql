# Troubleshooting — Practice 14: MCP Tool Database Design

> All SQL is `-- blocked: Docker not accessible`.

---

## Error: `permission denied for table documents`

**Cause**: The agent role is trying to query `documents` directly instead of through a tool function.

**Fix**: Ensure the agent's code calls `mcp_get_document(...)` rather than `SELECT * FROM documents`. The agent role has no direct table grants — only EXECUTE on tool functions.

```sql
-- blocked: Docker not accessible
-- Wrong: direct table access
SELECT * FROM documents WHERE id = $1;

-- Correct: through tool function
SELECT mcp_get_document('doc-uuid', 'agent-id', 'tenant-id');
```

---

## Error: `new row violates row-level security policy for table "documents"`

**Cause**: `SET LOCAL app.tenant_id` or `SET LOCAL app.agent_id` was not called before the INSERT.

**Fix**: Always call `set_config(...)` (or `SET LOCAL ...`) at the beginning of any database session that will execute queries against RLS-protected tables.

```sql
-- blocked: Docker not accessible
-- The tool function handles this internally via:
PERFORM set_config('app.tenant_id', p_tenant_id, true);
PERFORM set_config('app.agent_id',  p_agent_id,  true);
```

If you are testing directly (not via the tool function), set context manually:
```sql
-- blocked: Docker not accessible
SET LOCAL app.tenant_id = 'your-tenant-id';
SET LOCAL app.agent_id  = 'your-agent-id';
```

---

## Error: `mcp_tool_calls is INSERT-only. Operation UPDATE is not permitted.`

**Cause**: Code (or a test) attempted to UPDATE a row in `mcp_tool_calls`.

**Fix**: `mcp_tool_calls` is intentionally immutable. If you need to correct an audit entry, insert a new corrective entry — never update the existing one.

---

## Error: `Agent X cannot approve or reject its own pending approval request.`

**Cause**: The `reviewed_by` value in the UPDATE equals the `requested_by` value in the existing row.

**Fix**: Use a different identity for the reviewer. In tests, use `reviewed_by = 'human-reviewer-001'` (not the agent ID).

---

## Error: Function `mcp_create_draft` does not exist

**Cause**: The function creation in `setup.sql` failed (possibly due to a syntax error in a previous statement that left the transaction rolled back).

**Fix**: Run `setup.sql` in sections. Check for earlier errors that may have aborted the transaction:

```sql
-- blocked: Docker not accessible
-- Check if function exists:
SELECT proname FROM pg_proc WHERE proname = 'mcp_create_draft';
```

If it does not exist, re-run the function creation section of `setup.sql`.

---

## Error: `ERROR: operator does not exist: text = uuid`

**Cause**: Passing a TEXT value where a UUID is expected (or vice versa).

**Fix**: Cast explicitly:
```sql
-- blocked: Docker not accessible
WHERE id = $1::UUID
-- or in application code, ensure the parameter type matches
```

---

## RLS policies not visible in `pg_policies`

**Cause**: The policies may have been created for a role that does not match the query filter.

**Fix**:
```sql
-- blocked: Docker not accessible
SELECT * FROM pg_policies
WHERE tablename IN ('documents','mcp_tool_calls','pending_approvals');
-- Do not filter by rolname — check all policies for these tables
```

---

## Tool function returns `{"error": "document_not_found"}` unexpectedly

**Cause**: The `tenant_id` context is set to a different tenant than the document belongs to, causing the WHERE clause to return no rows.

**Fix**: Verify that `app.tenant_id` is set to the correct value before calling the function:
```sql
-- blocked: Docker not accessible
SELECT current_setting('app.tenant_id', true);
-- Must match the tenant_id column in the documents row you are querying
```
