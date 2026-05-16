# Exercises — Practice 14: MCP Tool Database Design

> All SQL is `-- blocked: Docker not accessible`. Write and review the SQL; test when Docker is available.

---

## Exercise 1: Understand the Schema

Read `setup.sql` and answer these questions without running any SQL:

1. Which table is INSERT-only? What prevents UPDATE and DELETE?
2. What CHECK constraint limits the `status` column of `documents`?
3. Why does `mcp_create_draft` use `SECURITY DEFINER`?
4. What prevents the agent from setting `status = 'approved'` on a pending_approval it created?
5. Why does the agent role have no direct GRANT on the `documents` table?

---

## Exercise 2: Write a New Narrow Tool Function

Write a PostgreSQL function `mcp_get_document(p_doc_id UUID, p_agent_id TEXT, p_tenant_id TEXT)` that:
- Sets the session context (agent_id, tenant_id, tool_name)
- Returns the document's id, title, status, and created_at (not the body)
- Inserts a row into mcp_tool_calls recording the read
- Returns JSONB

```sql
-- blocked: Docker not accessible
-- Write your function here:
CREATE OR REPLACE FUNCTION mcp_get_document(
  p_doc_id    UUID,
  p_agent_id  TEXT,
  p_tenant_id TEXT
) RETURNS JSONB
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_doc RECORD;
BEGIN
  -- Your code here
END;
$$;
```

---

## Exercise 3: Implement an RLS Policy for Read-Only Agents

Imagine a second role `mcp_readonly_agent` that should be able to SELECT from `documents` but never INSERT, UPDATE, or DELETE.

Write:
1. The `CREATE ROLE` statement
2. The RLS policy for SELECT only
3. The GRANT needed for the readonly agent to call a read tool function

```sql
-- blocked: Docker not accessible
-- Write your role, policy, and grant here:
```

---

## Exercise 4: Simulate a Blocked Operation

Without running the SQL, predict what happens in each scenario and explain why:

**Scenario A**:
```sql
-- blocked: Docker not accessible
SET LOCAL app.agent_id  = 'agent-1';
SET LOCAL app.tenant_id = 'tenant-A';
INSERT INTO mcp_tool_calls(tool_name, agent_id, tenant_id, success)
VALUES ('test_tool', 'agent-1', 'tenant-A', true);
-- Then:
UPDATE mcp_tool_calls SET success = false WHERE agent_id = 'agent-1';
```

**Scenario B**:
```sql
-- blocked: Docker not accessible
SET LOCAL app.agent_id  = 'agent-2';
SET LOCAL app.tenant_id = 'tenant-A';
SELECT * FROM documents;
-- (Documents exist for tenant-A and tenant-B)
```

**Scenario C**:
```sql
-- blocked: Docker not accessible
-- Assume a pending_approval exists with requested_by = 'agent-1'
UPDATE pending_approvals
SET status = 'approved', reviewed_by = 'agent-1'
WHERE id = 'some-id';
```

---

## Exercise 5: Design a "Submit for Review" Tool

Write a function `mcp_submit_for_review(p_doc_id UUID, p_agent_id TEXT, p_tenant_id TEXT)` that:
- Validates the document exists and is in 'draft' status
- Updates the document status to 'review'
- Records the action in mcp_tool_calls
- Returns JSONB with the new status

Constraints:
- The agent can only submit documents it created (`created_by = p_agent_id`)
- The document must currently be in 'draft' status
- If either constraint fails, return an error JSONB (not RAISE EXCEPTION)

```sql
-- blocked: Docker not accessible
CREATE OR REPLACE FUNCTION mcp_submit_for_review(
  p_doc_id    UUID,
  p_agent_id  TEXT,
  p_tenant_id TEXT
) RETURNS JSONB
SECURITY DEFINER LANGUAGE plpgsql AS $$
BEGIN
  -- Your code here
END;
$$;
```

---

## Exercise 6: Audit Log Query

Write SQL that answers: "What tool calls did agent 'agent-abc' make in the last 24 hours for tenant 'tenant-xyz'?"

```sql
-- blocked: Docker not accessible
SELECT
  -- Your columns here
FROM mcp_tool_calls
WHERE -- Your conditions here
ORDER BY called_at DESC;
```

---

## Exercise 7: Pending Approvals Expiry

Write the SQL for a scheduled job that:
1. Marks pending_approvals as 'expired' where `expires_at < now()`
2. Returns the count of rows that were expired

```sql
-- blocked: Docker not accessible
WITH expired AS (
  UPDATE pending_approvals
  SET status = 'expired'
  WHERE -- Your conditions here
  RETURNING id
)
SELECT -- Your count here;
```

---

## Exercise 8: Reflection Exercise

Without writing SQL, answer:

1. The schema uses `SECURITY DEFINER` on tool functions. What is the risk of this approach, and how does the schema mitigate it?
2. Why does `mcp_submit_archive_request` insert into `pending_approvals` instead of directly archiving the document?
3. If you needed to add a new tool `mcp_search_documents(query TEXT, ...)`, would it need to write to `mcp_tool_calls`? Why or why not?
4. What would break if you removed `FORCE ROW LEVEL SECURITY` from the `documents` table?
