# PostgreSQL for MCP Tools
Level: Intermediate

## One-line intuition
MCP tools are narrow, typed database interfaces that let AI agents perform exactly one well-scoped operation — and PostgreSQL's ACID guarantees, RLS, and trigger system make it the ideal backend.

## Why this exists
AI agents need to interact with persistent data. If an agent can run arbitrary SQL, it is one hallucinated statement away from dropping a production table. MCP (Model Context Protocol) solves this by defining a strict tool layer: the agent calls a named function with validated parameters, never touching raw SQL. PostgreSQL provides the enforcement and audit machinery underneath.

## First-principles explanation
An MCP tool is a contract: it has a name, an input schema, and a defined output. The database enforces the contract's side of the bargain — constraints reject invalid data, RLS restricts visible rows, triggers record every write. The agent has no escape hatch: it cannot craft arbitrary SQL, it cannot change its own permissions, and every action leaves a permanent record.

The stack looks like this:

```
Agent → MCP tool call (typed JSON)
     → Input validation (application layer)
     → SET LOCAL app.agent_id = '...'
     → Parameterized query against narrow view or function
     → RLS policy evaluates current_setting('app.agent_id')
     → Audit trigger fires on every write
     → ACID transaction commits or rolls back atomically
```

## Micro-concepts
- **MCP tool**: a named, typed interface an AI agent calls to interact with a system
- **Narrow interface**: one tool does exactly one thing (no "execute_sql" mega-tool)
- **Typed parameters**: every input has an explicit type — UUID, TEXT, NUMERIC — preventing injection
- **SET LOCAL**: sets a session-local variable that RLS policies can read
- **Audit trigger**: a BEFORE/AFTER trigger that writes to an insert-only log table
- **ACID**: atomicity ensures a multi-step agent operation either fully succeeds or fully rolls back

## Beginner view
Think of MCP tools as a cashier window at a bank. You can say "I want to deposit $50" or "check my balance" — you cannot walk into the vault yourself. PostgreSQL is the vault with armed guards (RLS) and a camera system (audit triggers).

## Intermediate view
MCP tools map cleanly to stored functions or parameterized queries. Each tool corresponds to one narrow database operation. The application layer validates inputs, sets the agent context via `SET LOCAL`, then executes the query. PostgreSQL does the rest: RLS filters rows, triggers log writes, transactions guarantee atomicity.

## Advanced view
At scale, each MCP tool becomes an API endpoint backed by a PostgreSQL function. The function signature is the contract. `SECURITY DEFINER` functions can cross privilege boundaries safely — the function runs as its owner (a service role with limited grants), not as the calling role. This means the agent role itself needs almost no direct table privileges; all access is mediated through functions with explicit GRANT EXECUTE.

## Mental model
MCP tools are the narrow doors on a vault. Each door opens to exactly one room. The agent picks a door (tool name), passes a key that matches the lock (typed input), and a camera records the entry (audit trigger). There is no master key, no skeleton key, and no way to break down a wall.

## PostgreSQL view
```sql
-- blocked: Docker not accessible
-- Conceptual example only

-- Agent role has no direct table access
CREATE ROLE mcp_agent_role;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM mcp_agent_role;

-- Access only through narrow functions
CREATE FUNCTION get_document(p_doc_id UUID, p_agent_id TEXT)
RETURNS TABLE(id UUID, title TEXT, body TEXT)
SECURITY DEFINER
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('app.agent_id', p_agent_id, true);
  RETURN QUERY
    SELECT d.id, d.title, d.body
    FROM documents d
    WHERE d.id = p_doc_id;
  -- RLS on documents table filters by current_setting('app.agent_id')
END;
$$;

GRANT EXECUTE ON FUNCTION get_document TO mcp_agent_role;

-- Audit trigger logs every function call result
CREATE TABLE mcp_tool_calls (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tool_name   TEXT NOT NULL,
  agent_id    TEXT NOT NULL,
  input_json  JSONB,
  called_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  success     BOOLEAN NOT NULL
);
```

## SQL view
Every MCP tool call becomes one parameterized query. The query never contains agent-supplied SQL fragments — only agent-supplied values bound as parameters. This is the difference between `WHERE id = $1` (safe) and `WHERE id = ` || agent_input (unsafe).

## Non-SQL or hybrid view
In a REST API world, MCP tools are endpoints — `POST /documents/{id}/read`. PostgreSQL sits behind the endpoint. The security model is the same: the HTTP layer validates inputs, the database enforces permissions. MCP makes this pattern explicit for AI agent runtimes.

## Design principle
**One tool, one operation.** A tool that can "do anything with documents" is not a tool — it is a footgun. Each MCP tool should have a name that fully describes its effect: `get_document`, `create_draft`, `submit_for_review`. The name is the contract.

## Critical thinking
- What if the agent calls the same tool 1000 times rapidly? Rate limiting belongs in the application layer, not the database — but the audit log will make the pattern visible.
- What if the input validation is too strict? The agent cannot complete legitimate tasks. Too loose, and injection becomes possible. Calibrate to the exact shape of valid inputs.
- What if the tool needs to span multiple tables? Wrap the multi-step operation in one function inside one transaction. The agent never sees intermediate state.

## Creative thinking
MCP tools can be designed as a graph: some tools unlock others. `submit_for_review` is only callable after `create_draft` has succeeded. PostgreSQL enforces this via foreign key relationships and status-column constraints — the tool cannot be called out of order because the database will reject the insert.

## Systems thinking
The MCP tool layer is a translation layer between unstructured agent intent and structured database operations. It absorbs ambiguity at the boundary and presents clean, typed, auditable operations to PostgreSQL. The health of the whole system depends on this boundary being narrow and explicit.

## MCP and agent perspective
From the agent's perspective, an MCP tool is an atomic capability. The agent does not need to know that there is a database behind it — it only sees the tool name and the typed inputs. This abstraction is intentional: the agent cannot reason about the database schema, cannot construct SQL, and cannot accidentally bypass the security layer.

## Ontology perspective
An MCP tool is an **action type** with a fixed **input schema** and a fixed **effect**. The effect is always one of: read state, write state, or read-then-write state. The database is the **state machine**. The audit log is the **event log** of all state transitions. Together they form a complete record of agent behavior.

## Practice session
1. List three operations that should each be a separate MCP tool for a task management system.
2. Sketch the audit trigger that fires when `create_draft` is called.
3. Explain why `SECURITY DEFINER` is preferable to granting the agent role direct table access.
4. Write the `SET LOCAL` statement that would set `app.agent_id` before an RLS-protected query.
5. What happens if the agent supplies a non-UUID string for a UUID parameter? Where should that be caught?

## References
- MCP Specification: https://spec.modelcontextprotocol.io/
- PostgreSQL Row Security Policies: https://www.postgresql.org/docs/16/ddl-rowsecurity.html
- PostgreSQL SET LOCAL: https://www.postgresql.org/docs/16/sql-set.html
- PostgreSQL SECURITY DEFINER: https://www.postgresql.org/docs/16/sql-createfunction.html
