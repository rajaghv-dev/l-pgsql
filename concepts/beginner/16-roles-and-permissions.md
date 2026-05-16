# Roles and Permissions

Level: Beginner

## One-line intuition

A role is a named identity in PostgreSQL that can log in, own objects, and have permissions granted to it — users and groups are both roles.

## Why this exists

Multiple people and services access the same database. Not all should be able to do the same things. Roles + grants implement the **principle of least privilege**: each identity gets exactly the access it needs, no more.

## First-principles explanation

In PostgreSQL, roles are unified — there is no separate concept of "user" vs "group." A role with `LOGIN` privilege is a user. A role without `LOGIN` is a group. A role can be a member of other roles (inheritance).

Permissions (privileges) are granted on specific objects (tables, sequences, schemas, databases). Privileges must be explicitly granted — nothing is allowed by default for new roles.

## Micro-concepts

| Concept | Command |
|---------|---------|
| Create a role | `CREATE ROLE name` |
| Create a login role (user) | `CREATE ROLE name LOGIN PASSWORD 'pw'` |
| Grant table privilege | `GRANT SELECT ON TABLE t TO role` |
| Revoke privilege | `REVOKE INSERT ON TABLE t FROM role` |
| Role membership (group) | `GRANT group_role TO member_role` |
| Grant on all tables | `GRANT SELECT ON ALL TABLES IN SCHEMA public TO role` |
| Default privileges | `ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO role` |

## Beginner view

Think of roles as key cards in an office:

- A **visitor** key card opens the lobby and meeting rooms only (SELECT on specific tables).
- A **staff** key card opens the lobby, offices, and kitchen (SELECT + INSERT on more tables).
- An **admin** key card opens everything (SUPERUSER — use sparingly).

```sql
-- Create a read-only role (group, no login)
CREATE ROLE readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;

-- Create a service account that can log in and inherits readonly
CREATE ROLE app_reader LOGIN PASSWORD 'secret' IN ROLE readonly;

-- Verify: app_reader inherits SELECT from readonly
-- REVOKE when done
REVOKE readonly FROM app_reader;
DROP ROLE app_reader;
DROP ROLE readonly;
```

## Intermediate view

**Schema permissions**: to access a table, a role needs:
1. `CONNECT` on the database
2. `USAGE` on the schema
3. Privilege on the specific table

Missing any one of the three = permission denied.

```sql
GRANT CONNECT ON DATABASE cfp TO app_reader;
GRANT USAGE ON SCHEMA public TO app_reader;
GRANT SELECT ON TABLE books TO app_reader;
```

**Row-level security (RLS)**: restrict which rows a role can see, not just which tables. Detail covered in intermediate stage.

**Default privileges**: grants applied to future objects created by a specific role:

```sql
-- Any table created by cfp in the public schema is automatically readable by readonly
ALTER DEFAULT PRIVILEGES FOR ROLE cfp IN SCHEMA public
GRANT SELECT ON TABLES TO readonly;
```

## Advanced view

- `GRANT ... WITH GRANT OPTION`: allows the grantee to grant the same privilege to others — use with caution.
- `SET ROLE role_name`: switch to a different role within a session (must be a member of that role).
- `pg_hba.conf`: authentication rules at the connection level — separate from object-level grants. Both must allow access for a connection to succeed.
- Auditing: log role changes and grants with `log_statement = 'ddl'`.

## Mental model

Think of permissions as a matrix:

```
         | SELECT | INSERT | UPDATE | DELETE |
---------|--------|--------|--------|--------|
readonly |   YES  |   NO   |   NO   |   NO   |
writer   |   YES  |   YES  |   YES  |   NO   |
admin    |   YES  |   YES  |   YES  |  YES   |
```

Roles group these matrix rows. Objects (tables) are the columns. GRANT fills a cell. REVOKE empties it.

## PostgreSQL view

```sql
-- View current role
SELECT current_user, session_user;

-- List all roles
SELECT rolname, rolcanlogin, rolsuper, rolinherit
FROM pg_roles
ORDER BY rolname;

-- View privileges on a table
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_name = 'books';

-- Check what roles the current user belongs to
SELECT rolname FROM pg_roles
WHERE pg_has_role(current_user, oid, 'member');
```

## SQL view

```sql
-- Production pattern: app role + migration role

-- Migration role: can CREATE/DROP tables
CREATE ROLE migrator LOGIN PASSWORD 'migrate_pw';
GRANT CREATE ON SCHEMA public TO migrator;

-- App role: can read/write data, cannot change schema
CREATE ROLE app_rw LOGIN PASSWORD 'app_pw';
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_rw;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_rw;

-- Reporting role: read-only
CREATE ROLE reporter LOGIN PASSWORD 'report_pw';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO reporter;
```

## Non-SQL or hybrid view

In application code, roles are analogous to authorization scopes in OAuth. The database role is the service account; the application-level user ID is embedded in the SQL query as a parameter or in a `SET LOCAL app.user_id = '...'` session variable (used with RLS).

## Design principle

**Principle of least privilege**: every role gets the minimum permissions needed to do its job. The cost of over-permission is a security incident. The cost of under-permission is a permission error — easy to fix. Err on the side of caution.

## Critical thinking

- `GRANT ALL ON ALL TABLES` is almost always wrong outside of development. In production, split read and write roles, and never give application roles DDL privileges.
- `SUPERUSER` bypasses all permission checks. Never use it for application connections. Assign SUPERUSER only to DBA accounts used for administration.

## Creative thinking

Combine roles with views for data masking:

```sql
-- View that hides PII for the analytics role
CREATE VIEW user_stats AS
SELECT id, created_at, country_code FROM users;  -- no email, no name

GRANT SELECT ON user_stats TO analyst;
REVOKE SELECT ON TABLE users FROM analyst;
```

Analysts get demographic data without seeing personal details.

## Systems thinking

In a multi-tenant SaaS system, roles + RLS + connection pooling interact:

- PgBouncer uses one application role (pooled connections).
- Row-level security uses a session variable to identify the tenant.
- Each role has only the privileges for its service.
- A compromised microservice can only access its own role's data.

## MCP and agent perspective

Agents that interact with the database should use dedicated roles:

```sql
-- Read-only agent role
CREATE ROLE mcp_agent_reader LOGIN PASSWORD 'agent_pw';
GRANT SELECT ON TABLE books, authors, checkouts TO mcp_agent_reader;
-- NOT: GRANT SELECT ON ALL TABLES

-- Write-scoped agent role (narrow scope)
CREATE ROLE mcp_agent_writer LOGIN PASSWORD 'agent_write_pw';
GRANT SELECT, INSERT ON TABLE orders TO mcp_agent_writer;
GRANT USAGE ON SEQUENCE orders_id_seq TO mcp_agent_writer;
-- Cannot UPDATE or DELETE
```

If the agent is compromised, the damage is limited to what the role can do. This is defense in depth.

## Ontology perspective

- A role is a **principal** — an identity in the access control system.
- A privilege is a **capability** — what operations a principal can perform on an object.
- GRANT is an **assertion** — it asserts that a principal has a capability.
- Role membership implements **inheritance** — a member inherits the capabilities of the group role.
- This system implements **discretionary access control (DAC)** — the owner of an object decides who can access it.

## Practice session

`practice/beginner/09-roles-basics/` — exercises: create a read-only role, grant SELECT, verify it cannot INSERT, agent angle example.

## References

| Resource | URL | Why |
|----------|-----|-----|
| PostgreSQL docs — Roles | https://www.postgresql.org/docs/current/user-manag.html | Role creation and management |
| PostgreSQL docs — Privileges | https://www.postgresql.org/docs/current/ddl-priv.html | Full privilege types per object |
| PostgreSQL docs — Row Security | https://www.postgresql.org/docs/current/ddl-rowsecurity.html | Row-level security overview |
| PostgreSQL docs — pg_hba.conf | https://www.postgresql.org/docs/current/auth-pg-hba-conf.html | Connection-level authentication |
