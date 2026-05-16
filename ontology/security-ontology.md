# Security Ontology

Level: Intermediate → Advanced
Domain: PostgreSQL / Security

## Definition
PostgreSQL security is a layered model combining authentication (who you are), authorization (what you can do via roles and privileges), row-level security (which rows you can see or modify), and encryption (pgcrypto) — enforced at the database engine level independently of the application.

## Why this concept matters
Database security is the last line of defense. Application-level bugs (SQL injection, authorization bypass) can only cause damage if the database does not enforce least-privilege access. RLS, roles, and audit logs are the tools that make multi-tenant and regulated applications safe.

## Related concepts
- [[schema-design-ontology]] — parent (objects that security applies to)
- [[transaction-ontology]] — related (RLS policies evaluated per transaction)
- [[ai-agent-memory-ontology]] — child (tenant isolation, RLS for agents)
- [[extension-ontology]] — related (pgcrypto is an extension)
- [[observability-ontology]] — related (audit logging)

---

## Role

One-line definition: A named database principal that can represent a user, a group, or a service account; roles own objects and are granted privileges.

```sql
-- blocked: Docker not accessible
-- Create roles
CREATE ROLE app_user LOGIN PASSWORD 'secret';
CREATE ROLE app_readonly NOLOGIN;  -- group role, no direct login
CREATE ROLE app_admin LOGIN SUPERUSER;

-- Grant group role to user
GRANT app_readonly TO app_user;

-- Inspect roles
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin
FROM pg_roles ORDER BY rolname;
```

Role attributes:
| Attribute | Meaning |
|-----------|---------|
| `LOGIN` | Can authenticate (is a user) |
| `SUPERUSER` | Bypasses all permission checks |
| `CREATEDB` | Can create databases |
| `CREATEROLE` | Can create other roles |
| `BYPASSRLS` | Ignores row-level security policies |
| `REPLICATION` | Can initiate streaming replication |

---

## Grant / Privilege

One-line definition: A privilege is a named permission on an object; GRANT assigns it to a role; REVOKE removes it.

```sql
-- blocked: Docker not accessible
-- Object-level privileges
GRANT SELECT ON TABLE orders TO app_readonly;
GRANT INSERT, UPDATE ON TABLE orders TO app_user;
GRANT ALL ON TABLE orders TO app_admin;

-- Schema-level (must also grant USAGE on schema)
GRANT USAGE ON SCHEMA app TO app_user;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO app_readonly;

-- Default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA app
    GRANT SELECT ON TABLES TO app_readonly;

-- Revoke
REVOKE DELETE ON TABLE orders FROM app_user;

-- Inspect
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_name = 'orders';
```

Privilege types: `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER`, `EXECUTE`, `USAGE`, `CREATE`, `CONNECT`, `TEMPORARY`.

---

## Row-Level Security (RLS)

One-line definition: A PostgreSQL mechanism that enforces per-row access control by attaching security policies to a table, filtering rows before they are returned or modified.

```sql
-- blocked: Docker not accessible
-- Enable RLS on a table
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
-- FORCE ROW LEVEL SECURITY applies policies even to the table owner
ALTER TABLE orders FORCE ROW LEVEL SECURITY;

-- Create policies
-- SELECT policy: users see only their own orders
CREATE POLICY orders_tenant_isolation ON orders
    FOR SELECT
    USING (tenant_id = current_setting('app.current_tenant')::BIGINT);

-- INSERT policy: can only insert rows for their own tenant
CREATE POLICY orders_insert ON orders
    FOR INSERT
    WITH CHECK (tenant_id = current_setting('app.current_tenant')::BIGINT);

-- Inspect policies
SELECT * FROM pg_policies WHERE tablename = 'orders';

-- Drop policy
DROP POLICY orders_tenant_isolation ON orders;
```

`USING` — filters rows on read (SELECT, UPDATE WHERE, DELETE WHERE).
`WITH CHECK` — validates rows on write (INSERT, UPDATE new values).

---

## Policy

One-line definition: A named RLS rule on a table specifying which roles it applies to, the command (`SELECT`/`INSERT`/`UPDATE`/`DELETE`/`ALL`), and the row-level predicate.

Permissive vs Restrictive:
- **PERMISSIVE** (default): Multiple policies are ORed — a row is accessible if any policy allows it.
- **RESTRICTIVE**: Multiple policies are ANDed — a row is accessible only if all restrictive policies allow it.

```sql
-- blocked: Docker not accessible
-- Restrictive policy: even if a permissive policy allows it, this must also pass
CREATE POLICY active_only ON orders
    AS RESTRICTIVE
    USING (is_active = true);
```

---

## Tenant Isolation

One-line definition: A multi-tenancy pattern where each tenant's data is isolated via RLS policies keyed on a `tenant_id` column, preventing cross-tenant data leakage.

Pattern:
1. Add `tenant_id` to every tenant-scoped table.
2. Enable RLS and FORCE RLS on each table.
3. Set `app.current_tenant` as a session-level setting from the connection pool.
4. Create `USING (tenant_id = current_setting('app.current_tenant')::BIGINT)` policies.
5. Application-level superuser bypasses RLS for admin operations only.

Related: [[ai-agent-memory-ontology]]

---

## pgcrypto

One-line definition: A PostgreSQL extension providing symmetric encryption, public-key encryption, hashing (MD5, SHA), and UUID generation functions.

```sql
-- blocked: Docker not accessible
CREATE EXTENSION pgcrypto;

-- Hash a password (bcrypt)
SELECT crypt('my_password', gen_salt('bf', 10));

-- Verify
SELECT (stored_hash = crypt('input_password', stored_hash)) AS match FROM users WHERE id = 1;

-- Symmetric encryption (AES-128)
SELECT pgp_sym_encrypt('secret data', 'passphrase');
SELECT pgp_sym_decrypt(encrypted_col, 'passphrase') FROM sensitive_table;

-- Generate UUID
SELECT gen_random_uuid();
```

Related: [[extension-ontology]]

---

## Audit Log

One-line definition: An append-only record of data modification events (who, what, when, before/after values) used for compliance, debugging, and security forensics.

Implementation patterns:
1. **Trigger-based**: Write-audit trigger on each table, inserts into an `audit.log` table.
2. **pgaudit extension**: Session-level or object-level audit logging to the PostgreSQL log file.
3. **Application-level**: Application writes events to an event log table before committing business data.

```sql
-- blocked: Docker not accessible
-- Simple audit table pattern
CREATE TABLE audit.changes (
    id          BIGSERIAL PRIMARY KEY,
    table_name  TEXT NOT NULL,
    operation   TEXT NOT NULL,  -- INSERT, UPDATE, DELETE
    row_id      BIGINT,
    old_data    JSONB,
    new_data    JSONB,
    changed_by  TEXT NOT NULL DEFAULT current_user,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Related: [[ai-agent-memory-ontology]], [[observability-ontology]]

---

## BYPASSRLS

One-line definition: A role attribute that causes RLS policies to be ignored for that role; only superusers and roles with explicit `BYPASSRLS` attribute bypass RLS.

Caution: Any role with `BYPASSRLS` can read all tenant data. Grant only to dedicated admin/migration roles, never to application service accounts.

```sql
-- blocked: Docker not accessible
CREATE ROLE db_admin LOGIN BYPASSRLS;
-- Check which roles bypass RLS
SELECT rolname FROM pg_roles WHERE rolbypassrls;
```

---

## Principle of Least Privilege

One-line definition: Each role should have only the minimum permissions required for its function — no more.

Checklist:
- Application user: `SELECT`, `INSERT`, `UPDATE` on specific tables; never `DELETE` unless required; never DDL.
- Read-only user: `SELECT` only; `USAGE` on schemas.
- Migration user: DDL permissions; no production data access.
- Admin user: `BYPASSRLS` + DDL; never used by application code.
- Avoid `SUPERUSER` for any application role.

---

## System catalog reference
- `pg_roles` — all roles and their attributes
- `pg_policies` — RLS policies
- `information_schema.role_table_grants` — privilege grants
- `information_schema.table_privileges` — table-level privileges
- `pg_auth_members` — role membership graph

---

## Beginner mental model
Security is layered: PostgreSQL first checks if you can log in (authentication via pg_hba.conf), then checks if you can connect to the database (CONNECT privilege), then checks if you have permission on each object (GRANT), and finally checks if RLS allows the specific row. Each layer must pass.

## Intermediate mental model
Use role groups to manage permissions at scale: create `app_readonly`, `app_readwrite` group roles, grant them appropriate privileges, then add individual login roles to those groups. RLS sits below the application and filters rows regardless of how the query is constructed — it cannot be bypassed by SQL injection unless the attacker gains a BYPASSRLS role.

## Advanced mental model
RLS policies interact with plan caching — parameterized plans must be re-evaluated when the tenant context changes. `current_setting('app.current_tenant')` is the safest way to pass tenant context; `SET LOCAL` confines it to the current transaction. Audit triggers must write to their own table in a separate transaction context (using `pg_background` or deferred) to avoid losing the audit record on rollback.

## MCP and agent perspective
An AI agent is a service account — it should have exactly the privileges needed for its declared tasks, nothing more. Agents should never hold SUPERUSER or BYPASSRLS. Tenant context must be set before any agent-issued query (`SET app.current_tenant = ?`). Agents generating schema changes must route them through a human-approval step. Audit log tables must be append-only (no UPDATE/DELETE privilege for the agent role).

## Practical implication
| Situation | Implication |
|-----------|-------------|
| Application connects as superuser | One SQL injection vulnerability exposes entire database |
| RLS enabled but FORCE RLS not set | Table owner bypasses RLS — use FORCE RLS always |
| Missing BYPASSRLS check in migration script | Migrations may silently pass RLS filters and miss rows |
| Permissive policies ORed inadvertently | Data leak: row visible if any policy passes, not all |
| Audit trigger missing on a table | That table's changes are not logged; compliance gap |
| `pgcrypto` not installed | Cannot hash passwords in-database; rely on application |

## Obsidian connections
[[schema-design-ontology]] [[transaction-ontology]] [[ai-agent-memory-ontology]] [[extension-ontology]] [[observability-ontology]]

## References
- PostgreSQL Roles: https://www.postgresql.org/docs/16/user-manag.html
- Row Security Policies: https://www.postgresql.org/docs/16/ddl-rowsecurity.html
- pgcrypto: https://www.postgresql.org/docs/16/pgcrypto.html
- pgaudit extension: https://github.com/pgaudit/pgaudit
