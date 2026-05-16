# Agent Permission Ontology

> This ontology maps the permission structure for AI agents operating on PostgreSQL databases.
> Use [[wikilink]] format to navigate between related ontology files.

---

## Core Concepts

### Agent Role
A PostgreSQL role assigned to an agent. The agent role has the minimum privileges needed to call its authorized tool functions. It has no superuser attribute, no BYPASSRLS, no CREATEROLE, no DDL privileges, and no direct table grants beyond what tool functions require.

- SQL: `CREATE ROLE mcp_agent_role NOINHERIT NOCREATEROLE NOCREATEDB NOREPLICATION NOBYPASSRLS;`
- Related: [[mcp-tool-ontology]]
- Principle: one role per agent type (not per agent instance)

### RLS Policy
A predicate expression that PostgreSQL automatically appends to every query on a table. Policies are invisible to the agent — it cannot see them, cannot disable them, and cannot construct SQL that avoids them.

- Types: PERMISSIVE (ORed together), RESTRICTIVE (ANDed with all others)
- Clauses: USING (for SELECT/UPDATE/DELETE visibility), WITH CHECK (for INSERT/UPDATE values)
- Related: [[security-ontology]]

### Permission Boundary
The complete set of what an agent can and cannot do, defined by: role grants + RLS policies + function execution rights. The boundary is enforced at the database level, not in application code.

- Components:
  - Role-level: GRANT SELECT/INSERT/EXECUTE on specific objects
  - Row-level: RLS policies using current_setting('app.agent_id')
  - Function-level: SECURITY DEFINER mediates cross-privilege access

### SET LOCAL Context
The session-local variable pattern used to communicate agent identity to RLS policies and audit triggers without embedding it in SQL strings.

```sql
-- blocked: Docker not accessible
SET LOCAL app.agent_id  = 'agent-uuid-here';
SET LOCAL app.tenant_id = 'tenant-uuid-here';
SET LOCAL app.tool_name = 'get_document';
```

- Scope: lasts until end of current transaction (SET LOCAL) or session (SET)
- RLS reads: `current_setting('app.agent_id', true)` — second arg suppresses error if unset
- Audit trigger reads: same current_setting call

### BYPASSRLS
A role attribute that causes all RLS policies to be skipped for that role. This is a superpower equivalent that must never be granted to any agent role.

- Risk: an agent with BYPASSRLS can read and write all rows in all RLS-protected tables
- Detection: `SELECT rolname FROM pg_roles WHERE rolbypassrls = true;`
- Policy: only the postgres superuser should have this attribute, and only because it cannot be revoked from the superuser

### Least Privilege
The principle that an agent role should have exactly the permissions needed for its defined tools — no more. Adding a permission "just in case" is a violation of this principle.

- Checklist:
  - Does the agent need SELECT? Grant it only on the specific view/table.
  - Does the agent need INSERT? Grant it only on the specific table and columns.
  - Does the agent need UPDATE? Consider using a function instead of direct UPDATE grant.
  - Does the agent need DELETE? Almost never — use soft-delete.

### Audit Event
See [[agent-workflow-ontology]]. Audit events are the record of every permission exercise — every INSERT, UPDATE, DELETE that a permission allowed. Permissions without audit are unverifiable.

---

## Permission Levels

```
Superuser (postgres)
  └─ full database control; BYPASSRLS; DDL; DROP
  └─ NEVER used by agents

Service Role (app_service)
  └─ owns tables, creates functions, manages policies
  └─ NOT an agent role; used by deployment/migration processes

Agent Role (mcp_agent_role)
  └─ EXECUTE on specific functions
  └─ SELECT on specific views (RLS-protected)
  └─ INSERT on specific narrow tables (audit log, access log)
  └─ NO direct UPDATE/DELETE on business tables
  └─ NO BYPASSRLS, NO SUPERUSER, NO DDL
```

---

## Policy Design for Multi-Agent Systems

When multiple agent types exist, each needs its own role and its own set of RLS policies:

```
read_agent_role   → SELECT policies only; no INSERT
write_agent_role  → SELECT + INSERT policies; no UPDATE/DELETE
admin_agent_role  → SELECT + INSERT + UPDATE; high-risk ops via pending_actions
```

Restrictive policies (ANDed with all permissive policies) set hard upper bounds:

```sql
-- blocked: Docker not accessible
-- No agent, regardless of other policies, can see rows from other tenants
CREATE POLICY strict_tenant_isolation ON documents
  AS RESTRICTIVE FOR ALL TO mcp_agent_role
  USING (tenant_id = current_setting('app.tenant_id', true));
```

---

## Wikilinks

- [[agent-workflow-ontology]] — agent, action, audit, approval
- [[mcp-tool-ontology]] — tool schema, permission boundary, SECURITY DEFINER
- [[security-ontology]] — injection prevention, parameterized queries, least privilege
- [[human-approval-ontology]] — high-risk action routing, reviewer identity

---

## Key Invariants

1. Agent roles have NOBYPASSRLS — this is non-negotiable
2. Agent roles have no DDL privileges (no CREATE TABLE, ALTER TABLE, DROP)
3. Agent roles have no SUPERUSER attribute
4. RLS is enabled AND FORCED on all tables agents access
5. All permission grants are code-reviewed like any schema change
6. New tables default to RLS-enabled; agents must be explicitly granted access
