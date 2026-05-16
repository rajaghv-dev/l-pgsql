# Support Ticketing System Example

Level: Advanced
Domain: Multi-tenant support tickets with RLS, audit triggers, FTS, and escalation workflow
Synthetic data: Yes

## Overview

A full-featured support ticketing system for a fictional SaaS platform called
"HelpBridge". Demonstrates the combination of:

- **Row-Level Security (RLS)** — tenants can only see their own tickets.
- **Audit trigger** — every change to `status` or `priority` is automatically
  recorded in `ticket_history`.
- **Full-text search** — GIN index on a combined tsvector of title and description.
- **Escalation workflow** — an agent can update priority and status; all changes
  appear in the immutable history.

MCP angle: an agent can create tickets, search them by keyword, escalate priority,
and reassign — and every action leaves an auditable trail.

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- Tenants (superuser-managed)
CREATE TABLE tenants (
    id    SERIAL PRIMARY KEY,
    name  TEXT   NOT NULL UNIQUE
);

-- Tickets (RLS by tenant_id)
CREATE TABLE tickets (
    id            BIGSERIAL PRIMARY KEY,
    tenant_id     INT         NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    title         TEXT        NOT NULL CHECK (char_length(title) > 0),
    description   TEXT        NOT NULL DEFAULT '',
    status        TEXT        NOT NULL DEFAULT 'open'
                              CHECK (status IN ('open','in_progress','resolved','closed')),
    priority      TEXT        NOT NULL DEFAULT 'medium'
                              CHECK (priority IN ('low','medium','high','critical')),
    created_by    TEXT        NOT NULL,   -- user identifier (email or agent ID)
    assigned_to   TEXT,                   -- support agent name
    search_vec    TSVECTOR,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY tickets_tenant_isolation ON tickets
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::INT);

CREATE POLICY tickets_tenant_insert ON tickets
    AS RESTRICTIVE WITH CHECK
    (tenant_id = current_setting('app.tenant_id', TRUE)::INT);

CREATE INDEX idx_tickets_tenant_id ON tickets (tenant_id);
CREATE INDEX idx_tickets_status    ON tickets (status);
CREATE INDEX idx_tickets_priority  ON tickets (priority);
CREATE INDEX idx_tickets_search    ON tickets USING GIN (search_vec);

-- Trigger: update search_vec
CREATE OR REPLACE FUNCTION fn_tickets_search_vec()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.search_vec :=
        setweight(to_tsvector('english', coalesce(NEW.title,       '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.description, '')), 'B');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_tickets_search_vec
BEFORE INSERT OR UPDATE ON tickets
FOR EACH ROW EXECUTE FUNCTION fn_tickets_search_vec();

-- Comments on tickets
CREATE TABLE ticket_comments (
    id          BIGSERIAL PRIMARY KEY,
    ticket_id   BIGINT      NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    body        TEXT        NOT NULL CHECK (char_length(body) > 0),
    author      TEXT        NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_comments_ticket_id ON ticket_comments (ticket_id);

-- Ticket history: immutable record of status/priority changes
CREATE TABLE ticket_history (
    id            BIGSERIAL PRIMARY KEY,
    ticket_id     BIGINT      NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    field_changed TEXT        NOT NULL,   -- 'status' or 'priority'
    old_value     TEXT,
    new_value     TEXT        NOT NULL,
    changed_by    TEXT        NOT NULL DEFAULT current_user,
    changed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_history_ticket_id ON ticket_history (ticket_id);
CREATE INDEX idx_history_changed_at ON ticket_history (changed_at);

-- Trigger: record status and priority changes into ticket_history
CREATE OR REPLACE FUNCTION fn_ticket_audit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status <> OLD.status THEN
        INSERT INTO ticket_history (ticket_id, field_changed, old_value, new_value)
        VALUES (NEW.id, 'status', OLD.status, NEW.status);
    END IF;
    IF NEW.priority <> OLD.priority THEN
        INSERT INTO ticket_history (ticket_id, field_changed, old_value, new_value)
        VALUES (NEW.id, 'priority', OLD.priority, NEW.priority);
    END IF;
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ticket_audit
BEFORE UPDATE ON tickets
FOR EACH ROW EXECUTE FUNCTION fn_ticket_audit();
```

## Seed data

```sql
-- Tenants
INSERT INTO tenants (name) VALUES
  ('Acme Corp'),
  ('Blue Sky Ltd');

-- Tickets for Acme Corp (tenant 1)
SET app.tenant_id = '1';

INSERT INTO tickets (tenant_id, title, description, status, priority, created_by, assigned_to)
VALUES
  (1, 'Login page shows blank screen after SSO redirect',
   'Affected users cannot log in after the SSO provider redirects back. '
   'Browser console shows a CORS error. Reproducible on Chrome and Firefox.',
   'open', 'critical', 'alice@acme.example', NULL),

  (1, 'Export to CSV produces empty file for date ranges over 90 days',
   'When users select a date range longer than 90 days in the export dialog, '
   'the downloaded CSV file is 0 bytes. Short ranges work correctly.',
   'in_progress', 'high', 'bob@acme.example', 'support-agent-1'),

  (1, 'Dashboard widget does not refresh after timezone change',
   'After changing account timezone in settings, the main dashboard still shows '
   'data in the old timezone until a hard refresh.',
   'open', 'medium', 'alice@acme.example', NULL),

  (1, 'Request: add keyboard shortcut for quick search',
   'Feature request: pressing Ctrl+K should open the global search bar, '
   'similar to other productivity tools.',
   'open', 'low', 'charlie@acme.example', NULL);

-- Tickets for Blue Sky Ltd (tenant 2)
SET app.tenant_id = '2';

INSERT INTO tickets (tenant_id, title, description, status, priority, created_by, assigned_to)
VALUES
  (2, 'API rate limit errors on bulk import endpoint',
   'When importing more than 500 records at once, the API returns 429 errors. '
   'Exponential backoff does not resolve the issue within the session.',
   'open', 'high', 'diana@bluesky.example', NULL),

  (2, 'Email notifications sent with wrong sender display name',
   'Automated emails show "Workstream Notifications" but should show "HelpBridge".',
   'resolved', 'low', 'evan@bluesky.example', 'support-agent-2');

-- Simulate escalation: escalate ticket 1 to trigger audit
SET app.tenant_id = '1';

UPDATE tickets
SET    assigned_to = 'support-agent-lead'
WHERE  id = 1;

-- Simulate status change (triggers ticket_history)
UPDATE tickets
SET    status = 'in_progress'
WHERE  id = 1;

-- Simulate priority downgrade
UPDATE tickets
SET    priority = 'high'
WHERE  id = 3;

-- Add comments
INSERT INTO ticket_comments (ticket_id, body, author) VALUES
  (1, 'Reproduced locally. CORS header missing on redirect response.', 'support-agent-lead'),
  (1, 'Fix deployed to staging. Awaiting confirmation from user.', 'support-agent-lead'),
  (2, 'Root cause identified: query optimizer hits memory limit at 90 days.', 'support-agent-1');
```

## Example queries

### Full-text search across tickets for current tenant

```sql
SET app.tenant_id = '1';

SELECT id,
       title,
       status,
       priority,
       ts_rank(search_vec, query) AS rank
FROM   tickets,
       plainto_tsquery('english', 'SSO login CORS error') AS query
WHERE  search_vec @@ query
ORDER  BY rank DESC;
```

### Open tickets by priority (current tenant)

```sql
SET app.tenant_id = '1';

SELECT id, title, priority, created_by, created_at
FROM   tickets
WHERE  status IN ('open', 'in_progress')
ORDER  BY CASE priority
            WHEN 'critical' THEN 1
            WHEN 'high'     THEN 2
            WHEN 'medium'   THEN 3
            WHEN 'low'      THEN 4
          END,
          created_at ASC;
```

### Ticket history for a specific ticket

```sql
SELECT field_changed, old_value, new_value, changed_by, changed_at
FROM   ticket_history
WHERE  ticket_id = 1
ORDER  BY changed_at ASC;
```

### All comments for a ticket with timeline

```sql
SELECT c.id,
       c.author,
       LEFT(c.body, 80) AS comment_excerpt,
       c.created_at
FROM   ticket_comments c
WHERE  c.ticket_id = 1
ORDER  BY c.created_at ASC;
```

### Escalate a ticket (status + priority in one UPDATE)

```sql
SET app.tenant_id = '1';

UPDATE tickets
SET    priority = 'critical',
       status   = 'in_progress',
       assigned_to = 'support-agent-lead'
WHERE  id = 3;
-- Both changes appear in ticket_history automatically
```

### Summary: open tickets per priority (current tenant)

```sql
SET app.tenant_id = '1';

SELECT priority,
       COUNT(*) FILTER (WHERE status = 'open')        AS open_count,
       COUNT(*) FILTER (WHERE status = 'in_progress') AS in_progress_count
FROM   tickets
WHERE  status IN ('open','in_progress')
GROUP  BY priority
ORDER  BY CASE priority
            WHEN 'critical' THEN 1
            WHEN 'high'     THEN 2
            WHEN 'medium'   THEN 3
            WHEN 'low'      THEN 4
          END;
```

### Admin view: tickets across all tenants (BYPASSRLS)

```sql
-- Requires superuser or BYPASSRLS role
SELECT t.id,
       tn.name  AS tenant,
       t.title,
       t.status,
       t.priority
FROM   tickets  t
JOIN   tenants  tn ON tn.id = t.tenant_id
ORDER  BY tn.name, t.priority, t.created_at;
```

### RLS isolation: cross-tenant query returns 0 rows

```sql
SET app.tenant_id = '1';
SELECT COUNT(*) FROM tickets WHERE tenant_id = 2;
-- Expected: 0 (RLS filters it)
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

SELECT COUNT(*) FROM tenants;           -- Expected: 2
SELECT COUNT(*) FROM tickets;           -- Expected: 6 (superuser)
SELECT COUNT(*) FROM ticket_comments;   -- Expected: 3
SELECT COUNT(*) FROM ticket_history;    -- Expected: 3 (2 status + 1 priority change)

-- tsvector populated
SELECT COUNT(*) FROM tickets WHERE search_vec IS NOT NULL;
-- Expected: 6

-- Triggers exist
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE event_object_table IN ('tickets')
ORDER BY trigger_name;

-- RLS active
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'tickets';
```

## Practice tasks

1. **Resolve a ticket.** Set `app.tenant_id = '1'`. Update ticket id=2 to
   `status = 'resolved'`. Query `ticket_history` for ticket 2 and confirm the
   status change is recorded.

2. **Comment thread.** Add 3 more comments to ticket id=1 simulating a back-and-forth
   between the customer and support agent. Write a query that shows the full
   comment thread ordered by `created_at`.

3. **SLA breach detection.** Write a query that returns all open/in_progress tickets
   that are older than 48 hours AND have priority 'critical' or 'high'. These are
   potential SLA breaches.

4. **Cross-tenant safety.** Set `app.tenant_id = '1'`. Attempt to INSERT a ticket
   with `tenant_id = 2`. What error does PostgreSQL return? Why does the
   `WITH CHECK` policy prevent this?

5. **Agent escalation workflow.** Write a PL/pgSQL function `escalate_ticket(ticket_id,
   new_priority, agent_name)` that updates the ticket's priority and assigned_to,
   then inserts a comment saying "Escalated to [agent_name] with priority [new_priority]".
   Wrap both in a transaction.

## MCP and agent perspective

An AI support agent using this schema via MCP would:

- **Create tickets from user messages** — translate an incoming support request
  into an INSERT with appropriate priority inference.
- **Search for similar tickets** — before creating a new ticket, run the FTS query
  to check for duplicates or existing solutions.
- **Escalate automatically** — if a ticket has been open for more than 4 hours
  with no assignment, UPDATE priority and assigned_to; the trigger logs the change.
- **All actions audited** — every UPDATE the agent makes to status or priority
  appears in `ticket_history`, giving human supervisors full visibility.
- **Tenant isolation enforced** — the agent cannot leak Acme Corp's tickets to
  Blue Sky Ltd even if its prompt contains a cross-tenant query.

## Teardown

```sql
DROP TRIGGER  IF EXISTS trg_ticket_audit      ON tickets;
DROP TRIGGER  IF EXISTS trg_tickets_search_vec ON tickets;
DROP FUNCTION IF EXISTS fn_ticket_audit();
DROP FUNCTION IF EXISTS fn_tickets_search_vec();
DROP TABLE    IF EXISTS ticket_history;
DROP TABLE    IF EXISTS ticket_comments;
DROP TABLE    IF EXISTS tickets;
DROP TABLE    IF EXISTS tenants;
```

## References

- Row-Level Security: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- PL/pgSQL Triggers: https://www.postgresql.org/docs/current/plpgsql-trigger.html
- Full-Text Search: https://www.postgresql.org/docs/current/textsearch.html
- FILTER clause in aggregates: https://www.postgresql.org/docs/current/sql-expressions.html#SYNTAX-AGGREGATES
