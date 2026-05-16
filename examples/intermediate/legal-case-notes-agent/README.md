# Legal Case Notes Agent Example

Level: Intermediate
⚠️ All data in this example is synthetic. This example does not constitute legal advice.

## Overview

A multi-tenant legal case management system for a fictional law firm called "Meridian Legal".
Demonstrates:

- **Row-Level Security (RLS)** by `tenant_id` — firm A cannot see firm B's cases.
- **Agent-safe permissions** — the agent role can only `SELECT` from `cases` and
  `case_notes`, and can only `INSERT` into `agent_reads` (an access log). It cannot
  modify or delete case records.
- **Access logging** — every record retrieval by the agent is tracked in `agent_reads`
  for audit and compliance.

⚠️ All case numbers, names, and notes are entirely synthetic.

## Schema

```sql
-- blocked: Docker not accessible; validate against cfp_postgres when available

CREATE TABLE cases (
    id            BIGSERIAL PRIMARY KEY,
    case_number   TEXT        NOT NULL UNIQUE,
    title         TEXT        NOT NULL,
    status        TEXT        NOT NULL DEFAULT 'open'
                              CHECK (status IN ('open','in_progress','closed','archived')),
    tenant_id     INT         NOT NULL
);

ALTER TABLE cases ENABLE ROW LEVEL SECURITY;

CREATE POLICY cases_tenant_isolation ON cases
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::INT);

CREATE INDEX idx_cases_tenant_id ON cases (tenant_id);
CREATE INDEX idx_cases_status    ON cases (status);

CREATE TABLE case_notes (
    id          BIGSERIAL PRIMARY KEY,
    case_id     BIGINT      NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    note_body   TEXT        NOT NULL,
    note_type   TEXT        NOT NULL DEFAULT 'general'
                            CHECK (note_type IN ('general','hearing','discovery','filing','ruling')),
    created_by  TEXT        NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_case_notes_case_id ON case_notes (case_id);

CREATE TABLE agent_reads (
    id        BIGSERIAL PRIMARY KEY,
    case_id   BIGINT      NOT NULL REFERENCES cases(id),
    agent_id  TEXT        NOT NULL,
    read_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_agent_reads_case_id  ON agent_reads (case_id);
CREATE INDEX idx_agent_reads_agent_id ON agent_reads (agent_id);

-- Agent role: read-only on cases and case_notes; INSERT-only on agent_reads
-- GRANT SELECT ON cases, case_notes TO agent_role;
-- GRANT INSERT ON agent_reads TO agent_role;
```

## Seed data

```sql
-- blocked: Docker not accessible

-- Tenants (superuser-managed, no RLS on this table)
-- Assuming tenant 1 = Meridian Legal, tenant 2 = Summit Law Group

INSERT INTO cases (case_number, title, status, tenant_id) VALUES
  ('ML-2024-001', 'Greenwood v. Hartley Properties – Lease Dispute',       'in_progress', 1),
  ('ML-2024-002', 'Estate of Ruiz – Probate Filing',                        'open',        1),
  ('ML-2024-003', 'Blackwell Corp Regulatory Compliance Review',            'closed',      1),
  ('SL-2024-001', 'Chen v. Northgate Holdings – Employment Claim',          'open',        2),
  ('SL-2024-002', 'Summit Land Trust – Property Transfer',                  'in_progress', 2);

INSERT INTO case_notes (case_id, note_body, note_type, created_by) VALUES
  (1, 'Initial pleadings filed. Defendant has 30 days to respond.',          'filing',    'atty.jones@meridian.example'),
  (1, 'Mediation scheduled for next month. Client briefed on process.',      'general',   'atty.jones@meridian.example'),
  (1, 'Discovery requests sent to opposing counsel.',                        'discovery', 'paralegal.kim@meridian.example'),
  (2, 'Death certificate and will submitted to probate court.',              'filing',    'atty.patel@meridian.example'),
  (2, 'Hearing set. Two beneficiaries contesting asset distribution.',       'hearing',   'atty.patel@meridian.example'),
  (3, 'Compliance review completed. No violations found. Case closed.',      'ruling',    'atty.jones@meridian.example'),
  (4, 'Complaint filed. EEOC right-to-sue letter attached.',                 'filing',    'atty.chen@summit.example'),
  (5, 'Title search ordered. Survey report pending.',                        'general',   'atty.lee@summit.example');
```

## Example queries

### List open cases for current tenant

```sql
SET app.tenant_id = '1';

SELECT id, case_number, title, status
FROM   cases
WHERE  status IN ('open', 'in_progress')
ORDER  BY case_number;
```

### Retrieve all notes for a case (agent pattern: log then read)

```sql
-- Step 1: log the access
INSERT INTO agent_reads (case_id, agent_id)
VALUES (1, 'agent-summariser-v1');

-- Step 2: retrieve notes
SELECT cn.note_type,
       cn.created_by,
       cn.created_at::DATE AS date,
       cn.note_body
FROM   case_notes cn
WHERE  cn.case_id = 1
ORDER  BY cn.created_at ASC;
```

### Notes by type for a case

```sql
SELECT note_type,
       COUNT(*)       AS note_count,
       MAX(created_at) AS latest
FROM   case_notes
WHERE  case_id = 1
GROUP  BY note_type
ORDER  BY latest DESC;
```

### Agent activity log for audit

```sql
SELECT ar.agent_id,
       c.case_number,
       c.title,
       ar.read_at
FROM   agent_reads ar
JOIN   cases       c  ON c.id = ar.case_id
ORDER  BY ar.read_at DESC;
```

### Cross-tenant RLS check

```sql
SET app.tenant_id = '1';
SELECT COUNT(*) FROM cases WHERE tenant_id = 2;
-- Expected: 0 (RLS blocks cross-tenant reads)
```

## Validation queries

```sql
-- blocked: Docker not accessible

SELECT COUNT(*) FROM cases;        -- Expected: 5 (superuser)
SELECT COUNT(*) FROM case_notes;   -- Expected: 8

-- RLS active on cases
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'cases';

-- Agent read log is empty before agent runs
SELECT COUNT(*) FROM agent_reads;  -- Expected: 0 initially

-- Indexes exist
SELECT indexname FROM pg_indexes WHERE tablename IN ('cases', 'case_notes', 'agent_reads');
```

## Practice tasks

1. **Tenant isolation.** Set `app.tenant_id = '1'` and attempt to select a case
   with `tenant_id = 2` directly. What does RLS return? Now set `app.tenant_id = '2'`
   and verify that Summit Law cases are visible.

2. **Note search.** Add a `tsvector` column to `case_notes` and maintain it with
   a trigger. Write an FTS query that finds all notes containing the word "hearing"
   for the current tenant's cases.

3. **Agent access summary.** After running several `agent_reads` inserts, write a
   query that counts how many times each agent has accessed each case, and what
   the most recent access was.

4. **Permission test.** Create a limited role `agent_role`, grant it only SELECT on
   `cases` and `case_notes` and INSERT on `agent_reads`. Connect as that role and
   verify it cannot UPDATE a case or DELETE a note.

5. **Bulk retrieval pattern.** Simulate an agent that summarises all open cases:
   for each open case, insert one `agent_reads` row, then return the case plus its
   note count. Write this as a single query using a CTE with a data-modifying
   statement (`WITH ins AS (INSERT ...) SELECT ...`).

## MCP and agent perspective

An AI legal assistant using this schema via MCP would:

- **Read-only by design** — the agent role has no UPDATE or DELETE grants, so a
  hallucinated SQL mutation cannot modify case records, even if the model generates
  one.
- **Log before reading** — the agent pattern inserts into `agent_reads` before
  fetching notes, creating an immutable audit trail for compliance review.
- **Tenant-scoped** — `SET app.tenant_id` is injected by the MCP server from the
  authenticated session; the agent cannot override it.
- **Note summarisation** — the agent fetches all notes for a case, passes them as
  context to the LLM, and returns a structured summary without modifying the source.
- **No legal judgments** — the agent synthesises information from notes; it does
  not generate legal strategy, advice, or filings.

## Teardown

```sql
-- blocked: Docker not accessible
DROP TABLE IF EXISTS agent_reads  CASCADE;
DROP TABLE IF EXISTS case_notes   CASCADE;
DROP TABLE IF EXISTS cases        CASCADE;
```

## References

- Row-Level Security: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- Data-modifying CTEs: https://www.postgresql.org/docs/current/queries-with.html#QUERIES-WITH-MODIFYING
