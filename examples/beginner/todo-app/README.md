# Todo App Example

Level: Beginner
Domain: Task management with status constraints, priority ordering, and due dates
Synthetic data: Yes

## Overview

A classic todo list implementation that teaches CHECK constraints, enum-like status
columns, UPDATE statements, and multi-column ORDER BY. The schema is intentionally
simple — one table — so all energy goes into understanding how constraints enforce
data integrity and how to query tasks by different dimensions (status, priority,
due date).

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

CREATE TABLE tasks (
    id          SERIAL PRIMARY KEY,
    title       TEXT    NOT NULL CHECK (char_length(title) > 0),
    description TEXT    NOT NULL DEFAULT '',
    status      TEXT    NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'in_progress', 'done')),
    priority    INT     NOT NULL DEFAULT 2
                        CHECK (priority IN (1, 2, 3)),
                        -- 1 = high, 2 = medium, 3 = low
    due_date    DATE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for common filter patterns
CREATE INDEX idx_tasks_status   ON tasks (status);
CREATE INDEX idx_tasks_due_date ON tasks (due_date) WHERE due_date IS NOT NULL;
```

Priority scale: **1 = high**, **2 = medium**, **3 = low** — lower number sorts first.

## Seed data

```sql
INSERT INTO tasks (title, description, status, priority, due_date) VALUES
  ('Set up development environment',
   'Install PostgreSQL 16, configure pg_stat_statements, verify extensions.',
   'done', 1, CURRENT_DATE - 5),

  ('Write schema for todo app',
   'Design the tasks table with appropriate constraints.',
   'done', 1, CURRENT_DATE - 3),

  ('Add seed data',
   'Insert at least 10 realistic sample rows for testing.',
   'done', 2, CURRENT_DATE - 2),

  ('Write example queries',
   'Cover status filter, priority sort, overdue detection, UPDATE patterns.',
   'in_progress', 1, CURRENT_DATE + 1),

  ('Write validation queries',
   'Queries that confirm the schema is set up correctly.',
   'in_progress', 2, CURRENT_DATE + 2),

  ('Review README for clarity',
   'Check that explanations are beginner-friendly.',
   'pending', 2, CURRENT_DATE + 5),

  ('Add practice tasks section',
   'Write 5 open-ended exercises for students.',
   'pending', 3, CURRENT_DATE + 7),

  ('Overdue task (missed deadline)',
   'This task was not completed on time — used for overdue demo.',
   'pending', 1, CURRENT_DATE - 4),

  ('Optional: add tags column',
   'Consider TEXT[] tags for categorisation (stretch goal).',
   'pending', 3, NULL),

  ('Document teardown steps',
   'List all DROP statements so the schema can be cleanly removed.',
   'pending', 2, CURRENT_DATE + 10);
```

## Example queries

### All pending tasks, highest priority first

```sql
SELECT id, title, priority, due_date
FROM   tasks
WHERE  status = 'pending'
ORDER  BY priority ASC, due_date ASC NULLS LAST;
```

### Tasks currently in progress

```sql
SELECT id, title, description
FROM   tasks
WHERE  status = 'in_progress'
ORDER  BY priority ASC;
```

### Overdue tasks (past due_date and not done)

```sql
SELECT id, title, due_date,
       CURRENT_DATE - due_date AS days_overdue
FROM   tasks
WHERE  status <> 'done'
  AND  due_date < CURRENT_DATE
ORDER  BY days_overdue DESC;
```

### Tasks due in the next 3 days (upcoming)

```sql
SELECT id, title, status, due_date
FROM   tasks
WHERE  due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 3
  AND  status <> 'done'
ORDER  BY due_date ASC;
```

### Task status summary

```sql
SELECT status, COUNT(*) AS count
FROM   tasks
GROUP  BY status
ORDER  BY CASE status
            WHEN 'in_progress' THEN 1
            WHEN 'pending'     THEN 2
            WHEN 'done'        THEN 3
          END;
```

### Move a task from pending to in_progress

```sql
UPDATE tasks
SET    status = 'in_progress'
WHERE  id = 6
  AND  status = 'pending';    -- guard: only advance, never skip states accidentally
```

### Mark a task as done

```sql
UPDATE tasks
SET    status = 'done'
WHERE  id = 5;
```

### High-priority tasks that are not done

```sql
SELECT id, title, status, due_date
FROM   tasks
WHERE  priority = 1
  AND  status <> 'done'
ORDER  BY due_date ASC NULLS LAST;
```

### Demonstrate CHECK constraint violation

```sql
-- This should fail with a check constraint violation:
-- INSERT INTO tasks (title, status) VALUES ('Bad status', 'cancelled');
-- ERROR: new row for relation "tasks" violates check constraint "tasks_status_check"
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- 1. Total tasks
SELECT COUNT(*) AS total_tasks FROM tasks;
-- Expected: 10

-- 2. Status values are all valid
SELECT DISTINCT status FROM tasks ORDER BY status;
-- Expected: done, in_progress, pending

-- 3. Priority values are all valid
SELECT DISTINCT priority FROM tasks ORDER BY priority;
-- Expected: 1, 2, 3

-- 4. Done tasks count
SELECT COUNT(*) FROM tasks WHERE status = 'done';
-- Expected: 3

-- 5. Tasks with no due date
SELECT COUNT(*) FROM tasks WHERE due_date IS NULL;
-- Expected: 1

-- 6. Indexes
SELECT indexname FROM pg_indexes WHERE tablename = 'tasks';
```

## Practice tasks

1. **Priority escalation.** Task id=9 (tags stretch goal) is now urgent. Write an
   UPDATE to change its priority to 1. Then write a SELECT that shows all priority-1
   tasks sorted by due_date.

2. **Batch completion.** All `done` tasks were completed today. Write a single
   UPDATE that sets `due_date = CURRENT_DATE` for every task with `status = 'done'`
   where `due_date` is NULL or earlier than today.

3. **Status pipeline report.** Produce a report showing, for each status, the count
   of tasks and the earliest due date. Use GROUP BY and MIN(due_date).

4. **Add a category column.** Use ALTER TABLE to add a `category TEXT` column with
   a default of `'general'`. Update a few tasks with categories like `'learning'`
   and `'admin'`. Then filter tasks by category.

5. **Constraint exploration.** Try to INSERT a task with `priority = 5`. Observe
   the error. Then try `status = 'archived'`. Document what PostgreSQL says in each
   case and explain why CHECK constraints are preferable to enforcing these rules in
   application code.

## MCP and agent perspective

An agent managing a todo list via MCP would:

- **Create tasks on the fly** — translate user requests ("remind me to review the
  schema tomorrow") into INSERT statements with appropriate priority and due_date.
- **Surface the daily agenda** — run the "due in next 3 days" query each morning
  and present it as a briefing.
- **Enforce workflow rules** — only allow status transitions that make sense
  (`pending` -> `in_progress` -> `done`), rejecting back-transitions via application
  logic layered on top of the CHECK constraint.
- **Detect overdue work** — automatically escalate overdue high-priority tasks by
  updating their priority to 1 and notifying the user.
- **Respect constraints** — the CHECK on `status` means the agent cannot accidentally
  insert an invalid state, even if its prompt crafting has a bug.

## Teardown

```sql
DROP INDEX IF EXISTS idx_tasks_due_date;
DROP INDEX IF EXISTS idx_tasks_status;
DROP TABLE IF EXISTS tasks;
```

## References

- CHECK Constraints: https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-CHECK-CONSTRAINTS
- UPDATE syntax: https://www.postgresql.org/docs/current/sql-update.html
- Date functions: https://www.postgresql.org/docs/current/functions-datetime.html
