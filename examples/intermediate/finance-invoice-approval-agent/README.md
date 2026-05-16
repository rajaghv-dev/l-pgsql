# Finance Invoice Approval Agent Example

Level: Intermediate
⚠️ All data in this example is synthetic. This example does not constitute financial advice.

## Overview

A multi-tenant invoice approval workflow for a fictional accounts-payable team called
"Clearpath Finance". Demonstrates:

- **Separation of duties** — the agent can submit approval requests but cannot approve
  them. Human approvers act on `approval_requests`.
- **Immutable audit log** — every action on an invoice (submission, approval, rejection)
  is appended to `audit_log`; the agent cannot delete or modify existing log entries.
- **Tenant isolation via RLS** — `invoices` and `approval_requests` are scoped by
  `tenant_id`.

⚠️ All vendor names, amounts, and invoice numbers are entirely synthetic.

## Schema

```sql
-- blocked: Docker not accessible; validate against cfp_postgres when available

CREATE TABLE invoices (
    id          BIGSERIAL PRIMARY KEY,
    vendor      TEXT           NOT NULL,
    amount      NUMERIC(15,2)  NOT NULL CHECK (amount > 0),
    status      TEXT           NOT NULL DEFAULT 'pending'
                               CHECK (status IN ('pending','under_review','approved','rejected')),
    created_at  TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    tenant_id   INT            NOT NULL
);

ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY invoices_tenant_isolation ON invoices
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::INT);

CREATE INDEX idx_invoices_tenant_id ON invoices (tenant_id);
CREATE INDEX idx_invoices_status    ON invoices (status);

CREATE TABLE approval_requests (
    id           BIGSERIAL PRIMARY KEY,
    invoice_id   BIGINT         NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    requested_by TEXT           NOT NULL,
    status       TEXT           NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending','approved','rejected')),
    reviewed_by  TEXT,
    reviewed_at  TIMESTAMPTZ,
    notes        TEXT
);

CREATE INDEX idx_approval_invoice_id ON approval_requests (invoice_id);
CREATE INDEX idx_approval_status     ON approval_requests (status);

CREATE TABLE audit_log (
    id           BIGSERIAL PRIMARY KEY,
    invoice_id   BIGINT      NOT NULL REFERENCES invoices(id),
    action       TEXT        NOT NULL,
    performed_by TEXT        NOT NULL,
    performed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_invoice_id   ON audit_log (invoice_id);
CREATE INDEX idx_audit_performed_at ON audit_log (performed_at);

-- Agent role: SELECT on invoices; INSERT on approval_requests and audit_log.
-- Cannot UPDATE invoices.status or UPDATE/DELETE approval_requests.
-- GRANT SELECT ON invoices TO agent_role;
-- GRANT INSERT ON approval_requests, audit_log TO agent_role;
```

## Seed data

```sql
-- blocked: Docker not accessible

INSERT INTO invoices (vendor, amount, status, tenant_id) VALUES
  ('Acme Supplies Inc.',     4500.00,  'pending',      1),
  ('Blue Ridge Consulting',  12000.00, 'under_review',  1),
  ('Crestview Software LLC', 8750.50,  'pending',      1),
  ('Delta Logistics Co.',    2300.00,  'approved',     1),
  ('Evergreen Services',     650.00,   'rejected',     1),
  ('Northgate Vendors Ltd',  9200.00,  'pending',      2),
  ('Summit Cloud Corp',      3100.00,  'under_review',  2);

-- Approval requests already submitted
INSERT INTO approval_requests (invoice_id, requested_by, status, reviewed_by, reviewed_at, notes)
VALUES
  (2, 'agent-ap-v1', 'pending',  NULL,              NULL, NULL),
  (4, 'agent-ap-v1', 'approved', 'finance.mgr@cp.example', NOW() - INTERVAL '2 days',
   'Standard vendor, amount within quarterly budget.'),
  (5, 'agent-ap-v1', 'rejected', 'finance.mgr@cp.example', NOW() - INTERVAL '1 day',
   'Duplicate submission. Original invoice INV-2023-441 already paid.');

-- Audit log entries
INSERT INTO audit_log (invoice_id, action, performed_by) VALUES
  (2, 'approval_request_submitted', 'agent-ap-v1'),
  (4, 'approval_request_submitted', 'agent-ap-v1'),
  (4, 'approved',                   'finance.mgr@cp.example'),
  (5, 'approval_request_submitted', 'agent-ap-v1'),
  (5, 'rejected',                   'finance.mgr@cp.example');
```

## Example queries

### Pending invoices awaiting agent submission (current tenant)

```sql
SET app.tenant_id = '1';

SELECT i.id,
       i.vendor,
       i.amount,
       i.created_at::DATE AS invoice_date
FROM   invoices i
WHERE  i.status = 'pending'
  AND  NOT EXISTS (
           SELECT 1 FROM approval_requests ar WHERE ar.invoice_id = i.id
       )
ORDER  BY i.amount DESC;
```

### Submit an approval request (agent pattern)

```sql
-- Step 1: create the approval request
INSERT INTO approval_requests (invoice_id, requested_by)
VALUES (1, 'agent-ap-v1');

-- Step 2: update invoice status to under_review
-- Note: in a strict agent setup this UPDATE would be done by the human workflow,
-- not the agent. Here shown for completeness.
UPDATE invoices SET status = 'under_review' WHERE id = 1;

-- Step 3: log the action
INSERT INTO audit_log (invoice_id, action, performed_by)
VALUES (1, 'approval_request_submitted', 'agent-ap-v1');
```

### View all approval requests with invoice details

```sql
SET app.tenant_id = '1';

SELECT ar.id          AS request_id,
       i.vendor,
       i.amount,
       ar.requested_by,
       ar.status      AS request_status,
       ar.reviewed_by,
       ar.reviewed_at::DATE AS reviewed_on,
       ar.notes
FROM   approval_requests ar
JOIN   invoices          i  ON i.id = ar.invoice_id
ORDER  BY ar.id;
```

### Audit trail for a specific invoice

```sql
SELECT action,
       performed_by,
       performed_at::DATE AS date
FROM   audit_log
WHERE  invoice_id = 4
ORDER  BY performed_at ASC;
```

### Summary: invoice counts by status (current tenant)

```sql
SET app.tenant_id = '1';

SELECT status, COUNT(*) AS invoice_count, SUM(amount) AS total_amount
FROM   invoices
GROUP  BY status
ORDER  BY status;
```

## Validation queries

```sql
-- blocked: Docker not accessible

SELECT COUNT(*) FROM invoices;            -- Expected: 7 (superuser)
SELECT COUNT(*) FROM approval_requests;   -- Expected: 3
SELECT COUNT(*) FROM audit_log;           -- Expected: 5

-- RLS active
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'invoices';

-- Tenant 1 sees 5 invoices
SET app.tenant_id = '1';
SELECT COUNT(*) FROM invoices;            -- Expected: 5

-- Tenant 1 cannot see tenant 2 invoices
SELECT COUNT(*) FROM invoices WHERE tenant_id = 2;  -- Expected: 0
```

## Practice tasks

1. **Submit a new request.** Using tenant 1, submit an approval request for invoice id=3
   and log the action to `audit_log`. Verify the request appears with status `'pending'`.

2. **High-value filter.** Write a query that returns all invoices with `amount > 5000`
   that are still in `'pending'` status and have no approval request yet. This is
   the agent's priority queue.

3. **Approval rate.** Write a query over `approval_requests` that computes the
   approval rate (approved / total reviewed) and the average review time in days.

4. **Separation of duties test.** Grant a limited role only SELECT on `invoices`
   and INSERT on `approval_requests`. Verify it cannot UPDATE `invoices.status` or
   INSERT into `audit_log`.

5. **Duplicate guard.** Add a UNIQUE constraint on `approval_requests(invoice_id)`
   to prevent the agent from submitting duplicate requests. Test by attempting to
   insert two requests for the same invoice.

## MCP and agent perspective

An AI accounts-payable agent using this schema via MCP would:

- **Submit, not approve** — the agent can INSERT approval requests but has no grant
  to UPDATE `approval_requests.status`, preserving human control over financial
  decisions.
- **Priority queue** — the agent queries for high-value pending invoices first,
  submitting requests ordered by amount descending.
- **Audit every action** — every INSERT into `approval_requests` is paired with
  an INSERT into `audit_log`, so human finance managers can see exactly what the
  agent did and when.
- **Tenant-scoped** — `app.tenant_id` is injected by the MCP server; the agent
  cannot access another tenant's invoices.
- **No financial decisions** — the agent routes invoices to the right approvers
  based on rules (amount thresholds, vendor category); it does not approve payments.

## Teardown

```sql
-- blocked: Docker not accessible
DROP TABLE IF EXISTS audit_log          CASCADE;
DROP TABLE IF EXISTS approval_requests  CASCADE;
DROP TABLE IF EXISTS invoices           CASCADE;
```

## References

- Row-Level Security: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- CHECK Constraints: https://www.postgresql.org/docs/current/ddl-constraints.html
