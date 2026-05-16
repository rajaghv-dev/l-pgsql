# Agent-Safe Database Actions
Level: Intermediate

## One-line intuition
Safe agent actions are "write-narrow, read-wide": agents can see broadly but can only write to tightly scoped targets, and never without a human approval gate for high-risk operations.

## Why this exists
An AI agent making a mistake in a database can be catastrophic and invisible. Unlike a human who might pause before hitting DELETE, an agent will execute whatever its reasoning produces without hesitation. The database must be the backstop — not the agent's own judgment.

## First-principles explanation
Agent safety in a database context comes from three layers:

1. **Permission layer**: the agent role has only the grants it absolutely needs — typically SELECT on views, INSERT on specific tables, EXECUTE on specific functions. No UPDATE, no DELETE, no DDL.
2. **Constraint layer**: CHECK constraints, NOT NULL, foreign keys, and unique constraints reject invalid data before it lands.
3. **Audit layer**: every write, even a rejected one, leaves a record.

The key insight is that safety is not about trusting the agent — it is about designing the system so that an agent mistake causes a constraint violation or an audit alert, not silent data corruption.

## Micro-concepts
- **Write-narrow**: agent INSERT targets only specific columns; UPDATE targets only specific rows by primary key
- **Read-wide**: agent SELECT can scan broadly, subject to RLS filtering
- **Human approval gateway**: `pending_actions` table holds high-risk operations until a human approves
- **Compensation pattern**: if a transaction fails, a compensation event is recorded instead of leaving state inconsistent
- **Transaction boundary**: multi-step agent operations wrap in one BEGIN/COMMIT so they atomically succeed or fail
- **SKIP LOCKED**: prevents two agent instances from processing the same pending action

## Beginner view
Safe agent actions are like letting someone use a library: they can browse any shelf (read-wide), but they can only write their name in the sign-out book (write-narrow), and a librarian must approve taking rare books (human approval gateway).

## Intermediate view
```sql
-- blocked: Docker not accessible

-- Safe: agent can only insert a read-log entry, never modify the source record
GRANT INSERT ON agent_read_log TO mcp_agent_role;
GRANT SELECT ON documents_view TO mcp_agent_role;

-- Unsafe operation caught by missing grant:
-- UPDATE documents SET title = '...' -- permission denied

-- Unsafe operation caught by constraint:
-- INSERT INTO agent_read_log(agent_id, doc_id)
-- VALUES (NULL, '...') -- violates NOT NULL
```

## Advanced view
The pending_actions pattern is the critical design for high-risk operations:

```sql
-- blocked: Docker not accessible

CREATE TABLE pending_actions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_type  TEXT NOT NULL,
  target_table TEXT NOT NULL,
  target_id    UUID NOT NULL,
  payload      JSONB NOT NULL,
  requested_by TEXT NOT NULL,   -- agent_id
  status       TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','approved','rejected','expired')),
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_by  TEXT,
  reviewed_at  TIMESTAMPTZ,
  expires_at   TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '24 hours'
);

-- Agent inserts a pending action; cannot approve its own request
-- Human reviews and sets status = 'approved'
-- Background job picks up approved actions with SKIP LOCKED
```

## Mental model
Think of an agent as a junior employee on their first week. They can read any file in the shared drive (read-wide with RLS limiting to their department). They can submit a form to request an action (pending_actions). They cannot open the safe, run the shredder, or override the boss's signature (no dangerous grants). Their manager approves the form (human approval gateway).

## PostgreSQL view
```sql
-- blocked: Docker not accessible

-- Safe: narrow INSERT via trigger-protected function
CREATE OR REPLACE FUNCTION agent_create_draft(
  p_agent_id TEXT,
  p_title    TEXT,
  p_content  TEXT
) RETURNS UUID
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_doc_id UUID;
BEGIN
  -- Input validation
  IF length(p_title) = 0 OR length(p_title) > 500 THEN
    RAISE EXCEPTION 'title must be 1-500 characters';
  END IF;

  INSERT INTO documents(title, body, status, created_by)
  VALUES (p_title, p_content, 'draft', p_agent_id)
  RETURNING id INTO v_doc_id;

  -- Audit
  INSERT INTO mcp_tool_calls(tool_name, agent_id, input_json, success)
  VALUES ('create_draft', p_agent_id,
          jsonb_build_object('title', p_title), true);

  RETURN v_doc_id;
END;
$$;
```

## SQL view
The safest SQL an agent can run is a parameterized query against a view with RLS. The agent supplies values, never SQL structure. The view hides columns the agent should not see. RLS hides rows belonging to other tenants.

## Non-SQL or hybrid view
In event-sourced systems, agents never mutate state directly — they append events. PostgreSQL can model this: every agent write is an INSERT to an event log; a separate projection materializes current state. The agent cannot corrupt existing events because INSERT-only tables have a trigger that rejects UPDATE and DELETE.

## Design principle
**Unsafe by default; safe by grant.** Start with an agent role that has zero privileges. Add grants one at a time, with justification. If the agent does not need to DELETE, never grant DELETE — not even temporarily.

## Critical thinking
- **DELETE without WHERE**: the most dangerous SQL statement. Agents should never have DELETE privileges. If records must be removed, use soft-delete (status = 'deleted') so the row remains auditable.
- **TRUNCATE**: even more dangerous than DELETE — it bypasses triggers. Never grant TRUNCATE to any agent role.
- **Schema changes**: DDL (ALTER TABLE, DROP TABLE) requires superuser or ownership. Agent roles must never own tables.
- **What if an agent needs to "update" a record?** Design as INSERT of a new version row with a supersedes_id column. The old row is never modified.

## Creative thinking
Design a "shadow mode" for new agent capabilities: when first deployed, a new tool writes to a shadow table alongside its real target. Humans compare the shadow writes against expected behavior. Only after validation does the tool write to the real table. This pattern tests agent behavior without risk.

## Systems thinking
Agent safety is a property of the system, not of the agent. A safe agent in an unsafe system is still dangerous. The system must assume the agent will eventually produce a malformed or malicious-looking action and be designed to absorb that without damage.

## MCP and agent perspective
From the MCP perspective, tools are classified at design time as: read-only, write-narrow, or write-wide. Write-wide tools should not exist. Write-narrow tools may execute directly. Read-only tools always execute directly. Any operation that cannot be classified as write-narrow should route through the pending_actions gateway.

## Ontology perspective
Safe actions form a **permission lattice**: SELECT < INSERT-narrow < UPDATE-by-ID < DELETE-by-ID < DDL. Agents live at the bottom of this lattice. Each rung up requires a new human decision, a new audit trail, and a new approval workflow.

## Practice session
1. List five SQL operations that an agent should never have direct access to, and explain why for each.
2. Write a `pending_actions` INSERT that represents an agent requesting to archive a document.
3. Explain the difference between soft-delete (status column) and hard-delete. Which is safer for agents and why?
4. What constraint would prevent an agent from setting status = 'approved' on its own pending action?
5. Describe what SKIP LOCKED does in a pending_actions processing queue.

## References
- PostgreSQL Privileges: https://www.postgresql.org/docs/16/ddl-priv.html
- PostgreSQL Row Security: https://www.postgresql.org/docs/16/ddl-rowsecurity.html
- SELECT FOR UPDATE SKIP LOCKED: https://www.postgresql.org/docs/16/sql-select.html
- OWASP Least Privilege: https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html
