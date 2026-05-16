# Solutions — Practice 14: MCP Tool Database Design

> All SQL is `-- blocked: Docker not accessible`.

---

## Exercise 1: Schema Comprehension

**Q1: Which table is INSERT-only? What prevents UPDATE and DELETE?**

`mcp_tool_calls` is INSERT-only. The `protect_tool_calls` BEFORE trigger raises an exception for any UPDATE or DELETE operation. The `protect_tool_calls_truncate` trigger raises an exception for TRUNCATE. The agent role cannot disable these triggers because it has no DDL (ALTER TABLE) privileges.

**Q2: What CHECK constraint limits the `status` column of `documents`?**

```sql
CHECK (status IN ('draft','review','published','archived'))
```

Any INSERT or UPDATE that tries to set status to any other value is rejected by the database engine.

**Q3: Why does `mcp_create_draft` use `SECURITY DEFINER`?**

`SECURITY DEFINER` causes the function to run with the privileges of the function owner (typically a service role), not the caller (the agent role). This allows the agent to write to `documents` and `mcp_tool_calls` without having direct GRANT on those tables. The function mediates all access — the agent cannot bypass it.

**Q4: What prevents the agent from setting `status = 'approved'` on a pending_approval it created?**

Two mechanisms: (1) the agent role has no direct GRANT to UPDATE `pending_approvals` (only INSERT is permitted via the INSERT RLS policy), and (2) even if it could somehow UPDATE, the `no_self_approval` trigger checks `reviewed_by = requested_by` and raises an exception.

**Q5: Why does the agent role have no direct GRANT on the `documents` table?**

The agent accesses documents only through SECURITY DEFINER tool functions. This means the agent can only do what the tool functions allow — it cannot construct arbitrary SQL against the table. The function is the enforcement boundary.

---

## Exercise 2: mcp_get_document

```sql
-- blocked: Docker not accessible
CREATE OR REPLACE FUNCTION mcp_get_document(
  p_doc_id    UUID,
  p_agent_id  TEXT,
  p_tenant_id TEXT
) RETURNS JSONB
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_doc RECORD;
BEGIN
  PERFORM set_config('app.agent_id',  p_agent_id,  true);
  PERFORM set_config('app.tenant_id', p_tenant_id, true);
  PERFORM set_config('app.tool_name', 'get_document', true);

  SELECT id, title, status, created_at
  INTO v_doc
  FROM documents
  WHERE id = p_doc_id AND tenant_id = p_tenant_id;
  -- Note: RLS also filters by tenant_id automatically

  INSERT INTO mcp_tool_calls(tool_name, agent_id, tenant_id, input_json, success)
  VALUES ('get_document', p_agent_id, p_tenant_id,
          jsonb_build_object('doc_id', p_doc_id),
          v_doc.id IS NOT NULL);

  IF v_doc.id IS NULL THEN
    RETURN jsonb_build_object('error', 'document_not_found');
  END IF;

  RETURN jsonb_build_object(
    'id', v_doc.id,
    'title', v_doc.title,
    'status', v_doc.status,
    'created_at', v_doc.created_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION mcp_get_document TO mcp_agent_role;
```

Key points:
- Body (`body TEXT`) is intentionally excluded — the tool only returns what the agent needs
- The tool logs both successful and failed reads to `mcp_tool_calls`
- Returns a structured JSONB error rather than raising an exception on not-found

---

## Exercise 3: Read-Only Agent Role

```sql
-- blocked: Docker not accessible

CREATE ROLE mcp_readonly_agent
  NOSUPERUSER NOCREATEDB NOCREATEROLE
  NOREPLICATION NOBYPASSRLS NOINHERIT;

-- RLS policy: readonly agent can SELECT only (in their tenant)
CREATE POLICY doc_readonly_select ON documents
  AS PERMISSIVE FOR SELECT TO mcp_readonly_agent
  USING (tenant_id = current_setting('app.tenant_id', true));

-- Grant: only execute read-only tool functions
GRANT EXECUTE ON FUNCTION mcp_get_document TO mcp_readonly_agent;
-- Note: no GRANT EXECUTE on mcp_create_draft or mcp_submit_archive_request
```

---

## Exercise 4: Blocked Operations

**Scenario A**: The INSERT succeeds (it is a valid INSERT with correct context). The UPDATE immediately raises:
```
ERROR: mcp_tool_calls is INSERT-only. Operation UPDATE is not permitted.
```
The immutability trigger fires before the UPDATE executes.

**Scenario B**: The SELECT returns only documents where `tenant_id = 'tenant-A'`. Documents for tenant-B are invisible — they do not appear in the result, and the agent has no way to know they exist.

**Scenario C**: The trigger `no_self_approval` fires and raises:
```
ERROR: Agent agent-1 cannot approve or reject its own pending approval request.
```
The UPDATE is rolled back.

---

## Exercise 5: mcp_submit_for_review

```sql
-- blocked: Docker not accessible
CREATE OR REPLACE FUNCTION mcp_submit_for_review(
  p_doc_id    UUID,
  p_agent_id  TEXT,
  p_tenant_id TEXT
) RETURNS JSONB
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_doc RECORD;
BEGIN
  PERFORM set_config('app.agent_id',  p_agent_id,  true);
  PERFORM set_config('app.tenant_id', p_tenant_id, true);

  SELECT id, status, created_by INTO v_doc
  FROM documents
  WHERE id = p_doc_id AND tenant_id = p_tenant_id;

  IF v_doc.id IS NULL THEN
    RETURN jsonb_build_object('error', 'document_not_found');
  END IF;

  IF v_doc.created_by != p_agent_id THEN
    RETURN jsonb_build_object('error', 'not_authorized',
      'message', 'Agent can only submit documents it created for review');
  END IF;

  IF v_doc.status != 'draft' THEN
    RETURN jsonb_build_object('error', 'invalid_status',
      'current_status', v_doc.status,
      'message', 'Only draft documents can be submitted for review');
  END IF;

  UPDATE documents SET status = 'review' WHERE id = p_doc_id;

  INSERT INTO mcp_tool_calls(tool_name, agent_id, tenant_id, input_json, success)
  VALUES ('submit_for_review', p_agent_id, p_tenant_id,
          jsonb_build_object('doc_id', p_doc_id), true);

  RETURN jsonb_build_object('document_id', p_doc_id, 'new_status', 'review');
END;
$$;

GRANT EXECUTE ON FUNCTION mcp_submit_for_review TO mcp_agent_role;
```

---

## Exercise 6: Audit Log Query

```sql
-- blocked: Docker not accessible
SELECT
  id,
  tool_name,
  input_json,
  called_at,
  success,
  error_message
FROM mcp_tool_calls
WHERE agent_id  = 'agent-abc'
  AND tenant_id = 'tenant-xyz'
  AND called_at > now() - INTERVAL '24 hours'
ORDER BY called_at DESC;
```

---

## Exercise 7: Pending Approvals Expiry

```sql
-- blocked: Docker not accessible
WITH expired AS (
  UPDATE pending_approvals
  SET
    status = 'expired',
    review_notes = coalesce(review_notes || ' | ', '') || 'Auto-expired at ' || now()::TEXT
  WHERE status = 'pending'
    AND expires_at < now()
  RETURNING id
)
SELECT count(*) AS rows_expired FROM expired;
```

---

## Exercise 8: Reflection Answers

**Q1: SECURITY DEFINER risk and mitigation**

Risk: if the function has a SQL injection vulnerability, the attacker gains the function owner's privileges (not the agent's minimal role). Mitigation: (1) all inputs are parameterized — no string concatenation into SQL; (2) inputs are validated before any SQL executes; (3) function owners have limited grants themselves (not superuser).

**Q2: Why pending_approvals instead of direct archive**

Archiving is irreversible. An agent that archives a document cannot unarchive it without a new approval workflow. Routing through pending_approvals gives a human the chance to catch a mistaken archive request before it executes.

**Q3: Should mcp_search_documents write to mcp_tool_calls?**

Yes. Logging reads is important for access auditability — knowing which agent searched for what at what time. Read logs are less critical than write logs but are still valuable for compliance (especially in regulated domains where data access must be logged).

**Q4: What breaks without FORCE ROW LEVEL SECURITY?**

Without `FORCE ROW LEVEL SECURITY`, the table owner (the PostgreSQL role that owns the table, typically the deploying role) bypasses all RLS policies. If a connection runs as that owner role (e.g., during a migration or manual query), it sees all rows from all tenants without any filtering. FORCE ensures policies apply even to the owner.
