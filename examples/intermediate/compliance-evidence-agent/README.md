# Compliance Evidence Agent Example

Level: Intermediate  
All data in this example is synthetic. This does not constitute compliance, legal, or regulatory advice.

## Overview

An AI agent collects and stores compliance evidence artifacts. The agent can INSERT evidence but cannot approve it (human-only) and cannot modify or delete existing evidence (INSERT-only enforcement).

## Schema

```sql
-- blocked: Docker not accessible; validate against cfp_postgres when available
CREATE TABLE controls (
    id BIGSERIAL PRIMARY KEY,
    control_code TEXT UNIQUE NOT NULL,
    description TEXT NOT NULL,
    owner TEXT NOT NULL,
    tenant_id INT NOT NULL
);

CREATE TABLE evidence (
    id BIGSERIAL PRIMARY KEY,
    control_id BIGINT REFERENCES controls(id),
    evidence_type TEXT NOT NULL,
    content TEXT NOT NULL,
    collected_by TEXT NOT NULL,
    collected_at TIMESTAMPTZ DEFAULT now(),
    approved BOOLEAN DEFAULT false,
    reviewed_by TEXT,
    reviewed_at TIMESTAMPTZ,
    tenant_id INT NOT NULL
);

ALTER TABLE evidence ENABLE ROW LEVEL SECURITY;
CREATE POLICY evidence_tenant ON evidence USING (tenant_id = current_setting('app.tenant_id')::int);

-- Evidence is INSERT-only (agent cannot modify or delete)
CREATE OR REPLACE FUNCTION prevent_evidence_modification()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Evidence records are immutable. Only INSERT is allowed.';
END;
$$;

CREATE TRIGGER evidence_immutable
BEFORE UPDATE OR DELETE ON evidence
FOR EACH ROW EXECUTE FUNCTION prevent_evidence_modification();

CREATE TABLE evidence_log (
    id BIGSERIAL PRIMARY KEY,
    evidence_id BIGINT REFERENCES evidence(id),
    action TEXT NOT NULL,
    performed_by TEXT,
    performed_at TIMESTAMPTZ DEFAULT now()
);
```

## Seed data (synthetic)

```sql
-- blocked: Docker not accessible
INSERT INTO controls (control_code, description, owner, tenant_id) VALUES
    ('CC-001', 'Access control review — quarterly', 'compliance-team', 1),
    ('CC-002', 'Data retention policy validation', 'data-team', 1);

INSERT INTO evidence (control_id, evidence_type, content, collected_by, tenant_id) VALUES
    (1, 'screenshot', 'Access review completed for Q1 2026 (synthetic)', 'agent-compliance', 1),
    (2, 'document', 'Data retention policy v2.1 applied (synthetic)', 'agent-compliance', 1);
```

## Example queries

```sql
-- blocked: Docker not accessible
SET app.tenant_id = '1';

-- Agent: collect new evidence
INSERT INTO evidence (control_id, evidence_type, content, collected_by, tenant_id)
VALUES (1, 'log_extract', 'Firewall log review completed (synthetic)', 'agent-compliance', 1);

-- Human: approve evidence (agents cannot do this)
UPDATE evidence SET approved = true, reviewed_by = 'compliance-manager', reviewed_at = now()
WHERE id = 1;

-- Agent: view pending evidence (unapproved)
SELECT e.id, c.control_code, e.evidence_type, e.collected_at
FROM evidence e JOIN controls c ON c.id = e.control_id
WHERE e.approved = false AND e.tenant_id = current_setting('app.tenant_id')::int;
```

## Practice tasks

1. Try to UPDATE an evidence row — observe the immutability trigger
2. Try to DELETE evidence — same result
3. Approve evidence as a human (direct UPDATE, bypassing the agent)
4. Add a second tenant's controls and verify RLS isolation

## MCP and agent perspective

- Tool `collect_evidence(control_id, evidence_type, content)` — INSERT only
- Tool `get_pending_evidence(control_id)` — SELECT WHERE approved = false
- Agent cannot call UPDATE or DELETE — no such tools exist
- Approval is always a human action via a separate UI

## Teardown

```sql
-- blocked: Docker not accessible
DROP TABLE IF EXISTS evidence_log CASCADE;
DROP TABLE IF EXISTS evidence CASCADE;
DROP TABLE IF EXISTS controls CASCADE;
```

## References

- [PostgreSQL Triggers](https://www.postgresql.org/docs/16/plpgsql-trigger.html)
- [Row Level Security](https://www.postgresql.org/docs/16/ddl-rowsecurity.html)
