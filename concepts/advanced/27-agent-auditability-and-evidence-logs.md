# Agent Auditability and Evidence Logs
Level: Advanced

## One-line intuition
An immutable audit log — INSERT-only, trigger-protected, with full old/new JSONB snapshots — is the forensic record of everything every agent ever did, and PostgreSQL enforces its immutability at the engine level.

## Why this exists
When an agent makes a mistake or acts unexpectedly, the first question is always "what exactly did it do, and in what order?" If the audit log can be modified or deleted, it cannot answer that question — even an honest mistake by a developer cleaning up "test" data destroys the evidence. INSERT-only enforcement makes this impossible by design.

## First-principles explanation
A standard audit log is a table where someone inserts a row after each write. The problem: that same person (or the agent) can also delete or update those rows. The audit log is as trustworthy as the actor who wrote it.

An immutable audit log adds a trigger: any UPDATE or DELETE on the audit table raises an exception immediately. The trigger cannot be disabled by the agent (it lacks the ALTER TABLE privilege). Even a superuser would need to `ALTER TABLE audit_log DISABLE TRIGGER` — an action that itself should be logged and alarmed.

The JSONB old_data/new_data pattern captures the complete row state at the time of the write. This is forensic completeness: an auditor can reconstruct the exact state of any row at any point in time by replaying the audit log.

## Micro-concepts
- **INSERT-only table**: a trigger raises exception on UPDATE or DELETE; INSERTs are the only permitted operation
- **old_data / new_data JSONB**: complete row snapshots using `row_to_json(OLD)::JSONB`
- **who**: the actor (agent_id, user_id) from current_setting
- **what**: the operation type (INSERT/UPDATE/DELETE) and table name
- **when**: logged_at TIMESTAMPTZ with DEFAULT now()
- **Retention vs. deletion**: old audit rows are archived (moved to cold storage), never deleted
- **Tamper evidence**: disabling the immutability trigger requires DDL privileges the agent does not have

## Beginner view
Imagine the audit log as a notarized journal. Every action gets a new page — you can add pages but you cannot tear them out or erase what is written. If someone tries to erase a page, the notary stamp self-destructs and alarms. The journal is a complete history of everything that happened.

## Intermediate view
```sql
-- blocked: Docker not accessible

CREATE TABLE agent_audit_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name  TEXT NOT NULL,
  operation   TEXT NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
  agent_id    TEXT NOT NULL,
  tenant_id   TEXT,
  row_id      UUID,
  old_data    JSONB,
  new_data    JSONB,
  changed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  tool_name   TEXT,
  session_id  TEXT
);

-- Immutability enforcer
CREATE OR REPLACE FUNCTION audit_immutability_guard()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION
    'agent_audit_log is INSERT-only. Operation % is not permitted. '
    'Contact the DBA if archival is needed.',
    TG_OP;
END;
$$;

CREATE TRIGGER enforce_audit_immutability
BEFORE UPDATE OR DELETE ON agent_audit_log
FOR EACH ROW EXECUTE FUNCTION audit_immutability_guard();

-- Prevent TRUNCATE as well
CREATE TRIGGER enforce_audit_no_truncate
BEFORE TRUNCATE ON agent_audit_log
FOR EACH STATEMENT EXECUTE FUNCTION audit_immutability_guard();
```

## Advanced view
```sql
-- blocked: Docker not accessible

-- Generic audit trigger for any table
CREATE OR REPLACE FUNCTION capture_audit_event()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_agent_id  TEXT := current_setting('app.agent_id', true);
  v_tenant_id TEXT := current_setting('app.tenant_id', true);
  v_tool_name TEXT := current_setting('app.tool_name', true);
  v_row_id    UUID;
BEGIN
  v_row_id := CASE
    WHEN TG_OP = 'DELETE' THEN (row_to_json(OLD)->>'id')::UUID
    ELSE (row_to_json(NEW)->>'id')::UUID
  END;

  INSERT INTO agent_audit_log(
    table_name, operation, agent_id, tenant_id, row_id,
    old_data, new_data, tool_name
  ) VALUES (
    TG_TABLE_NAME,
    TG_OP,
    coalesce(v_agent_id, 'unknown'),
    v_tenant_id,
    v_row_id,
    CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN row_to_json(OLD)::JSONB END,
    CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN row_to_json(NEW)::JSONB END,
    v_tool_name
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Attach to any write table
CREATE TRIGGER audit_documents
AFTER INSERT OR UPDATE OR DELETE ON documents
FOR EACH ROW EXECUTE FUNCTION capture_audit_event();

-- Forensic queries
-- Who changed document X and when?
SELECT agent_id, operation, old_data->>'status' AS old_status,
       new_data->>'status' AS new_status, changed_at
FROM agent_audit_log
WHERE table_name = 'documents'
  AND row_id = 'doc-uuid-here'::UUID
ORDER BY changed_at;

-- What did agent Y do in the last hour?
SELECT table_name, operation, row_id, tool_name, changed_at
FROM agent_audit_log
WHERE agent_id = 'agent-y'
  AND changed_at > now() - INTERVAL '1 hour'
ORDER BY changed_at;
```

## Mental model
The audit log is a black box flight recorder. It runs continuously, captures everything, and is sealed against tampering. When something goes wrong, the forensic team reads the recorder — they cannot erase it, and neither can the agent. Unlike a black box that only runs during the flight, the audit log runs forever.

## PostgreSQL view
```sql
-- blocked: Docker not accessible

-- Archival: move old rows to cold storage (never delete)
-- Run as a privileged maintenance job, not as the agent role

INSERT INTO agent_audit_log_archive
SELECT * FROM agent_audit_log
WHERE changed_at < now() - INTERVAL '90 days';

-- Delete from live table ONLY after archive is confirmed
DELETE FROM agent_audit_log
WHERE changed_at < now() - INTERVAL '90 days'
  AND id IN (SELECT id FROM agent_audit_log_archive
             WHERE changed_at < now() - INTERVAL '90 days');

-- The archive table itself is also INSERT-only
-- (same immutability trigger applies)

-- Check: has the immutability trigger been disabled?
SELECT tgname, tgenabled
FROM pg_trigger
WHERE tgrelid = 'agent_audit_log'::regclass;
-- tgenabled should be 'O' (origin firing) for all triggers
-- 'D' means disabled — alarm condition
```

## SQL view
The forensic query patterns are simple: filter by agent_id, table_name, or row_id; order by changed_at. Because old_data and new_data are JSONB, you can query any column's historical value without schema changes: `old_data->>'status'` retrieves the status at the time of the event.

## Non-SQL or hybrid view
Some systems use append-only event stores (Kafka, EventStore) as the audit trail. PostgreSQL provides ACID durability that Kafka does not — a committed audit row is guaranteed to survive crashes. For compliance-grade auditability, PostgreSQL is preferred because the guarantee is transactional: the business event and the audit row commit together or not at all.

## Design principle
**The audit trigger and the business operation commit in the same transaction.** If the audit write fails, the business operation rolls back. You never have a situation where an operation happened but was not logged — the two are atomic.

## Critical thinking
- **What if a superuser runs a manual DELETE on the audit table?** The trigger fires and raises an exception. The superuser would need to `ALTER TABLE audit_log DISABLE TRIGGER` first — that DDL statement itself should be monitored by a pg_audit extension or an external log aggregator.
- **What if old_data is very large?** JSONB compression helps. For very large rows, store only the changed columns in old_data using `hstore_diff` patterns or by capturing only the columns that actually changed.
- **What about schema changes?** If a column is renamed or removed, historical JSONB still contains the old column name. This is a feature, not a bug — the audit log preserves the state as it was at the time of the event.
- **What if the audit log itself grows too large?** Partition by month using declarative partitioning. Detach old partitions and move them to slower storage. Never drop them.

## Creative thinking
Design a **differential audit**: instead of storing the full old and new rows, compute and store only the diff (which columns changed, from what value, to what value). This reduces storage by 80% for wide tables. Use a PostgreSQL function that compares two JSONB objects and returns only the keys that differ.

## Systems thinking
The audit log is the **ground truth** of the system. Everything else — application logs, metrics, agent memory — may have gaps, approximations, or inconsistencies. The audit log, being commit-synchronized, is the authoritative record. When any other source contradicts the audit log, the audit log is right.

## MCP and agent perspective
From the MCP perspective, audit logging is invisible to the agent — it happens in a trigger after the write, before the transaction commits. The agent cannot disable it, cannot read it (RLS blocks access), and cannot know from the tool's output whether the log was written. The log exists for humans, not for agents.

## Ontology perspective
The audit log is an **event sourcing system** embedded in the relational model. Each row is an event: it has a subject (agent), a verb (INSERT/UPDATE/DELETE), an object (table + row_id), a time, and a payload (old/new data). The current state of any row is the projection of all events for that row_id.

## Practice session
1. Write the immutability trigger that prevents UPDATE and DELETE on the audit log table.
2. Write the generic audit trigger that captures old_data and new_data for any table it is attached to.
3. Write a query that reconstructs the complete history of changes to a document with a given UUID.
4. Design the archival job: write the SQL that moves rows older than 90 days to an archive table in one atomic transaction.
5. How would you detect if the immutability trigger has been disabled? Write the monitoring query.

## References
- PostgreSQL Triggers: https://www.postgresql.org/docs/16/plpgsql-trigger.html
- PostgreSQL JSONB: https://www.postgresql.org/docs/16/datatype-json.html
- pg_audit extension: https://github.com/pgaudit/pgaudit
- Event sourcing with PostgreSQL: https://www.postgresql.org/docs/16/sql-createtable.html
