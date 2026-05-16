# Functions, Triggers, and Audit Patterns

Level: Intermediate

## One-line intuition
Triggers are automatic callbacks that fire when data changes — use them to enforce invariants and write audit trails without trusting the application layer.

## Why this exists
Applications can be buggy, bypassed, or replaced. If audit logging or business-rule enforcement lives only in application code, a direct `psql` session or a data migration can silently violate it. Triggers and stored functions move critical logic into the database itself, making it impossible to bypass through any access path.

## First-principles explanation
A PostgreSQL trigger is a function bound to a table event (`INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`) that runs automatically. Trigger functions are written in PL/pgSQL (or other procedural languages) and return a special `TRIGGER` type. They receive `NEW` (the incoming row) and `OLD` (the previous row) as implicit variables. Triggers can be `BEFORE` (modify or cancel the operation), `AFTER` (react after the fact), or `INSTEAD OF` (on views). Row-level triggers fire once per affected row; statement-level triggers fire once per SQL statement. Audit patterns use `AFTER` triggers to write immutable records of what changed, who changed it, and when.

## Micro-concepts
- **PL/pgSQL function** — stored procedural function with loops, conditions, and SQL; the primary language for trigger functions
- **BEFORE trigger** — can modify `NEW` or return `NULL` to cancel the operation; used for validation and normalization
- **AFTER trigger** — cannot modify the operation; used for side effects like audit logging and notifications
- **INSTEAD OF trigger** — fires on views; redirects DML to underlying tables
- **Transition tables** — `REFERENCING NEW TABLE AS new_rows` for efficient statement-level bulk auditing
- **`current_user` / `session_user`** — identity of the executing role; included in audit rows
- **`TG_OP`** — trigger variable containing the operation type: INSERT, UPDATE, DELETE, TRUNCATE
- **`TG_TABLE_NAME`** — trigger variable with the table name; enables generic audit functions
- **`NEW` / `OLD`** — implicit row variables in row-level triggers
- **`pg_notify()`** — send async notification from a trigger; enables event-driven architectures

## Beginner view
Think of a trigger like a motion sensor: when someone opens a door (changes a row), the alarm (trigger function) goes off automatically. You don't have to remember to set it each time.

## Intermediate view
Design audit triggers to write to a separate `audit_log` table with columns: `table_name`, `operation`, `old_data JSONB`, `new_data JSONB`, `changed_by`, `changed_at`. Use `row_to_json(OLD)` and `row_to_json(NEW)` to capture full row snapshots. Keep trigger functions small and fast — they run synchronously inside the transaction. Long-running work should be deferred to a job queue via `pg_notify`.

## Advanced view
Trigger overhead accumulates on high-write tables. Profile with `EXPLAIN ANALYZE` and `pg_stat_user_tables`. Consider statement-level triggers with transition tables (`REFERENCING NEW TABLE AS new_rows`) for bulk insert auditing — far more efficient than row-level triggers on `COPY` operations. Be aware that triggers do not fire on `TRUNCATE` by default for row-level; only statement-level `TRUNCATE` triggers exist. Logical replication consumers (Debezium, pglogical) may be a better audit mechanism at scale.

## Mental model
A trigger is a contract written in the database: "Every time this thing happens, this other thing also happens — guaranteed, regardless of who did the first thing."

## PostgreSQL view
```sql
-- List all triggers
SELECT trigger_name, event_manipulation, event_object_table,
       action_timing, action_orientation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, action_timing;

-- Inspect trigger function source
SELECT prosrc FROM pg_proc WHERE proname = 'audit_trigger_fn';
```

## SQL view
```sql
-- Audit log table
CREATE TABLE audit_log (
  id          BIGSERIAL PRIMARY KEY,
  table_name  TEXT NOT NULL,
  operation   TEXT NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
  old_data    JSONB,
  new_data    JSONB,
  changed_by  TEXT NOT NULL DEFAULT current_user,
  changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Generic audit trigger function
CREATE OR REPLACE FUNCTION audit_trigger_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO audit_log (table_name, operation, old_data, new_data)
  VALUES (
    TG_TABLE_NAME,
    TG_OP,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE row_to_json(OLD)::jsonb END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE row_to_json(NEW)::jsonb END
  );
  RETURN NEW;
END;
$$;

-- Attach to a table
CREATE TRIGGER orders_audit
AFTER INSERT OR UPDATE OR DELETE ON orders
FOR EACH ROW EXECUTE FUNCTION audit_trigger_fn();

-- blocked: Docker not accessible; validate against cfp_postgres when available
```

## Non-SQL or hybrid view
Audit data stored as JSONB (`old_data`, `new_data`) enables rich querying: find all rows where a specific JSONB field changed using `old_data->>'status' != new_data->>'status'`. This makes the audit log self-describing and queryable without schema migrations when the source table changes.

## Design principle
Never put audit logic solely in application code — always back it with a database trigger so that direct SQL sessions, migrations, and background workers are audited too.

## Critical thinking
Triggers fire inside the same transaction as the originating statement. What happens to your audit log if the outer transaction rolls back? Is an aborted audit record a problem or a feature?

## Creative thinking
Could triggers be used to implement event sourcing inside PostgreSQL — storing every state change as an immutable event and deriving current state by replaying the audit log?

## Systems thinking
Triggers interact with transaction isolation (they see the same snapshot), replication (triggers fire on replicas with `session_replication_role`), and connection poolers (which may reuse sessions, affecting `current_user` in audit rows). Always test triggers in your full stack, not just `psql`.

## MCP and agent perspective
Audit triggers are the database's immune system against agent misbehavior. An AI agent making bulk updates without `WHERE` clauses will leave a full record in the audit log. Agents should be designed to query the audit log for their own recent actions before retrying, to detect and avoid duplicate operations.

## Ontology perspective
Triggers are the enforcement arm of business invariants — they move ontological rules from the application layer (where they can be forgotten or bypassed) into the database layer (where they are always enforced). The audit log is an ontological record of state transitions: each row captures a fact about what changed, who changed it, and when. This makes the audit log a queryable event store — a temporal record of the ontology's evolution.

`TG_TABLE_NAME` enables generic audit functions that apply across all tables, reflecting the ontological principle that the audit pattern is universal (every entity change should be recorded), not table-specific.

## Practice session
See `practice/intermediate/11-audit-triggers/` for hands-on exercises building a generic audit trigger and querying the audit log.

## References
- PostgreSQL docs — CREATE TRIGGER: https://www.postgresql.org/docs/16/sql-createtrigger.html
- PostgreSQL docs — PL/pgSQL: https://www.postgresql.org/docs/16/plpgsql.html
- PostgreSQL docs — Trigger Functions: https://www.postgresql.org/docs/16/plpgsql-trigger.html
- PostgreSQL docs — Trigger Transition Tables: https://www.postgresql.org/docs/16/sql-createtrigger.html#SQL-CREATETRIGGER-DESCRIPTION
- "PostgreSQL Audit Trigger" (2ndQuadrant): https://github.com/2ndQuadrant/audit-trigger
