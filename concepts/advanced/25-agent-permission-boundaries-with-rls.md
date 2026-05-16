# Agent Permission Boundaries with RLS
Level: Advanced

## One-line intuition
Row-Level Security is the enforcement layer for agent permissions: it moves access control from application code into the database, where the agent cannot bypass it regardless of what SQL it generates.

## Why this exists
Application-layer access control (checking permissions in code before running SQL) fails when the SQL execution path changes — a new tool, a bug, a misconfiguration. RLS enforces permissions at the data layer: the row is simply invisible or unwritable to the wrong agent, no matter how the SQL was constructed.

## First-principles explanation
PostgreSQL RLS policies are predicate expressions attached to a table. Every query against that table has the policy's predicate appended automatically by the query planner:

- `SELECT * FROM documents` becomes effectively `SELECT * FROM documents WHERE agent_id = current_setting('app.agent_id')`
- The agent cannot remove this predicate — it is enforced before the query executes
- The agent cannot see that the predicate exists — filtered rows appear to not exist

For multi-agent systems, the pattern is:
1. Set the agent context: `SET LOCAL app.agent_id = 'agent-uuid'`
2. Execute the query — RLS appends the filter automatically
3. Audit trigger fires on any write — records the agent_id from current_setting

The `current_setting('app.agent_id')` call inside policy expressions reads the session-local variable set in step 1. This is how the database knows which agent is acting, without any application code involved in the filtering.

## Micro-concepts
- **RLS policy**: a predicate expression automatically ANDed onto every query for a table
- **USING clause**: the filter applied to SELECT, UPDATE, DELETE — which rows are visible
- **WITH CHECK clause**: the filter applied to INSERT, UPDATE — which values are allowed to be written
- **current_setting('app.agent_id')**: reads the session-local variable set by SET LOCAL
- **BYPASSRLS**: a role attribute that causes all RLS policies to be skipped — extremely dangerous for agent roles
- **FORCE ROW LEVEL SECURITY**: applied to table owners so that even the owner obeys RLS
- **Policy stacking**: multiple policies on the same table are ORed together (permissive) or ANDed (restrictive)

## Beginner view
Imagine RLS as an invisible filter on every query. You ask for all documents; the database secretly appends "but only yours" before running the query. You never know it happened. You cannot remove the filter. You cannot see what's hidden.

## Intermediate view
```sql
-- blocked: Docker not accessible

-- Enable RLS on the documents table
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents FORCE ROW LEVEL SECURITY;

-- Agents can only see documents in their tenant
CREATE POLICY agent_tenant_isolation ON documents
  AS PERMISSIVE FOR ALL
  TO mcp_agent_role
  USING (tenant_id = current_setting('app.tenant_id'))
  WITH CHECK (tenant_id = current_setting('app.tenant_id'));

-- Agents can only read (not write) documents they did not create
CREATE POLICY agent_read_others ON documents
  AS PERMISSIVE FOR SELECT
  TO mcp_agent_role
  USING (tenant_id = current_setting('app.tenant_id'));

-- Agents can only write documents they created
CREATE POLICY agent_write_own ON documents
  AS PERMISSIVE FOR INSERT
  TO mcp_agent_role
  WITH CHECK (
    tenant_id = current_setting('app.tenant_id') AND
    created_by = current_setting('app.agent_id')
  );
```

## Advanced view
The `current_setting` → RLS → audit trigger chain is the complete enforcement stack:

```sql
-- blocked: Docker not accessible

-- The tool function sets context, then queries
CREATE OR REPLACE FUNCTION mcp_get_document(p_doc_id UUID)
RETURNS TABLE(id UUID, title TEXT, body TEXT)
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_agent_id TEXT := current_setting('app.agent_id', true);
BEGIN
  -- Validate context was set by caller
  IF v_agent_id IS NULL OR v_agent_id = '' THEN
    RAISE EXCEPTION 'app.agent_id not set — call SET LOCAL before invoking tools';
  END IF;

  RETURN QUERY
    SELECT d.id, d.title, d.body
    FROM documents d
    WHERE d.id = p_doc_id;
  -- RLS automatically adds: AND d.tenant_id = current_setting('app.tenant_id')
  -- and the agent cannot override this
END;
$$;

-- Per-agent restrictive policy (ANDed with all permissive policies)
CREATE POLICY agent_scope_restriction ON documents
  AS RESTRICTIVE FOR ALL
  TO mcp_agent_role
  USING (
    EXISTS (
      SELECT 1 FROM agent_permissions ap
      WHERE ap.agent_id = current_setting('app.agent_id')
        AND ap.table_name = 'documents'
        AND ap.can_select = true
    )
  );
```

## Mental model
RLS is a guard that sits at the door of each table. Before any row passes through — going in or coming out — the guard checks: "Does this row's tenant_id match the current agent's tenant_id?" If not, the row is invisible. The guard cannot be bribed, bypassed, or turned off by the agent. Only a human with ALTER TABLE authority can remove the guard.

The BYPASSRLS attribute is a master key that defeats all guards. Never give this key to an agent role.

## PostgreSQL view
```sql
-- blocked: Docker not accessible

-- Check which roles have BYPASSRLS (should be empty except postgres superuser)
SELECT rolname, rolbypassrls
FROM pg_roles
WHERE rolbypassrls = true;

-- Verify RLS is enabled on sensitive tables
SELECT schemaname, tablename, rowsecurity, forcerowsecurity
FROM pg_tables
WHERE tablename IN ('documents', 'agent_memory', 'cases');

-- Inspect active policies
SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'documents';

-- Test what an agent sees (simulate agent context)
SET LOCAL app.agent_id = 'agent-123';
SET LOCAL app.tenant_id = 'tenant-456';
SELECT * FROM documents; -- RLS filters automatically
RESET app.agent_id;
```

## SQL view
Policy expressions are arbitrary SQL predicates. They can join other tables (expensive but powerful), call functions, use current_setting. Keep policy expressions simple — a complex policy predicate runs on every row touched by every query.

## Non-SQL or hybrid view
Application-layer permission checks (if user.tenant_id == doc.tenant_id: ...) fail silently when bypassed. Database RLS fails loudly: the row is not returned, and the constraint violation is logged. Move permissions into the database where the agent cannot reason about them.

## Design principle
**BYPASSRLS must never be granted to any agent role.** This is non-negotiable. An agent with BYPASSRLS can see every row in every RLS-protected table. There is no safe way to use BYPASSRLS with agent roles — redesign the access pattern instead.

## Critical thinking
- **Policy performance**: every RLS policy expression runs per row. A JOIN in a policy expression can cause N+1 query patterns. Use current_setting for simple scalar lookups; pre-join data using views for complex access rules.
- **Policy gaps**: forgetting to enable RLS on a new table means no filtering. Use a database-level assertion check that RLS is enabled on all tables in the agent schema.
- **Policy conflicts**: two permissive policies OR together — an agent might see more rows than intended. Use a restrictive policy as an explicit upper bound.
- **Connection pooling**: PgBouncer in transaction mode resets session settings between transactions. SET LOCAL is safe because it resets automatically at transaction end. Do not use SET (session-level) in pooled environments.

## Creative thinking
Design per-agent RLS: each agent in a multi-agent system has different row visibility. Store agent permissions in an `agent_permissions` table. The RLS policy joins this table. Now you can add or revoke per-row access for specific agents without changing policies — just update the permissions table.

## Systems thinking
RLS is a **membrane** between the agent and the data. Everything that crosses the membrane — queries, inserts, updates — must pass through the policy predicates. The membrane is defined by humans (in the policy) and enforced by the database engine. The agent lives entirely outside the membrane; it can only interact through policy-sanctioned operations.

## MCP and agent perspective
From the MCP perspective, RLS is invisible but essential. The tool function does not include filtering in its WHERE clause — that would be application-layer access control. Instead, RLS applies the filter automatically. The tool's SQL is clean and readable; the enforcement is structural. The agent cannot reason about or bypass this enforcement layer.

## Ontology perspective
RLS policies form a **permission ontology**: each policy is a named rule with a subject (role), a predicate (the USING expression), and an action (SELECT/INSERT/UPDATE/DELETE). The policies together define the **permission boundary** for each role. The boundary is part of the database schema — version-controlled, audited, and reviewed like any other schema change.

## Practice session
1. Write a policy that allows an agent to SELECT any document in its tenant, but only INSERT documents where `created_by = current_setting('app.agent_id')`.
2. Explain the difference between a PERMISSIVE and RESTRICTIVE policy, and give a use case for each.
3. What happens if `SET LOCAL app.tenant_id` is not called before a query hits an RLS-protected table? Write the policy that handles this case safely.
4. Why is `FORCE ROW LEVEL SECURITY` important even for table owners?
5. Describe a scenario where a policy JOIN causes a performance problem, and propose a solution.

## References
- PostgreSQL Row Security: https://www.postgresql.org/docs/16/ddl-rowsecurity.html
- PostgreSQL current_setting: https://www.postgresql.org/docs/16/functions-admin.html
- RLS Performance: https://www.postgresql.org/docs/16/row-security.html
- BYPASSRLS: https://www.postgresql.org/docs/16/sql-createrole.html
