# Compliance Audit Log Example

Level: Intermediate
Domain: Tenant-isolated documents with automatic audit trail via triggers and RLS
Synthetic data: Yes

## Overview

A multi-tenant document management system for a fictional compliance platform
called "ClearRecord". Every write to the `documents` table is automatically
captured in an `audit_log` table via a trigger — no application code required.
Row-Level Security (RLS) ensures tenants can only see their own documents.
The audit log itself is INSERT-only: even superusers cannot delete entries via
normal SQL (a trigger enforces this).

Key concepts: trigger-based auditing, JSONB for old/new row snapshots, RLS
with `current_setting()`, INSERT-only enforcement.

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- Tenants (superuser-managed, not RLS-protected)
CREATE TABLE tenants (
    id    SERIAL PRIMARY KEY,
    name  TEXT   NOT NULL UNIQUE
);

-- Documents (RLS enforced by tenant_id)
CREATE TABLE documents (
    id          SERIAL PRIMARY KEY,
    tenant_id   INT     NOT NULL REFERENCES tenants(id),
    title       TEXT    NOT NULL,
    content     TEXT    NOT NULL DEFAULT '',
    created_by  TEXT    NOT NULL,   -- username or agent ID
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS: enable and create policy
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY documents_tenant_isolation ON documents
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::INT);

-- Index for efficient tenant isolation
CREATE INDEX idx_documents_tenant_id ON documents (tenant_id);

-- Audit log: immutable record of all writes to documents
CREATE TABLE audit_log (
    id           BIGSERIAL PRIMARY KEY,
    table_name   TEXT        NOT NULL,
    operation    TEXT        NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
    old_data     JSONB,                  -- NULL for INSERT
    new_data     JSONB,                  -- NULL for DELETE
    performed_by TEXT        NOT NULL,   -- current_user at time of write
    performed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_table_operation ON audit_log (table_name, operation);
CREATE INDEX idx_audit_log_performed_at    ON audit_log (performed_at);

-- Trigger function: capture all document writes into audit_log
CREATE OR REPLACE FUNCTION fn_audit_documents()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO audit_log (table_name, operation, old_data, new_data, performed_by)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
        CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
        current_user
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_audit_documents
AFTER INSERT OR UPDATE OR DELETE ON documents
FOR EACH ROW EXECUTE FUNCTION fn_audit_documents();

-- Trigger function: prevent DELETE or UPDATE on audit_log (INSERT-only enforcement)
CREATE OR REPLACE FUNCTION fn_audit_log_immutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'audit_log is immutable: % is not permitted', TG_OP;
END;
$$;

CREATE TRIGGER trg_audit_log_immutable
BEFORE UPDATE OR DELETE ON audit_log
FOR EACH ROW EXECUTE FUNCTION fn_audit_log_immutable();
```

## Seed data

```sql
-- Tenants
INSERT INTO tenants (name) VALUES
  ('Acme Corp'),
  ('Blue Sky Ltd'),
  ('Cedar Analytics');

-- Set tenant context to tenant 1 (Acme Corp) and insert documents
SET app.tenant_id = '1';

INSERT INTO documents (tenant_id, title, content, created_by) VALUES
  (1, 'Data Retention Policy',
   'All customer data must be retained for a minimum of 7 years per regulation XY-42.',
   'alice@acme.test'),
  (1, 'Incident Response Plan',
   'In the event of a data breach, the DPO must be notified within 24 hours.',
   'bob@acme.test'),
  (1, 'Access Control Matrix',
   'List of roles and their permissions across all internal systems.',
   'alice@acme.test');

-- Set tenant context to tenant 2 (Blue Sky Ltd)
SET app.tenant_id = '2';

INSERT INTO documents (tenant_id, title, content, created_by) VALUES
  (2, 'Employee Handbook 2024',
   'Updated policies for remote work, expense claims, and code of conduct.',
   'carol@bluesky.test'),
  (2, 'GDPR Checklist',
   'Checklist for annual GDPR compliance review. Last reviewed: 2024-01.',
   'carol@bluesky.test');

-- Set tenant context to tenant 3 (Cedar Analytics)
SET app.tenant_id = '3';

INSERT INTO documents (tenant_id, title, content, created_by) VALUES
  (3, 'Model Risk Policy',
   'Guidelines for validating ML models before production deployment.',
   'david@cedar.test');

-- Simulate an UPDATE to generate an audit trail
SET app.tenant_id = '2';

UPDATE documents
SET    content    = 'GDPR Checklist updated. Last reviewed: 2024-06.',
       updated_at = NOW()
WHERE  title = 'GDPR Checklist';

-- Simulate a DELETE
SET app.tenant_id = '1';

DELETE FROM documents WHERE title = 'Access Control Matrix';
```

## Example queries

### View documents for the current tenant

```sql
SET app.tenant_id = '1';

SELECT id, title, created_by, created_at
FROM   documents
ORDER  BY created_at DESC;
-- Only rows with tenant_id = 1 are visible
```

### Attempt to view another tenant's documents (RLS blocks it)

```sql
SET app.tenant_id = '1';

-- This returns 0 rows, not an error -- RLS silently filters them out
SELECT id, title FROM documents WHERE tenant_id = 2;
```

### Full audit trail for a specific table

```sql
SELECT id,
       operation,
       performed_by,
       performed_at,
       old_data->>'title' AS old_title,
       new_data->>'title' AS new_title
FROM   audit_log
WHERE  table_name = 'documents'
ORDER  BY performed_at DESC;
```

### Audit trail for DELETE operations only

```sql
SELECT id,
       performed_by,
       performed_at,
       old_data->>'title'     AS deleted_title,
       old_data->>'tenant_id' AS tenant_id
FROM   audit_log
WHERE  table_name = 'documents'
  AND  operation  = 'DELETE'
ORDER  BY performed_at DESC;
```

### Diff an UPDATE (what changed)

```sql
SELECT id,
       performed_at,
       old_data->>'content' AS content_before,
       new_data->>'content' AS content_after
FROM   audit_log
WHERE  table_name = 'documents'
  AND  operation  = 'UPDATE'
ORDER  BY performed_at DESC
LIMIT  5;
```

### Prove audit_log is immutable

```sql
-- This should raise: "audit_log is immutable: DELETE is not permitted"
-- DELETE FROM audit_log WHERE id = 1;

-- This should raise: "audit_log is immutable: UPDATE is not permitted"
-- UPDATE audit_log SET performed_by = 'hacker' WHERE id = 1;
```

### Bypass RLS as superuser (administrative view)

```sql
-- A superuser or role with BYPASSRLS can see all tenants
-- This is for admin/audit purposes only
SELECT d.id, d.tenant_id, t.name AS tenant, d.title
FROM   documents d
JOIN   tenants   t ON t.id = d.tenant_id
ORDER  BY d.tenant_id, d.id;
-- Note: requires BYPASSRLS privilege or superuser
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- 1. Total documents (superuser bypass)
SELECT COUNT(*) FROM documents;
-- Expected: 5 (6 inserted, 1 deleted)

-- 2. Audit log entries
SELECT COUNT(*) FROM audit_log;
-- Expected: 8 (6 INSERTs + 1 UPDATE + 1 DELETE)

-- 3. Audit log has no updates or deletes against itself
-- Attempt: UPDATE audit_log SET performed_by = 'test' WHERE id = 1;
-- Should raise exception

-- 4. Tenant isolation works
SET app.tenant_id = '1';
SELECT COUNT(*) FROM documents;
-- Expected: 2 (Data Retention Policy, Incident Response Plan)

SET app.tenant_id = '2';
SELECT COUNT(*) FROM documents;
-- Expected: 2 (Employee Handbook, GDPR Checklist)

-- 5. Trigger exists
SELECT trigger_name FROM information_schema.triggers WHERE event_object_table = 'documents';
```

## Practice tasks

1. **Insert and check the audit trail.** Set `app.tenant_id = '3'`, insert a new
   document, then query `audit_log` to confirm the INSERT was captured with the
   correct `new_data` JSONB.

2. **Tenant isolation proof.** Set `app.tenant_id = '1'` and try to UPDATE a
   document that belongs to tenant 2 using its `id`. What happens? How does RLS
   protect tenant 2's data?

3. **Audit diff report.** Write a query over `audit_log` that, for every UPDATE,
   computes which keys in the JSONB changed. Hint: use `jsonb_object_keys()` and
   compare `old_data` and `new_data`.

4. **Add a field to the audit.** Modify `fn_audit_documents` to also capture
   `current_setting('app.tenant_id', TRUE)` as a column called `tenant_id` in
   `audit_log`. Add the column and update the trigger.

5. **Audit log volume.** After inserting 100 documents and updating 50, how large
   is `audit_log`? Use `pg_size_pretty(pg_relation_size('audit_log'))`. How does
   JSONB storage affect the audit log size compared to storing only changed columns?

## MCP and agent perspective

An AI agent writing to this system via MCP would:

- **Write documents safely** — every INSERT, UPDATE, DELETE is automatically
  logged; the agent does not need to implement audit logic itself.
- **Cannot tamper with the audit trail** — the immutable trigger means even a
  compromised agent cannot erase evidence of its actions.
- **Operate within tenant context** — the agent sets `app.tenant_id` at the
  start of each session; RLS ensures it can never read or write another tenant's
  data even if the prompt is manipulated.
- **Expose audit summaries** — the agent can query `audit_log` to answer
  "what changed in the last 24 hours?" for compliance reporting.

The combination of RLS + trigger auditing means the database enforces safety
guarantees that do not depend on the agent behaving correctly.

## Teardown

```sql
DROP TRIGGER  IF EXISTS trg_audit_log_immutable ON audit_log;
DROP TRIGGER  IF EXISTS trg_audit_documents     ON documents;
DROP FUNCTION IF EXISTS fn_audit_log_immutable();
DROP FUNCTION IF EXISTS fn_audit_documents();
DROP TABLE    IF EXISTS audit_log;
DROP TABLE    IF EXISTS documents;
DROP TABLE    IF EXISTS tenants;
```

## References

- Row-Level Security: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- Trigger Functions: https://www.postgresql.org/docs/current/plpgsql-trigger.html
- JSONB Functions: https://www.postgresql.org/docs/current/functions-json.html
- current_setting(): https://www.postgresql.org/docs/current/functions-admin.html
