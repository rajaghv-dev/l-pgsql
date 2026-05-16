# Security Design Principles

Principles for securing PostgreSQL databases, roles, and data at every layer.

---

## Principle 1: Apply least privilege to all database roles

### One-line rule
Grant each role only the permissions it needs — never use the superuser or database owner role for application queries.

### Rationale
A compromised application connection with superuser privileges can read any table, drop any schema, and execute any function on the database server. A restricted application role limits the blast radius of a compromise to only what that role can access.

### Example (correct)
```sql
-- Create a restricted application role
CREATE ROLE app_role NOLOGIN;
GRANT CONNECT ON DATABASE myapp TO app_role;
GRANT USAGE ON SCHEMA public TO app_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_role;

-- Create a login role that inherits app_role
CREATE ROLE app_user LOGIN PASSWORD '...' IN ROLE app_role;

-- Revoke what is not needed
REVOKE CREATE ON SCHEMA public FROM app_role;
```

### Counter-example (incorrect)
```sql
-- Application connects as postgres (superuser) or as the database owner
-- One SQL injection = full database access
```

### When this principle applies
Always — production databases must never use superuser for application traffic.

### When to break it (with justification)
Migration scripts may need elevated privileges temporarily. Use a migration role with exactly the needed grants, and rotate credentials after the migration.

### PostgreSQL implementation
```sql
-- Audit current role privileges
\dp                           -- table/view ACLs in psql
SELECT * FROM information_schema.role_table_grants WHERE grantee = 'app_role';
```

### Agent/MCP implications
MCP tools must connect with a restricted role. Never pass the database owner or superuser credentials to a tool that an agent can invoke.

---

## Principle 2: Enable Row Level Security for multi-tenant data

### One-line rule
Use `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` and define policies before any multi-tenant table goes to production.

### Rationale
Without RLS, a bug in any query (missing WHERE clause, wrong parameter binding) can expose data across tenants. RLS enforces isolation at the engine level — no application code path can bypass it.

### Example (correct)
```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders FORCE ROW LEVEL SECURITY;  -- Applies to table owner too

CREATE POLICY tenant_isolation ON orders
    USING (tenant_id = current_setting('app.tenant_id')::bigint);

-- Application sets before every query:
SET LOCAL app.tenant_id = '42';
```

### Counter-example (incorrect)
```sql
-- Application adds WHERE tenant_id = $1 in every query
-- One missing WHERE = full data exposure
SELECT * FROM orders WHERE tenant_id = $tenant_id;
```

### When to break it (with justification)
Internal analytics queries by admins. Create a separate admin role with `BYPASSRLS` rather than disabling the policy.

---

## Principle 3: Never store plaintext passwords

### One-line rule
Hash all passwords before storing — use `pgcrypto`'s `crypt()` with `gen_salt('bf', 12)` or delegate to the application layer.

### Rationale
A database dump of a table with plaintext passwords immediately compromises every user account. Hashing with a strong bcrypt cost factor means the dump provides no useful information without significant computation per password.

### Example (correct)
```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Store hashed password
INSERT INTO users (email, password_hash)
VALUES ('alice@example.com', crypt('supersecret', gen_salt('bf', 12)));

-- Verify on login
SELECT id FROM users
WHERE email = 'alice@example.com'
  AND password_hash = crypt('supplied_password', password_hash);
```

### Counter-example (incorrect)
```sql
INSERT INTO users (email, password) VALUES ('alice@example.com', 'supersecret');
-- One SELECT * = all passwords exposed
```

### Agent/MCP implications
MCP tools must never return password columns in query results, even hashed ones. SELECT lists must explicitly exclude credential columns.

---

## Principle 4: Audit every write that matters

### One-line rule
Create audit log triggers on tables that contain sensitive or regulated data — record who changed what and when.

### Rationale
Security incidents require forensics. Without an audit log, you cannot answer "who deleted this record?", "when was this value changed?", or "what was the value before?". Triggers inside the same transaction capture the truth regardless of application layer logging.

### Example (correct)
```sql
CREATE TABLE audit_log (
    id           bigserial PRIMARY KEY,
    table_name   text NOT NULL,
    operation    text NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
    row_id       bigint,
    old_data     jsonb,
    new_data     jsonb,
    changed_by   text NOT NULL DEFAULT current_user,
    changed_at   timestamptz NOT NULL DEFAULT now(),
    app_user_id  bigint  -- set via current_setting('app.user_id') if available
);

CREATE OR REPLACE FUNCTION audit_trigger_fn()
RETURNS trigger AS $$
BEGIN
    INSERT INTO audit_log (table_name, operation, row_id, old_data, new_data, app_user_id)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        COALESCE(NEW.id, OLD.id),
        CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
        CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
        nullif(current_setting('app.user_id', true), '')::bigint
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER audit_orders
    AFTER INSERT OR UPDATE OR DELETE ON orders
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_fn();
```

---

## Principle 5: Validate input at the database boundary, not only in the application

### One-line rule
Use CHECK constraints, domain types, and trigger validation to enforce input correctness — do not rely solely on application-side validation.

### Rationale
See [[intermediate-design-principles]] Principle 2. Security-specific addition: malicious or broken clients can bypass application validation. The database constraint is unfakeable.

### Example (correct)
```sql
-- Prevent negative balances at the schema level
CREATE TABLE accounts (
    id      bigserial PRIMARY KEY,
    balance numeric(15,2) NOT NULL DEFAULT 0.00
        CHECK (balance >= 0.00)
);
```

---

## Principle 6: Rotate database credentials and revoke old ones

### One-line rule
Use time-limited credentials and rotate them on a schedule — never use a credential indefinitely.

### Rationale
Long-lived credentials accumulate risk: they may be logged, cached in config files, or captured in memory dumps. Rotation limits the window of exposure for any compromised credential.

### PostgreSQL implementation
```sql
-- Change password for a role
ALTER ROLE app_user PASSWORD 'new_strong_password';

-- Set password expiry
ALTER ROLE app_user VALID UNTIL '2025-01-01';

-- Revoke all connections for an old role before decommissioning
REVOKE CONNECT ON DATABASE myapp FROM old_role;
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = 'old_role';
DROP ROLE old_role;
```

---

## Principle 7: Restrict search_path to prevent schema injection

### One-line rule
Set `search_path` explicitly for application roles — never leave it as `"$user", public` where a rogue object in `public` could shadow a trusted function.

### Rationale
If `search_path = public` and a low-privilege user creates a function named `now()` in the public schema, PostgreSQL might call their function instead of the built-in one. Setting `search_path` to only trusted schemas prevents this.

### Example (correct)
```sql
ALTER ROLE app_user SET search_path = myapp_schema;

-- In functions: always use schema-qualified names
CREATE FUNCTION auth.check_token(token text) RETURNS bool AS $$
    SELECT EXISTS (SELECT 1 FROM auth.sessions WHERE token_hash = crypt(token, token_hash));
$$ LANGUAGE sql SECURITY DEFINER SET search_path = auth, pg_catalog;
```
