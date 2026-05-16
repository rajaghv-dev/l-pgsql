-- Practice 10: Row-Level Security and Multi-Tenancy
-- STATUS: blocked — Docker not accessible in this session
-- Run with: docker exec cfp_postgres psql -U cfp -d cfp -f setup.sql

-- ============================================================
-- Schema
-- ============================================================

DROP TABLE IF EXISTS tasks CASCADE;
DROP TABLE IF EXISTS projects CASCADE;
DROP TABLE IF EXISTS tenants CASCADE;

CREATE TABLE tenants (
    id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name    TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE projects (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES tenants(id),
    name        TEXT NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE tasks (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id  UUID NOT NULL REFERENCES projects(id),
    tenant_id   UUID NOT NULL REFERENCES tenants(id),
    title       TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','in-progress','done')),
    created_at  TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- Enable RLS
-- ============================================================

ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects FORCE ROW LEVEL SECURITY;

ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks FORCE ROW LEVEL SECURITY;

-- Tenant isolation policies
CREATE POLICY projects_tenant_isolation ON projects
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid)
    WITH CHECK (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

CREATE POLICY tasks_tenant_isolation ON tasks
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid)
    WITH CHECK (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ============================================================
-- Seed data — two tenants
-- ============================================================

INSERT INTO tenants (id, name) VALUES
    ('aaaaaaaa-0000-0000-0000-000000000001', 'Acme Corp'),
    ('bbbbbbbb-0000-0000-0000-000000000002', 'BetaCo');

INSERT INTO projects (id, tenant_id, name) VALUES
    ('11111111-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Acme Project Alpha'),
    ('22222222-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'BetaCo Main Project');

INSERT INTO tasks (project_id, tenant_id, title, status) VALUES
    ('11111111-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Design homepage', 'open'),
    ('11111111-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Setup CI/CD', 'in-progress'),
    ('22222222-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'Write API docs', 'open'),
    ('22222222-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'Deploy to production', 'done');

-- Verify (as superuser, bypasses RLS)
SELECT 'tenants' AS tbl, COUNT(*) FROM tenants
UNION ALL
SELECT 'projects', COUNT(*) FROM projects
UNION ALL
SELECT 'tasks', COUNT(*) FROM tasks;
