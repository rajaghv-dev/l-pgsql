# Medical Record Retrieval Agent Example

Level: Intermediate
⚠️ All data in this example is synthetic. This example does not provide medical diagnosis or treatment recommendations.

## Overview

A multi-tenant patient record system for a fictional healthcare provider called
"Helix Health". Demonstrates:

- **Read-only agent access** — the agent can only `SELECT` from `record_summaries`;
  it cannot INSERT, UPDATE, or DELETE patient records.
- **Mandatory access logging** — every retrieval by the agent is written to
  `agent_access_log`, enabling compliance review (analogous to HIPAA audit requirements
  on synthetic data).
- **Tenant isolation** — `patients` and `record_summaries` are scoped by `tenant_id`
  via RLS.

⚠️ All patient names, numbers, and medical content are entirely synthetic. Nothing
in this example constitutes medical, diagnostic, or treatment information.

## Schema

```sql
-- blocked: Docker not accessible; validate against cfp_postgres when available

CREATE TABLE patients (
    id             BIGSERIAL PRIMARY KEY,
    patient_number TEXT    NOT NULL UNIQUE,
    name           TEXT    NOT NULL,
    tenant_id      INT     NOT NULL
);

ALTER TABLE patients ENABLE ROW LEVEL SECURITY;

CREATE POLICY patients_tenant_isolation ON patients
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::INT);

CREATE INDEX idx_patients_tenant_id ON patients (tenant_id);

CREATE TABLE record_summaries (
    id            BIGSERIAL PRIMARY KEY,
    patient_id    BIGINT      NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    summary_type  TEXT        NOT NULL
                              CHECK (summary_type IN ('visit','lab','imaging','discharge','referral')),
    content       TEXT        NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_summaries_patient_id   ON record_summaries (patient_id);
CREATE INDEX idx_summaries_summary_type ON record_summaries (summary_type);

CREATE TABLE agent_access_log (
    id         BIGSERIAL PRIMARY KEY,
    patient_id BIGINT      NOT NULL REFERENCES patients(id),
    agent_id   TEXT        NOT NULL,
    accessed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    purpose    TEXT        NOT NULL DEFAULT 'record_retrieval'
);

CREATE INDEX idx_access_log_patient_id ON agent_access_log (patient_id);
CREATE INDEX idx_access_log_agent_id   ON agent_access_log (agent_id);

-- Agent role: SELECT on patients and record_summaries; INSERT on agent_access_log.
-- GRANT SELECT ON patients, record_summaries TO agent_role;
-- GRANT INSERT ON agent_access_log TO agent_role;
```

## Seed data

```sql
-- blocked: Docker not accessible

INSERT INTO patients (patient_number, name, tenant_id) VALUES
  ('HX-10001', 'Jordan M.',   1),
  ('HX-10002', 'Casey R.',    1),
  ('HX-10003', 'Morgan T.',   1),
  ('HX-20001', 'Riley A.',    2),
  ('HX-20002', 'Avery S.',    2);

-- Synthetic record summaries (no real medical data)
INSERT INTO record_summaries (patient_id, summary_type, content) VALUES
  (1, 'visit',
   'Routine annual checkup. Vitals within normal synthetic ranges. '
   'Follow-up recommended in 12 months.'),
  (1, 'lab',
   'Synthetic lab panel: all markers within reference range. '
   'No abnormal results identified.'),
  (1, 'imaging',
   'Chest X-ray: synthetic report — no acute findings. Normal cardiac silhouette.'),
  (2, 'visit',
   'Follow-up visit for previously noted condition. Symptom improvement noted. '
   'Medication regimen unchanged.'),
  (2, 'discharge',
   'Discharged following outpatient procedure. Post-procedure care instructions provided.'),
  (3, 'referral',
   'Referred to specialist for further evaluation. Appointment scheduled.'),
  (3, 'lab',
   'Lipid panel: synthetic values — all within acceptable synthetic reference range.'),
  (4, 'visit',
   'New patient intake. Medical history documented. Initial evaluation completed.'),
  (5, 'imaging',
   'MRI summary: synthetic — no structural abnormalities identified.');
```

## Example queries

### Retrieve summaries for a patient (agent pattern: log then read)

```sql
SET app.tenant_id = '1';

-- Step 1: log the access
INSERT INTO agent_access_log (patient_id, agent_id, purpose)
VALUES (1, 'agent-records-v1', 'record_retrieval');

-- Step 2: retrieve summaries
SELECT rs.summary_type,
       rs.created_at::DATE AS date,
       rs.content
FROM   record_summaries rs
WHERE  rs.patient_id = 1
ORDER  BY rs.created_at ASC;
```

### Find patients by partial name (current tenant)

```sql
SET app.tenant_id = '1';

SELECT id, patient_number, name
FROM   patients
WHERE  name ILIKE '%jordan%';
```

### Summary counts per patient (current tenant)

```sql
SET app.tenant_id = '1';

SELECT p.patient_number,
       p.name,
       COUNT(rs.id)                                      AS total_summaries,
       COUNT(*) FILTER (WHERE rs.summary_type = 'lab')   AS lab_count,
       COUNT(*) FILTER (WHERE rs.summary_type = 'visit') AS visit_count
FROM   patients       p
LEFT   JOIN record_summaries rs ON rs.patient_id = p.id
GROUP  BY p.id, p.patient_number, p.name
ORDER  BY p.patient_number;
```

### Agent activity log

```sql
SELECT al.agent_id,
       p.patient_number,
       al.purpose,
       al.accessed_at
FROM   agent_access_log al
JOIN   patients         p ON p.id = al.patient_id
ORDER  BY al.accessed_at DESC;
```

### Most recent record per patient

```sql
SET app.tenant_id = '1';

SELECT DISTINCT ON (rs.patient_id)
       p.patient_number,
       p.name,
       rs.summary_type,
       rs.created_at::DATE AS last_record_date
FROM   record_summaries rs
JOIN   patients         p ON p.id = rs.patient_id
ORDER  BY rs.patient_id, rs.created_at DESC;
```

## Validation queries

```sql
-- blocked: Docker not accessible

SELECT COUNT(*) FROM patients;          -- Expected: 5 (superuser)
SELECT COUNT(*) FROM record_summaries;  -- Expected: 9

-- RLS active on patients
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'patients';

-- Tenant 1 sees 3 patients
SET app.tenant_id = '1';
SELECT COUNT(*) FROM patients;          -- Expected: 3

-- Tenant isolation
SELECT COUNT(*) FROM patients WHERE tenant_id = 2;  -- Expected: 0

-- Access log starts empty
SELECT COUNT(*) FROM agent_access_log;  -- Expected: 0 initially
```

## Practice tasks

1. **Log-then-read enforcement.** Create a PL/pgSQL function
   `agent_get_summaries(p_patient_id BIGINT, p_agent_id TEXT)` that always inserts
   into `agent_access_log` before returning summaries, making it impossible to
   retrieve records without logging.

2. **Summary type FTS.** Add a `tsvector` column to `record_summaries` and a GIN
   index. Write an FTS query that finds all summaries containing "specialist" for
   the current tenant's patients.

3. **Access frequency.** Write a query that shows which patients have been accessed
   most frequently by agents in the last 30 days, sorted by access count descending.

4. **Tenant isolation test.** Set `app.tenant_id = '1'`. Write a query trying to
   read records for `patient_id = 4` (who belongs to tenant 2). What does RLS return?

5. **Selective read permission.** Add a `summary_type` column filter so the agent
   can only retrieve `'visit'` and `'discharge'` summaries (not `'imaging'` or `'lab'`).
   Implement this as a view `agent_visible_summaries` and grant SELECT on the view
   rather than the base table.

## MCP and agent perspective

An AI clinical assistant using this schema via MCP would:

- **Always log before reading** — the MCP tool implementation wraps every SELECT
  with a prior INSERT into `agent_access_log`, so access is auditable even if the
  LLM's reasoning is opaque.
- **No write access to records** — the agent role cannot modify `patients` or
  `record_summaries`, eliminating a class of accidental data corruption.
- **Tenant-scoped sessions** — `app.tenant_id` is set from the authenticated
  provider session; the agent cannot retrieve records from a different health system.
- **Summary, not diagnosis** — the agent retrieves and synthesises existing
  structured summaries; it does not generate medical conclusions.
- **Human in the loop** — all agent access logs are reviewable by compliance staff
  as an analogue to audit log requirements in regulated environments.

## Teardown

```sql
-- blocked: Docker not accessible
DROP TABLE IF EXISTS agent_access_log  CASCADE;
DROP TABLE IF EXISTS record_summaries  CASCADE;
DROP TABLE IF EXISTS patients          CASCADE;
```

## References

- Row-Level Security: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- DISTINCT ON: https://www.postgresql.org/docs/current/sql-select.html#SQL-DISTINCT
