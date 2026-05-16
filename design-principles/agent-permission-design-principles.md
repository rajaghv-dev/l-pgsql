# Agent Permission Design Principles

Six principles for assigning and enforcing database permissions for AI agent roles. These principles ensure agents operate with the minimum access needed and cannot escalate their own privileges.

---

## Principle 1: Agent Roles Have No Superuser, No BYPASSRLS, No DDL Privileges

**The three absolute prohibitions: no superuser, no BYPASSRLS, no DDL.**

These three attributes — if granted to any agent role — defeat every other safety mechanism. A superuser can disable triggers, bypass RLS, and alter tables. BYPASSRLS means every RLS policy is silently ignored. DDL privileges mean the agent can alter or drop tables.

```sql
-- blocked: Docker not accessible

-- Agent role definition: every flag is explicitly denied
CREATE ROLE mcp_agent_role
  NOSUPERUSER
  NOCREATEROLE
  NOCREATEDB
  NOREPLICATION
  NOBYPASSRLS
  NOINHERIT;

-- Verify no agent role has dangerous attributes
SELECT rolname, rolsuper, rolbypassrls, rolcreaterole, rolcreatedb
FROM pg_roles
WHERE rolname LIKE 'mcp_%'
  AND (rolsuper OR rolbypassrls OR rolcreaterole);
-- Expected: zero rows
```

**Why**: A single mistaken SUPERUSER or BYPASSRLS grant defeats all permission engineering. Check this in CI as a schema validation test.

---

## Principle 2: One Role per Agent Type, Not per Agent Instance

**Define roles by agent function (read_agent, write_agent, approval_agent), not by individual agent identity.**

Creating one PostgreSQL role per agent instance (agent_abc, agent_def) creates role proliferation — hundreds of roles with identical permissions. Agent identity is tracked via `current_setting('app.agent_id')` and RLS, not via the PostgreSQL role.

```sql
-- blocked: Docker not accessible

-- Correct: roles by type
CREATE ROLE mcp_read_agent NOBYPASSRLS NOSUPERUSER;
CREATE ROLE mcp_write_agent NOBYPASSRLS NOSUPERUSER;
CREATE ROLE mcp_admin_agent NOBYPASSRLS NOSUPERUSER;

-- Agent identity via session context, not role
SET LOCAL app.agent_id = 'agent-instance-uuid';
-- RLS uses current_setting('app.agent_id') for row-level isolation
```

**Why**: Role-per-type is maintainable. Role-per-instance is unmanageable at scale and provides no additional security (RLS provides the per-instance isolation).

---

## Principle 3: RLS Policies Are Human-Reviewed Before Deployment

**Every new or modified RLS policy must be reviewed by a human before it reaches production.**

RLS policies are security-critical code. An incorrect policy (one that is too permissive or has a NULL-handling bug) can expose data silently — rows simply appear in query results when they should not. Automated testing catches obvious bugs; human review catches subtle logic errors.

Review checklist:
- Does the USING clause correctly handle NULL `current_setting` values?
- Is the policy PERMISSIVE or RESTRICTIVE? Is that intentional?
- Does the policy apply to all operations (ALL) or specific ones? Is that intentional?
- Is FORCE ROW LEVEL SECURITY set on the table so even the owner obeys the policy?

**Why**: A permissive-by-accident RLS policy is worse than no policy — it creates the illusion of security while providing none.

---

## Principle 4: Tool Input Validation Before Any Database Operation

**The application layer validates inputs; the database validates again. Both checks must pass.**

Input validation in the application layer catches problems early and produces helpful error messages. Database-level constraints (CHECK, NOT NULL, FOREIGN KEY) catch problems that slip through — including bugs in the application layer. Both layers are necessary; neither alone is sufficient.

```sql
-- blocked: Docker not accessible

-- Database-level validation that complements application-layer checks
ALTER TABLE invoices ADD CONSTRAINT amount_positive CHECK (amount > 0);
ALTER TABLE invoices ADD CONSTRAINT amount_realistic CHECK (amount < 100000000);
ALTER TABLE tasks ADD CONSTRAINT valid_status CHECK (
  status IN ('open','in_progress','blocked','review','closed')
);
```

**Why**: Application layer validation can be bypassed (a different code path, a bug, a new tool). Database constraints cannot be bypassed as long as the agent has no DDL privileges.

---

## Principle 5: Scope Permissions to Minimum Needed

**Grant the minimum set of privileges required for the agent's tools to function. Do not pre-grant future needs.**

Start with zero privileges. Add each grant with documented justification: "this agent needs INSERT on agent_reads because the get_case_notes tool must log every read access." If no justification can be stated, the grant does not happen.

```sql
-- blocked: Docker not accessible

-- Correct: explicit minimum grants with comments
GRANT EXECUTE ON FUNCTION get_case_notes(UUID) TO mcp_read_agent;
  -- Justification: read agent must retrieve case notes via the narrow tool

GRANT EXECUTE ON FUNCTION log_note_read(UUID) TO mcp_read_agent;
  -- Justification: read agent must log every access for compliance

-- Incorrect: pre-granting INSERT on all tables "just in case"
-- GRANT INSERT ON ALL TABLES IN SCHEMA public TO mcp_read_agent;
```

**Why**: Unused permissions are dormant risks. When the agent is compromised, an attacker can use any granted permission — including ones the agent never actually uses.

---

## Principle 6: Permission Reviews Are Triggered by Schema Changes

**Any new table, new function, or new tool must trigger a permission review.**

Schema drift — adding a new table without reviewing agent access — is a common source of permission gaps. When a new table has no RLS and the agent role has been granted blanket SELECT on the schema, the new table is immediately visible to all agents.

Enforcement:
- Migration scripts that create tables must explicitly set `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`
- CI tests verify RLS is enabled on all tables in the agent schema
- New functions default to no grants; grants are added explicitly with justification

```sql
-- blocked: Docker not accessible

-- CI validation query: fail if any agent-schema table lacks RLS
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename NOT IN (
    SELECT tablename FROM pg_tables t
    JOIN pg_class c ON c.relname = t.tablename
    WHERE c.relrowsecurity = true
  );
-- Expected: zero rows in agent schema
```

**Why**: Schema changes happen more frequently than permission audits. Automating the check ensures permissions are reviewed at the right time — when the schema changes.

---

## Summary

| # | Principle | Mechanism |
|---|-----------|-----------|
| 1 | No superuser, no BYPASSRLS, no DDL | Role creation flags; CI validation |
| 2 | One role per agent type | Roles named by function, not instance |
| 3 | Human review of RLS policies | Code review process; review checklist |
| 4 | Input validation at both layers | Application + CHECK constraints |
| 5 | Minimum necessary grants | Explicit grants with justification |
| 6 | Permission review on schema change | CI RLS check; migration conventions |
