# Pharma Quality Check Agent Example

Level: Intermediate
⚠️ All data in this example is synthetic. This example makes no regulatory claims and does not constitute guidance for any regulated process.

## Overview

A multi-tenant pharmaceutical batch quality tracking system for a fictional manufacturer
called "Apex Pharma". Demonstrates:

- **Read + log pattern** — the agent reads batch and quality check data, then logs
  every check it performs into `agent_check_log`. It cannot modify batch status.
- **Status immutability for agents** — only human QA staff can UPDATE `batches.status`;
  the agent role has no UPDATE grant.
- **Tenant isolation via RLS** — each manufacturer tenant sees only its own batches.

⚠️ All batch numbers, product names, and quality check data are entirely synthetic.

## Schema

```sql
-- blocked: Docker not accessible; validate against cfp_postgres when available

CREATE TABLE batches (
    id              BIGSERIAL PRIMARY KEY,
    batch_number    TEXT        NOT NULL UNIQUE,
    product_name    TEXT        NOT NULL,
    manufactured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status          TEXT        NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending','in_review','released','quarantined','rejected')),
    tenant_id       INT         NOT NULL
);

ALTER TABLE batches ENABLE ROW LEVEL SECURITY;

CREATE POLICY batches_tenant_isolation ON batches
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::INT);

CREATE INDEX idx_batches_tenant_id ON batches (tenant_id);
CREATE INDEX idx_batches_status    ON batches (status);

CREATE TABLE quality_checks (
    id            BIGSERIAL PRIMARY KEY,
    batch_id      BIGINT      NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    check_type    TEXT        NOT NULL
                              CHECK (check_type IN ('visual','chemical','microbial','packaging','stability')),
    result        TEXT        NOT NULL
                              CHECK (result IN ('pass','fail','inconclusive')),
    performed_by  TEXT        NOT NULL,
    performed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_quality_checks_batch_id ON quality_checks (batch_id);
CREATE INDEX idx_quality_checks_result   ON quality_checks (result);

CREATE TABLE agent_check_log (
    id              BIGSERIAL PRIMARY KEY,
    batch_id        BIGINT      NOT NULL REFERENCES batches(id),
    agent_id        TEXT        NOT NULL,
    check_performed TEXT        NOT NULL,
    logged_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_agent_check_log_batch_id ON agent_check_log (batch_id);
CREATE INDEX idx_agent_check_log_agent_id ON agent_check_log (agent_id);

-- Agent role: SELECT on batches and quality_checks; INSERT on agent_check_log.
-- Cannot UPDATE batches.status or quality_checks.
-- GRANT SELECT ON batches, quality_checks TO agent_role;
-- GRANT INSERT ON agent_check_log TO agent_role;
```

## Seed data

```sql
-- blocked: Docker not accessible

INSERT INTO batches (batch_number, product_name, manufactured_at, status, tenant_id) VALUES
  ('AP-2024-001', 'Synexil 200mg Tablets',  NOW() - INTERVAL '30 days', 'released',     1),
  ('AP-2024-002', 'Carbolex 500mg Capsules', NOW() - INTERVAL '20 days', 'in_review',    1),
  ('AP-2024-003', 'Veltrex Oral Solution',   NOW() - INTERVAL '10 days', 'pending',      1),
  ('AP-2024-004', 'Synexil 200mg Tablets',  NOW() - INTERVAL '5 days',  'quarantined',  1),
  ('MX-2024-001', 'Proxadol 100mg Tablets', NOW() - INTERVAL '15 days', 'released',     2),
  ('MX-2024-002', 'Fentrex Cream 1%',       NOW() - INTERVAL '8 days',  'in_review',    2);

INSERT INTO quality_checks (batch_id, check_type, result, performed_by) VALUES
  (1, 'visual',      'pass',         'qa.chen@apex.example'),
  (1, 'chemical',    'pass',         'qa.chen@apex.example'),
  (1, 'microbial',   'pass',         'qa.patel@apex.example'),
  (1, 'packaging',   'pass',         'qa.patel@apex.example'),
  (2, 'visual',      'pass',         'qa.chen@apex.example'),
  (2, 'chemical',    'inconclusive', 'qa.chen@apex.example'),
  (2, 'microbial',   'pass',         'qa.patel@apex.example'),
  (4, 'visual',      'fail',         'qa.patel@apex.example'),
  (4, 'chemical',    'fail',         'qa.chen@apex.example'),
  (5, 'visual',      'pass',         'qa.rivera@mxpharma.example'),
  (5, 'chemical',    'pass',         'qa.rivera@mxpharma.example'),
  (6, 'visual',      'pass',         'qa.kim@mxpharma.example');
```

## Example queries

### List batches pending agent review (current tenant)

```sql
SET app.tenant_id = '1';

SELECT id, batch_number, product_name, status, manufactured_at::DATE AS mfg_date
FROM   batches
WHERE  status IN ('pending', 'in_review')
ORDER  BY manufactured_at ASC;
```

### Agent check pattern: log then read

```sql
SET app.tenant_id = '1';

-- Step 1: log that the agent is reviewing this batch
INSERT INTO agent_check_log (batch_id, agent_id, check_performed)
VALUES (2, 'agent-qa-v1', 'quality_check_review');

-- Step 2: retrieve quality checks for the batch
SELECT check_type, result, performed_by, performed_at::DATE AS check_date
FROM   quality_checks
WHERE  batch_id = 2
ORDER  BY performed_at ASC;
```

### Summary: check results per batch (current tenant)

```sql
SET app.tenant_id = '1';

SELECT b.batch_number,
       b.product_name,
       b.status,
       COUNT(*)                                        AS total_checks,
       COUNT(*) FILTER (WHERE qc.result = 'pass')     AS passed,
       COUNT(*) FILTER (WHERE qc.result = 'fail')     AS failed,
       COUNT(*) FILTER (WHERE qc.result = 'inconclusive') AS inconclusive
FROM   batches        b
LEFT   JOIN quality_checks qc ON qc.batch_id = b.id
GROUP  BY b.id, b.batch_number, b.product_name, b.status
ORDER  BY b.manufactured_at ASC;
```

### Batches with any failed checks

```sql
SET app.tenant_id = '1';

SELECT DISTINCT b.batch_number,
       b.product_name,
       b.status
FROM   batches       b
JOIN   quality_checks qc ON qc.batch_id = b.id
WHERE  qc.result = 'fail';
```

### Agent check log for audit

```sql
SELECT acl.agent_id,
       b.batch_number,
       b.product_name,
       acl.check_performed,
       acl.logged_at
FROM   agent_check_log acl
JOIN   batches         b ON b.id = acl.batch_id
ORDER  BY acl.logged_at DESC;
```

## Validation queries

```sql
-- blocked: Docker not accessible

SELECT COUNT(*) FROM batches;          -- Expected: 6 (superuser)
SELECT COUNT(*) FROM quality_checks;   -- Expected: 12

-- RLS active
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'batches';

-- Tenant 1 sees 4 batches
SET app.tenant_id = '1';
SELECT COUNT(*) FROM batches;          -- Expected: 4

-- Quarantined batches for tenant 1
SELECT batch_number FROM batches WHERE status = 'quarantined';
-- Expected: AP-2024-004

-- Agent log starts empty
SELECT COUNT(*) FROM agent_check_log;  -- Expected: 0 initially
```

## Practice tasks

1. **Status protection.** Verify that the agent role cannot run
   `UPDATE batches SET status = 'released' WHERE id = 4`. Document the permission
   error. Why is this separation important in a QA workflow?

2. **Inconclusive detector.** Write a query that returns all batches that have at
   least one inconclusive check and are still in `'in_review'` status. These need
   human follow-up.

3. **Check completeness.** Define the expected set of check types for a released
   batch as `{visual, chemical, microbial, packaging}`. Write a query that finds
   batches missing at least one expected check type.

4. **Agent log analysis.** After the agent reviews several batches, write a query
   grouping `agent_check_log` by `batch_id` to show how many times each batch has
   been reviewed and by which agents.

5. **Product-level summary.** Write a query that aggregates across all batches of
   the same `product_name`: total batches, pass rate, and most recent manufacture date.

## MCP and agent perspective

An AI quality-check agent using this schema via MCP would:

- **Read without modifying** — the agent gathers check results to produce a QA
  summary report; it cannot change batch status or alter existing check records.
- **Log every review** — inserting into `agent_check_log` before reading creates
  a regulatory-style audit trail showing which agent examined which batch and when.
- **Flag anomalies** — the agent queries for failed or inconclusive checks and
  surfaces them in a priority list for human QA staff.
- **Tenant-scoped** — the agent only sees the batches belonging to the authenticated
  manufacturer tenant.
- **No regulatory conclusions** — the agent identifies patterns in quality data;
  release, quarantine, and rejection decisions remain with human QA approvers.

## Teardown

```sql
-- blocked: Docker not accessible
DROP TABLE IF EXISTS agent_check_log CASCADE;
DROP TABLE IF EXISTS quality_checks  CASCADE;
DROP TABLE IF EXISTS batches         CASCADE;
```

## References

- Row-Level Security: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- FILTER in Aggregates: https://www.postgresql.org/docs/current/sql-expressions.html#SYNTAX-AGGREGATES
