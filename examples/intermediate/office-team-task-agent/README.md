# Office Team Task Agent Example

Level: Intermediate
⚠️ All data in this example is synthetic.

## Overview

A multi-tenant team task manager for a fictional agency called "Orbit Studio".
Demonstrates:

- **Full CRUD via narrow tools** — the agent can create tasks, update status, and
  reassign assignees through well-defined operations, not arbitrary SQL.
- **Action logging** — every agent action on a task is appended to `task_actions`,
  providing a complete history of what the agent did and why.
- **Tenant isolation via RLS** — `team_members` and `tasks` are scoped by `tenant_id`.

## Schema

```sql
-- blocked: Docker not accessible; validate against cfp_postgres when available

CREATE TABLE team_members (
    id        BIGSERIAL PRIMARY KEY,
    name      TEXT NOT NULL,
    email     TEXT NOT NULL UNIQUE,
    role      TEXT NOT NULL DEFAULT 'member'
              CHECK (role IN ('owner','manager','member')),
    tenant_id INT  NOT NULL
);

ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY team_members_tenant_isolation ON team_members
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::INT);

CREATE INDEX idx_team_members_tenant_id ON team_members (tenant_id);

CREATE TABLE tasks (
    id          BIGSERIAL PRIMARY KEY,
    title       TEXT        NOT NULL CHECK (char_length(title) > 0),
    description TEXT        NOT NULL DEFAULT '',
    status      TEXT        NOT NULL DEFAULT 'todo'
                            CHECK (status IN ('todo','in_progress','blocked','done')),
    assignee_id BIGINT      REFERENCES team_members(id) ON DELETE SET NULL,
    priority    TEXT        NOT NULL DEFAULT 'medium'
                            CHECK (priority IN ('low','medium','high','urgent')),
    due_date    DATE,
    tenant_id   INT         NOT NULL
);

ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY tasks_tenant_isolation ON tasks
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::INT);

CREATE INDEX idx_tasks_tenant_id   ON tasks (tenant_id);
CREATE INDEX idx_tasks_status      ON tasks (status);
CREATE INDEX idx_tasks_assignee_id ON tasks (assignee_id);
CREATE INDEX idx_tasks_due_date    ON tasks (due_date);

CREATE TABLE task_actions (
    id                 BIGSERIAL PRIMARY KEY,
    task_id            BIGINT      NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    action_type        TEXT        NOT NULL
                                   CHECK (action_type IN
                                     ('created','status_changed','reassigned',
                                      'priority_changed','note_added','completed')),
    performed_by_agent TEXT        NOT NULL,
    notes              TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_task_actions_task_id ON task_actions (task_id);
CREATE INDEX idx_task_actions_created ON task_actions (created_at);
```

## Seed data

```sql
-- blocked: Docker not accessible

INSERT INTO team_members (name, email, role, tenant_id) VALUES
  ('Priya S.',  'priya@orbit.example',  'manager', 1),
  ('Omar T.',   'omar@orbit.example',   'member',  1),
  ('Sofia L.',  'sofia@orbit.example',  'member',  1),
  ('James R.',  'james@orbit.example',  'owner',   1),
  ('Nadia K.',  'nadia@partner.example','manager', 2),
  ('Luca M.',   'luca@partner.example', 'member',  2);

INSERT INTO tasks (title, description, status, assignee_id, priority, due_date, tenant_id)
VALUES
  ('Set up CI pipeline',
   'Configure GitHub Actions for automated testing and deployment.',
   'in_progress', 2, 'high',   CURRENT_DATE + 7,  1),

  ('Write Q2 retrospective doc',
   'Summarise team wins, blockers, and process improvements from Q2.',
   'todo',        1, 'medium', CURRENT_DATE + 14, 1),

  ('Review vendor contracts',
   'Check renewal terms for three SaaS vendors due next quarter.',
   'blocked',     4, 'urgent', CURRENT_DATE + 3,  1),

  ('Onboard new contractor',
   'Prepare accounts, access, and orientation materials.',
   'todo',        1, 'high',   CURRENT_DATE + 5,  1),

  ('Update design system tokens',
   'Align colour tokens with new brand guidelines.',
   'done',        3, 'low',    CURRENT_DATE - 2,  1),

  ('Draft partner proposal',
   'Write initial proposal for new integration partnership.',
   'in_progress', 5, 'high',   CURRENT_DATE + 10, 2);

-- Log initial agent actions
INSERT INTO task_actions (task_id, action_type, performed_by_agent, notes) VALUES
  (1, 'status_changed', 'agent-task-v1', 'Moved to in_progress after sprint planning.'),
  (3, 'priority_changed','agent-task-v1', 'Escalated to urgent: contract deadline approaching.'),
  (5, 'completed',      'agent-task-v1', 'Design tokens updated and reviewed by manager.');
```

## Example queries

### Current task board for the team (current tenant)

```sql
SET app.tenant_id = '1';

SELECT t.id,
       t.title,
       t.status,
       t.priority,
       tm.name        AS assignee,
       t.due_date,
       t.due_date - CURRENT_DATE AS days_remaining
FROM   tasks       t
LEFT   JOIN team_members tm ON tm.id = t.assignee_id
WHERE  t.status <> 'done'
ORDER  BY CASE t.priority
            WHEN 'urgent' THEN 1
            WHEN 'high'   THEN 2
            WHEN 'medium' THEN 3
            WHEN 'low'    THEN 4
          END,
          t.due_date NULLS LAST;
```

### Create a task (agent pattern)

```sql
SET app.tenant_id = '1';

-- Step 1: insert the task
INSERT INTO tasks (title, description, status, assignee_id, priority, due_date, tenant_id)
VALUES ('Review sprint backlog', 'Groom backlog items for upcoming sprint.',
        'todo', 1, 'medium', CURRENT_DATE + 7, 1)
RETURNING id;

-- Step 2: log the creation (assuming returned id = 7)
INSERT INTO task_actions (task_id, action_type, performed_by_agent, notes)
VALUES (7, 'created', 'agent-task-v1', 'Created during weekly planning.');
```

### Reassign a task

```sql
SET app.tenant_id = '1';

UPDATE tasks SET assignee_id = 3 WHERE id = 2;

INSERT INTO task_actions (task_id, action_type, performed_by_agent, notes)
VALUES (2, 'reassigned', 'agent-task-v1', 'Reassigned from Priya to Sofia: capacity rebalance.');
```

### Overdue tasks

```sql
SET app.tenant_id = '1';

SELECT t.id,
       t.title,
       tm.name AS assignee,
       t.due_date,
       CURRENT_DATE - t.due_date AS days_overdue
FROM   tasks t
LEFT   JOIN team_members tm ON tm.id = t.assignee_id
WHERE  t.status NOT IN ('done')
  AND  t.due_date < CURRENT_DATE
ORDER  BY days_overdue DESC;
```

### Full action log for a task

```sql
SELECT action_type, performed_by_agent, notes, created_at
FROM   task_actions
WHERE  task_id = 3
ORDER  BY created_at ASC;
```

### Workload summary per team member (current tenant)

```sql
SET app.tenant_id = '1';

SELECT tm.name,
       COUNT(*)                                          AS total_tasks,
       COUNT(*) FILTER (WHERE t.status = 'in_progress') AS active,
       COUNT(*) FILTER (WHERE t.status = 'blocked')     AS blocked,
       COUNT(*) FILTER (WHERE t.priority = 'urgent')    AS urgent
FROM   team_members tm
LEFT   JOIN tasks t ON t.assignee_id = tm.id AND t.status <> 'done'
GROUP  BY tm.id, tm.name
ORDER  BY tm.name;
```

## Validation queries

```sql
-- blocked: Docker not accessible

SELECT COUNT(*) FROM team_members;  -- Expected: 6 (superuser)
SELECT COUNT(*) FROM tasks;         -- Expected: 6 (superuser)
SELECT COUNT(*) FROM task_actions;  -- Expected: 3

-- Tenant 1 data
SET app.tenant_id = '1';
SELECT COUNT(*) FROM team_members;  -- Expected: 4
SELECT COUNT(*) FROM tasks;         -- Expected: 5

-- RLS active
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename IN ('tasks','team_members');

-- Urgent tasks
SELECT title FROM tasks WHERE priority = 'urgent';
-- Expected: Review vendor contracts
```

## Practice tasks

1. **Auto-assign.** Write a query that finds the team member with the fewest
   active (non-done) tasks for a given tenant, then write an UPDATE that assigns
   a specified task to that member. Log the action.

2. **Blocked task alert.** Write a query that returns all blocked tasks older than
   3 days with no action logged in the last 24 hours. This is the agent's stale
   blocker list.

3. **Status transition validation.** Add a trigger on `tasks` that prevents
   setting `status = 'done'` if the current status is `'todo'` (must go through
   `'in_progress'` first). Test the guard.

4. **Sprint report.** Write a query that produces a sprint summary: total tasks,
   completed this sprint (done AND `due_date` within the last 14 days), and
   average days from creation to completion.

5. **Bulk reprioritise.** The agent identifies all tasks due in the next 2 days
   that are still `'todo'`. Write a single UPDATE that changes their priority to
   `'urgent'` and logs each change to `task_actions` using a data-modifying CTE.

## MCP and agent perspective

An AI task agent using this schema via MCP would:

- **Full CRUD, fully logged** — the agent can create, update, and reassign tasks,
  but every action is appended to `task_actions` so humans can review and override.
- **Narrow tool surface** — the MCP server exposes `create_task`, `update_status`,
  `reassign`, and `set_priority` functions rather than raw SQL, limiting what the
  agent can express.
- **Workload balancing** — the agent queries workload summaries and uses them to
  distribute new tasks to the least-loaded team member.
- **Proactive alerts** — the agent polls for overdue and blocked tasks on a schedule
  and posts summaries to a team channel without human prompting.
- **Tenant-scoped** — `app.tenant_id` is injected from the authenticated workspace
  session; the agent cannot access another team's data.

## Teardown

```sql
-- blocked: Docker not accessible
DROP TABLE IF EXISTS task_actions  CASCADE;
DROP TABLE IF EXISTS tasks         CASCADE;
DROP TABLE IF EXISTS team_members  CASCADE;
```

## References

- Row-Level Security: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- Data-modifying CTEs: https://www.postgresql.org/docs/current/queries-with.html#QUERIES-WITH-MODIFYING
- FILTER in aggregates: https://www.postgresql.org/docs/current/sql-expressions.html#SYNTAX-AGGREGATES
