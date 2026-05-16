# Security Hardening and Auditability

Level: Advanced

## One-line intuition
PostgreSQL's default configuration prioritizes convenience over security — hardening means restricting access at the network, authentication, and privilege layers, while auditability means creating immutable trails of every data change without relying on the unavailable pgaudit extension.

## Why this exists
A freshly installed PostgreSQL cluster accepts local connections without passwords, has a superuser with no password, and logs nothing by default. In production, this is a liability. Security hardening addresses the layers where PostgreSQL is exposed: network access, authentication strength, privilege model, and data confidentiality. Auditability addresses the requirement to know who changed what and when — especially for compliance (HIPAA, SOC 2, PCI DSS).

## First-principles explanation

### pg_hba.conf — the authentication firewall
`pg_hba.conf` (Host-Based Authentication) controls who can connect. Each line: `TYPE DATABASE USER ADDRESS METHOD`.

```conf
# Type    Database    User      Address           Method
local     all         postgres                    peer          # OS user match
local     all         all                         md5           # local with password
host      mydb        app_user  10.0.0.0/8        scram-sha-256 # network with SCRAM
host      all         all       0.0.0.0/0         reject        # deny everything else
hostssl   all         all       0.0.0.0/0         scram-sha-256 # SSL only
```

**Hardening rules**:
1. Use `scram-sha-256` (not `md5`) — MD5 is cryptographically weak
2. Use `hostssl` instead of `host` for all network connections — enforces TLS
3. Restrict `ADDRESS` to known IP ranges (application server IPs, not 0.0.0.0/0)
4. Never use `trust` for network connections (allows connection without password)
5. The `peer` method (matching OS username to DB username) is appropriate for local admin access only

Reload without restart: `SELECT pg_reload_conf();`

### SSL/TLS configuration
Enable SSL in `postgresql.conf`:
```conf
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
ssl_ca_file = 'ca.crt'              # for client certificate auth
ssl_min_protocol_version = 'TLSv1.2'
ssl_ciphers = 'HIGH:!aNULL:!MD5'   # disable weak ciphers
```

Verify SSL in use:
```sql
-- blocked: Docker not accessible
SELECT ssl, client_addr, usename FROM pg_stat_ssl
JOIN pg_stat_activity USING (pid);
```

### Least-privilege role model
```sql
-- blocked: Docker not accessible
-- Application user: minimal privileges
CREATE ROLE app_user LOGIN PASSWORD 'strong_password';
GRANT CONNECT ON DATABASE mydb TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- Read-only reporting user
CREATE ROLE reporting_user LOGIN PASSWORD 'strong_password';
GRANT CONNECT ON DATABASE mydb TO reporting_user;
GRANT USAGE ON SCHEMA public TO reporting_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO reporting_user;

-- Never give SUPERUSER to application accounts
-- Never give CREATEROLE or CREATEDB unless required

-- Revoke public schema creation (PG 15+ default)
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
```

### Default privilege management
```sql
-- blocked: Docker not accessible
-- Ensure future tables are accessible to app_user
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO app_user;
```

### Row-level encryption with pgcrypto
```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Store encrypted PII
CREATE TABLE user_profiles (
    id serial PRIMARY KEY,
    user_id bigint NOT NULL,
    encrypted_ssn bytea,   -- encrypted with pgp_sym_encrypt
    encrypted_dob bytea
);

-- Insert with encryption
INSERT INTO user_profiles (user_id, encrypted_ssn)
VALUES (42, pgp_sym_encrypt('123-45-6789', current_setting('app.encryption_key')));

-- Read with decryption (only if key is set)
SELECT user_id, pgp_sym_decrypt(encrypted_ssn, current_setting('app.encryption_key')) AS ssn
FROM user_profiles WHERE user_id = 42;

-- Key rotation: re-encrypt with new key
UPDATE user_profiles
SET encrypted_ssn = pgp_sym_encrypt(
    pgp_sym_decrypt(encrypted_ssn, 'old_key'),
    'new_key'
)
WHERE ...; -- requires knowing the old key
```

**Key management**: The encryption key should NOT be stored in the database. Pass it via application configuration, environment variable, or a secrets manager (Vault, AWS Secrets Manager). `current_setting('app.encryption_key')` retrieves a session-level setting set by the application on connect.

### Trigger-based audit logging (without pgaudit)
```sql
-- blocked: Docker not accessible
-- Audit log table
CREATE TABLE audit_log (
    id bigserial PRIMARY KEY,
    table_name text NOT NULL,
    operation text NOT NULL,       -- INSERT, UPDATE, DELETE
    row_id bigint,
    old_data jsonb,
    new_data jsonb,
    changed_by text NOT NULL DEFAULT current_user,
    changed_at timestamptz NOT NULL DEFAULT now(),
    app_user text,                 -- set by application via SET LOCAL
    session_id text
);

-- Generic audit trigger function
CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO audit_log (table_name, operation, row_id, old_data, new_data, app_user)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        CASE TG_OP WHEN 'DELETE' THEN OLD.id ELSE NEW.id END,
        CASE TG_OP WHEN 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
        CASE TG_OP WHEN 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
        current_setting('app.current_user_id', true)
    );
    RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

-- Apply to a table
CREATE TRIGGER orders_audit
    AFTER INSERT OR UPDATE OR DELETE ON orders
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();
```

Set application-level user context on connect:
```sql
-- blocked: Docker not accessible
-- Application sets this on every connection acquisition
SET LOCAL app.current_user_id = '42';  -- the application user ID, not DB role
```

### Connection security with PgBouncer
PgBouncer is a connection pooler that also provides security benefits:
- Hides database credentials from application (application authenticates to PgBouncer)
- Enables connection rate limiting per user
- Provides a stable connection endpoint that survives database failovers
- In `session` mode: each logical connection maps to a physical connection with full state
- In `transaction` mode: physical connections are shared — SET LOCAL applies only within the transaction (safe for app.current_user_id)

PgBouncer `pg_hba.conf` equivalent: `userlist.txt` with scram-sha-256 hashed passwords.

### postgresql.conf security settings
```conf
# Logging for security visibility
log_connections = on            # log every connection attempt
log_disconnections = on         # log disconnections
log_duration = off              # don't log all query durations (performance cost)
log_min_duration_statement = 1000  # log queries > 1 second
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '

# Limit exposure
superuser_reserved_connections = 3   # reserve connections for admin access even under load
```

## Micro-concepts
- **scram-sha-256**: the current recommended authentication method. Challenge-response; password never sent in plain.
- **pg_shadow / pg_authid**: role and password storage tables. Superuser access required to read password hashes.
- **`SECURITY DEFINER`**: function runs with the permissions of the function owner (like setuid). Powerful — use sparingly and carefully.
- **`GRANT OPTION`**: allows a grantee to re-grant the privilege. Almost never appropriate for application roles.
- **`NOLOGIN`**: prevents a role from being used for direct connection. Use for group roles that are inherited via `GRANT role TO user`.
- **BYPASSRLS**: a role attribute that ignores all row-level security policies. Never grant to application roles.
- **`SET LOCAL`**: sets a parameter for the current transaction only. Resets at transaction end. Appropriate for setting app context in pooled connections.
- **`pg_read_file()`**: superuser function that reads arbitrary files. A SQL injection vulnerability that exposes this function can read `/etc/passwd`. Restrict superuser access rigorously.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Use passwords, don't use the postgres superuser for applications, enable SSL.

**Intermediate view**: pg_hba.conf controls authentication. Use scram-sha-256. Grant least privilege. Audit changes with triggers.

**Advanced view**: Security is a layered system: network (TLS + IP restrictions), authentication (scram-sha-256, pg_hba.conf), authorization (roles, RLS, column-level privileges), and auditability (trigger-based audit log, connection logging). Each layer must be independently hardened. Trigger-based audit logs have a critical weakness: they run inside the user's transaction and can be bypassed by roles with trigger privileges. For tamper-proof audit, consider writing to a separate immutable store (append-only audit database, write-only object storage) via application-layer logging instead of database triggers. Encryption at rest (OS-level disk encryption) protects against physical media theft but not against SQL-level access — pgcrypto provides column-level protection against privileged-but-not-authorized database users.

## Mental model
Security hardening is building walls at multiple heights:
- **Network wall**: only known IP ranges can knock on the door (pg_hba.conf + firewall)
- **Authentication wall**: the door requires a strong key (scram-sha-256 + TLS)
- **Authorization wall**: each room has different keys (GRANT, RLS)
- **Encryption wall**: even if someone enters a room, the filing cabinets are locked (pgcrypto)
- **Audit wall**: every entry is recorded in a log that can't be altered (immutable audit trail)

Security without audit is a wall without cameras — you may stop attackers, but you can't investigate incidents.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_hba_file_rules` (shows parsed pg_hba.conf), `pg_stat_ssl` (SSL status per connection), `pg_roles` (role attributes), `pg_stat_activity` (active sessions).

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Check all roles and their privileges
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin, rolbypassrls
FROM pg_roles
ORDER BY rolname;

-- Check who has access to a table
SELECT grantee, privilege_type FROM information_schema.role_table_grants
WHERE table_name = 'orders';

-- Check SSL status
SELECT pid, usename, ssl, cipher, bits FROM pg_stat_ssl
JOIN pg_stat_activity USING (pid);
```

**Non-SQL / hybrid view**: Vault (HashiCorp) for secrets management + dynamic database credentials. AWS IAM authentication for PostgreSQL RDS/Aurora. `fail2ban` for blocking IPs after repeated failed authentication (reads PostgreSQL logs).

## Design principle
**Security is subtraction, not addition**: a secure PostgreSQL setup starts from "deny everything" and explicitly grants what is needed. The default "trust" local authentication and public schema CREATE privilege are security debt from a different era. Start hardened and selectively open, not start open and selectively close.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: Trigger-based audit logs can be disabled by users with `ALTER TABLE ... DISABLE TRIGGER`. Audit logs that can be disabled are not tamper-proof. For true tamper-evident logs, audit writes must be atomic with data changes but stored in a system that the data user cannot access — a separate audit database with one-way write access, or write-only object storage via a sidecar.

**Creative**: Use PostgreSQL row security policies to make the audit_log table append-only for application roles:
```sql
-- blocked: Docker not accessible
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY audit_insert_only ON audit_log FOR INSERT WITH CHECK (true);
-- No SELECT/UPDATE/DELETE policies for app_user → they can only insert
```

**Systems**: In a shared cluster (multiple applications), each application should have its own database (not schema). PostgreSQL isolates connection-level permissions at the database level. Cross-database queries require FDW. This is stronger isolation than schema-level separation, which can be bypassed by schema-crossing queries.

## MCP and agent perspective
AI agents that access the database as their own role (e.g., `agent_user`) should be restricted to only the tables and operations they legitimately need. An agent that reads customer data for recommendations should not have DELETE privileges on customer records. Use row-level security to enforce that the agent can only read records assigned to it (via `agent_id` or `session_id` filters). Log every agent query via `pg_stat_statements` and trigger-based audit to the audit_log, with the `app.agent_id` session variable set on connect — enabling forensic reconstruction of agent behavior in incident investigations.

## Ontology perspective
Security is an ontology of trust: it defines which actors, acting in which contexts, can perform which operations on which resources. pg_hba.conf defines the identity context (who, from where). Role privileges define the operational context (what). RLS defines the resource context (which rows). Encryption defines the confidentiality context (who can interpret the data). Audit defines the accountability context (who did what, when). A complete security model requires explicit definition of all five contexts.

## Practice session

**Exercise 1 — Audit current roles**: Find overly privileged roles.
```sql
-- blocked: Docker not accessible
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolbypassrls
FROM pg_roles
WHERE rolsuper OR rolcreatedb OR rolbypassrls
ORDER BY rolname;
```

**Exercise 2 — Encrypt a value**: Use pgcrypto symmetrically.
```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SELECT pgp_sym_encrypt('sensitive data', 'encryption_key_here') AS encrypted;
SELECT pgp_sym_decrypt(
    pgp_sym_encrypt('sensitive data', 'encryption_key_here'),
    'encryption_key_here'
) AS decrypted;
```

**Exercise 3 — Create an audit trigger**: Apply to orders table.
```sql
-- blocked: Docker not accessible
-- (use the audit_trigger_func defined above)
CREATE TRIGGER orders_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON orders
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();
-- Test: INSERT INTO orders (...) VALUES (...);
-- SELECT * FROM audit_log ORDER BY changed_at DESC LIMIT 5;
```

**Exercise 4 — Check table grants**: Who has access?
```sql
-- blocked: Docker not accessible
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
ORDER BY table_name, grantee;
```

**Exercise 5 — Validate pg_hba**: Read current auth configuration.
```sql
-- blocked: Docker not accessible
SELECT type, database, user_name, address, auth_method
FROM pg_hba_file_rules;
```

## References
- PostgreSQL Documentation: [Client Authentication (pg_hba.conf)](https://www.postgresql.org/docs/16/client-authentication.html)
- PostgreSQL Documentation: [SSL Support](https://www.postgresql.org/docs/16/ssl-tcp.html)
- PostgreSQL Documentation: [Role Attributes](https://www.postgresql.org/docs/16/role-attributes.html)
- PostgreSQL Documentation: [pgcrypto](https://www.postgresql.org/docs/16/pgcrypto.html)
- CIS PostgreSQL Benchmark: https://www.cisecurity.org/benchmark/postgresql
- PgBouncer Documentation: https://www.pgbouncer.org/
- OWASP PostgreSQL Security Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Database_Security_Cheat_Sheet.html
