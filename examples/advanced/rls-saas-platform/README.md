# Advanced RLS — SaaS Platform Example

Level: Advanced
Domain: Multi-policy Row-Level Security with role-based access for a SaaS task platform
Synthetic data: Yes

## Overview

An advanced Row-Level Security demonstration for a fictional project management
SaaS called "Meridian Tasks". Unlike the beginner multi-tenant example, this one
shows:

- **Multiple policies on the same table** — separate policies for SELECT, INSERT,
  UPDATE, and DELETE.
- **Role-based access within a tenant** — admins see all tasks in their org;
  members see only tasks assigned to them; the database enforces this, not the app.
- **SET LOCAL for safe session scoping** — org context and user context set in
  the same transaction.
- **BYPASSRLS risk** — documented explicitly with a warning.
- **Policy combining** — PostgreSQL evaluates PERMISSIVE policies with OR logic
  and RESTRICTIVE policies with AND logic.

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- Organizations (no RLS; managed by platform ops)
CREATE TABLE organizations (
    id    SERIAL PRIMARY KEY,
    name  TEXT   NOT NULL UNIQUE
);

-- Users (RLS: see only users in your org)
CREATE TABLE users (
    id        SERIAL PRIMARY KEY,
    org_id    INT    NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    email     TEXT   NOT NULL UNIQUE,
    role      TEXT   NOT NULL DEFAULT 'member'
                     CHECK (role IN ('admin','member','viewer'))
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Users see only members of their organization
CREATE POLICY users_org_isolation ON users
    FOR ALL
    USING (org_id = current_setting('app.org_id', TRUE)::INT);

CREATE INDEX idx_users_org_id ON users (org_id);

-- Projects (RLS: see only projects in your org)
CREATE TABLE projects (
    id      SERIAL PRIMARY KEY,
    org_id  INT    NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name    TEXT   NOT NULL
);

ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY projects_org_isolation ON projects
    FOR ALL
    USING (org_id = current_setting('app.org_id', TRUE)::INT);

CREATE INDEX idx_projects_org_id ON projects (org_id);

-- Tasks (multiple policies for fine-grained access)
CREATE TABLE tasks (
    id          BIGSERIAL PRIMARY KEY,
    project_id  INT     NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    org_id      INT     NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    title       TEXT    NOT NULL CHECK (char_length(title) > 0),
    status      TEXT    NOT NULL DEFAULT 'todo'
                        CHECK (status IN ('todo','in_progress','done')),
    assignee_id INT     REFERENCES users(id),
    created_by  INT     REFERENCES users(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- ---- TASKS: SELECT policies ----

-- Policy 1 (PERMISSIVE): admins can see ALL tasks in their org
CREATE POLICY tasks_admin_select ON tasks
    FOR SELECT
    USING (
        org_id = current_setting('app.org_id', TRUE)::INT
        AND EXISTS (
            SELECT 1 FROM users u
            WHERE u.id    = current_setting('app.user_id', TRUE)::INT
              AND u.org_id = current_setting('app.org_id', TRUE)::INT
              AND u.role    = 'admin'
        )
    );

-- Policy 2 (PERMISSIVE): members see only tasks assigned to them
CREATE POLICY tasks_member_select ON tasks
    FOR SELECT
    USING (
        org_id      = current_setting('app.org_id', TRUE)::INT
        AND assignee_id = current_setting('app.user_id', TRUE)::INT
    );

-- ---- TASKS: INSERT policy ----
-- Any user in the org can create tasks (the org_id must match)
CREATE POLICY tasks_insert ON tasks
    FOR INSERT
    WITH CHECK (
        org_id = current_setting('app.org_id', TRUE)::INT
    );

-- ---- TASKS: UPDATE policy ----
-- Only the assignee OR an admin can update a task
CREATE POLICY tasks_update ON tasks
    FOR UPDATE
    USING (
        org_id = current_setting('app.org_id', TRUE)::INT
        AND (
            assignee_id = current_setting('app.user_id', TRUE)::INT
            OR EXISTS (
                SELECT 1 FROM users u
                WHERE u.id    = current_setting('app.user_id', TRUE)::INT
                  AND u.org_id = current_setting('app.org_id', TRUE)::INT
                  AND u.role    = 'admin'
            )
        )
    );

-- ---- TASKS: DELETE policy ----
-- Only admins can delete tasks
CREATE POLICY tasks_delete ON tasks
    FOR DELETE
    USING (
        org_id = current_setting('app.org_id', TRUE)::INT
        AND EXISTS (
            SELECT 1 FROM users u
            WHERE u.id    = current_setting('app.user_id', TRUE)::INT
              AND u.org_id = current_setting('app.org_id', TRUE)::INT
              AND u.role    = 'admin'
        )
    );

CREATE INDEX idx_tasks_org_id      ON tasks (org_id);
CREATE INDEX idx_tasks_project_id  ON tasks (project_id);
CREATE INDEX idx_tasks_assignee_id ON tasks (assignee_id);
```

## Seed data

```sql
-- Organizations
INSERT INTO organizations (name) VALUES
  ('Acme Corp'),
  ('Blue Sky Ltd');

-- Users
INSERT INTO users (org_id, email, role) VALUES
  -- Acme Corp (org 1)
  (1, 'alice@acme.example',   'admin'),   -- id=1
  (1, 'bob@acme.example',     'member'),  -- id=2
  (1, 'carol@acme.example',   'member'),  -- id=3
  (1, 'diana@acme.example',   'viewer'),  -- id=4

  -- Blue Sky Ltd (org 2)
  (2, 'evan@bluesky.example', 'admin'),   -- id=5
  (2, 'fiona@bluesky.example','member');  -- id=6

-- Projects
INSERT INTO projects (org_id, name) VALUES
  (1, 'Website Redesign'),   -- id=1
  (1, 'API v2 Launch'),      -- id=2
  (2, 'Data Platform');      -- id=3

-- Tasks for Acme Corp
SET app.org_id  = '1';
SET app.user_id = '1';   -- acting as alice (admin)

INSERT INTO tasks (project_id, org_id, title, status, assignee_id, created_by) VALUES
  (1, 1, 'Design new homepage mockup',        'in_progress', 2, 1),  -- assigned to bob
  (1, 1, 'Review brand guidelines',           'todo',        3, 1),  -- assigned to carol
  (1, 1, 'Set up CI/CD pipeline',             'todo',        2, 1),  -- assigned to bob
  (2, 1, 'Draft API specification',           'in_progress', 3, 1),  -- assigned to carol
  (2, 1, 'Implement authentication endpoint', 'todo',        2, 1),  -- assigned to bob
  (2, 1, 'Load testing plan',                 'done',        1, 1);  -- assigned to alice (admin)

-- Tasks for Blue Sky Ltd
SET app.org_id  = '2';
SET app.user_id = '5';   -- acting as evan (admin)

INSERT INTO tasks (project_id, org_id, title, status, assignee_id, created_by) VALUES
  (3, 2, 'Ingest pipeline design',  'in_progress', 6, 5),
  (3, 2, 'Set up dbt project',      'todo',        5, 5);
```

## Example queries

### Admin view: all tasks in org (alice)

```sql
SET app.org_id  = '1';
SET app.user_id = '1';   -- alice is admin

SELECT t.id, t.title, t.status, u.email AS assignee
FROM   tasks t
LEFT   JOIN users u ON u.id = t.assignee_id
ORDER  BY t.id;
-- Returns all 6 Acme Corp tasks (admin policy matches)
```

### Member view: only my assigned tasks (bob)

```sql
SET app.org_id  = '1';
SET app.user_id = '2';   -- bob is member

SELECT t.id, t.title, t.status
FROM   tasks t
ORDER  BY t.id;
-- Returns only tasks where assignee_id = 2 (3 tasks)
```

### Cross-tenant isolation

```sql
SET app.org_id  = '1';
SET app.user_id = '2';

-- Cannot see Blue Sky tasks even with explicit filter
SELECT COUNT(*) FROM tasks WHERE org_id = 2;
-- Expected: 0
```

### Member can update their own task

```sql
SET app.org_id  = '1';
SET app.user_id = '2';   -- bob

-- Bob updates a task assigned to him
UPDATE tasks SET status = 'done' WHERE id = 1;
-- Succeeds (bob is the assignee)

-- Bob tries to update a task assigned to carol — UPDATE policy blocks it
UPDATE tasks SET status = 'done' WHERE id = 2;
-- 0 rows affected (silently filtered by UPDATE policy)
```

### Admin can delete tasks; member cannot

```sql
SET app.org_id  = '1';
SET app.user_id = '2';   -- bob (member)

-- Bob tries to delete a task
DELETE FROM tasks WHERE id = 5;
-- 0 rows affected (DELETE policy requires admin role)

SET app.user_id = '1';   -- alice (admin)

DELETE FROM tasks WHERE id = 5;
-- 1 row deleted
```

### SET LOCAL: scope org context to a single transaction

```sql
BEGIN;
  SET LOCAL app.org_id  = '2';
  SET LOCAL app.user_id = '5';  -- evan (Blue Sky admin)

  SELECT id, title FROM tasks ORDER BY id;
  -- Sees only Blue Sky tasks

  INSERT INTO tasks (project_id, org_id, title, assignee_id, created_by)
  VALUES (3, 2, 'Schema migration plan', 6, 5);
COMMIT;
-- After commit: app.org_id reverts to previous value (or empty)
```

### All policies on the tasks table

```sql
SELECT policyname, cmd, qual
FROM   pg_policies
WHERE  tablename = 'tasks'
ORDER  BY policyname;
```

### BYPASSRLS warning

```sql
-- WARNING: Any role with BYPASSRLS or superuser privilege ignores all policies.
-- This is intended for DBA and admin operations only.
-- Example (do NOT grant this to application users):
-- ALTER USER myapp_admin BYPASSRLS;

-- Superuser can see all tasks regardless of app.org_id:
-- SELECT COUNT(*) FROM tasks;  -- returns all rows from all orgs

-- Risk: if the application accidentally runs as a superuser,
-- all tenant isolation is bypassed silently.
-- Mitigation: application DB user should be a limited role, not superuser.
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

SELECT COUNT(*) FROM organizations;  -- Expected: 2
SELECT COUNT(*) FROM users;          -- Expected: 6
SELECT COUNT(*) FROM projects;       -- Expected: 3
SELECT COUNT(*) FROM tasks;          -- Expected: 8 (superuser; 6 Acme + 2 Blue Sky after delete above)

-- Policy count on tasks
SELECT COUNT(*) FROM pg_policies WHERE tablename = 'tasks';
-- Expected: 5

-- RLS enabled
SELECT tablename, rowsecurity FROM pg_tables
WHERE tablename IN ('users','projects','tasks');

-- Admin sees all org tasks
SET app.org_id = '1'; SET app.user_id = '1';
SELECT COUNT(*) FROM tasks;
-- Expected: 6 (or 5 after delete practice)

-- Member sees only assigned tasks
SET app.org_id = '1'; SET app.user_id = '3';
SELECT COUNT(*) FROM tasks;
-- Expected: 2 (carol's tasks)
```

## Practice tasks

1. **Viewer policy.** Add a `tasks_viewer_select` policy so users with `role = 'viewer'`
   can SELECT all tasks in their org (same as admin) but cannot INSERT, UPDATE, or DELETE.
   Test with `SET app.user_id = '4'` (diana, a viewer).

2. **Policy conflict.** Set `app.user_id = '1'` (alice, admin). Observe that the admin
   SELECT policy and the member SELECT policy both apply. Alice should see all tasks
   because PERMISSIVE policies use OR logic. Verify by checking what `pg_policies` says
   about `permissive` vs `restrictive`.

3. **RESTRICTIVE policy.** Add a RESTRICTIVE policy that prevents any INSERT to a `done`
   task (`WITH CHECK (status <> 'done')`). Test that even admins cannot create a task
   with status='done'.

4. **Delegated assignment.** Write a query (or function) that allows bob (a member) to
   reassign one of his tasks to carol, but only if carol is in the same org. Use
   `current_setting('app.user_id')` in the check.

5. **BYPASSRLS audit.** Query `pg_roles` to find all roles that have `bypassrls = true`.
   Write a short explanation of why each such role should be audited carefully in a
   production SaaS environment.

## MCP and agent perspective

An agent acting as a team member within this platform via MCP would:

- **Receive org_id and user_id at session start** — the MCP server sets both via
  `SET LOCAL` before any agent query. The agent never manipulates its own context.
- **Automatically restricted by role** — if the agent is a member-level user, it
  physically cannot read other members' tasks even if its SQL contains no WHERE filter.
- **Update only allowed rows** — the UPDATE policy means the agent cannot accidentally
  (or through prompt injection) update another user's tasks.
- **Admin agent has broader access** — a separate admin agent session sets a user with
  `role = 'admin'`, giving it the additional powers needed for reporting and maintenance.
- **Multiple policies compose safely** — PostgreSQL evaluates all PERMISSIVE policies
  with OR, so admin + member SELECT policies give admins full visibility without
  requiring a special bypass mechanism.

## Teardown

```sql
DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS organizations;
```

## References

- Row-Level Security: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- Policy commands (FOR SELECT/INSERT/UPDATE/DELETE): https://www.postgresql.org/docs/current/sql-createpolicy.html
- PERMISSIVE vs RESTRICTIVE: https://www.postgresql.org/docs/current/ddl-rowsecurity.html#DDL-ROWSECURITY-POLICIES
- pg_policies view: https://www.postgresql.org/docs/current/view-pg-policies.html
- SET LOCAL: https://www.postgresql.org/docs/current/sql-set.html
