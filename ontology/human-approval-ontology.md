# Human Approval Ontology

> This ontology maps the concepts, state machine, and enforcement patterns for human-in-the-loop approval workflows backed by PostgreSQL.
> Use [[wikilink]] format to navigate between related ontology files.

---

## Core Concepts

### Pending Action
A database row representing an agent's request to perform a high-risk operation. The pending action is not executed until a human reviewer approves it. It expires if not reviewed within a defined window.

- Table: `pending_actions`
- Fields: id, action_type, target_table, target_id, payload JSONB, requested_by (agent_id), status, expires_at
- Related: [[agent-workflow-ontology]]

### Approval Status
The current state of a pending action in the state machine. States are enforced by a CHECK constraint — no other values are permitted.

```
pending (initial)
  ├─► approved (human action)
  │     └─► executed (background worker)
  ├─► rejected (human action)
  └─► expired (scheduled job; expires_at < now())
```

### Reviewer
A human user (not an agent) who evaluates pending actions and makes approval decisions. The reviewer's identity is stored in `reviewed_by` and must be a human user ID from the authentication system.

- Constraint: `reviewed_by` must not equal `requested_by` (enforced by trigger)
- Log: every approval decision is recorded permanently in the audit log
- Related: [[agent-workflow-ontology]]

### Approval Trigger
The condition that causes an agent operation to route through the pending_actions workflow rather than executing immediately. Triggers are defined at the tool level.

| Trigger condition | Example |
|------------------|---------|
| Amount > threshold | Invoice total > $10,000 |
| Irreversible operation | Archive, delete, bulk update |
| Regulated domain action | Medical record modification |
| First occurrence | New vendor onboarding |
| Cross-tenant action | Data export |

### Timeout
The maximum time a pending action waits for human review before expiring. Expired actions are marked with status='expired' by a scheduled job. Agents must resubmit; timeouts never auto-approve.

- Default: 24 hours (configurable per action_type)
- Enforcement: scheduled job runs `UPDATE pending_actions SET status='expired' WHERE status='pending' AND expires_at < now()`
- Policy: timeout always means "reject by inaction" — never "approve by default"

### NOTIFY/LISTEN
PostgreSQL's built-in pub/sub mechanism used to alert human reviewers in real time when a new pending action arrives. A trigger fires NOTIFY after INSERT; the reviewer's application LISTENs on the channel.

- Channel: `'pending_actions'` (or per-tenant channels)
- Payload: JSON with id, action_type, requested_by, tenant_id
- Alternative: polling the pending_actions table on a schedule

### Compensation
A forward-corrective action taken when an approved-and-executed action produces wrong outcomes. Unlike rollback (which reverts uncommitted data), compensation inserts a new event that triggers a reverse workflow.

- Table: `compensation_events`
- Inserted by: background worker when an executed action's downstream effects fail
- Related: [[agent-workflow-ontology]]

---

## State Machine

```
Agent submits pending action (INSERT status='pending')
           │
           ▼
     Reviewer notified (NOTIFY/LISTEN or polling)
           │
           ├──── expires_at < now() ──────► Expired (scheduled job)
           │
           ├──── Human rejects ───────────► Rejected (UPDATE by human)
           │                                 └─► Agent notified (NOTIFY)
           │
           └──── Human approves ──────────► Approved (UPDATE by human)
                                              │
                                              ▼
                                    Background worker picks up
                                    (SELECT FOR UPDATE SKIP LOCKED)
                                              │
                                              ├── success ──► Executed
                                              └── failure ──► Compensation event
```

---

## Database Enforcement

```sql
-- blocked: Docker not accessible

-- Status constraint
CHECK (status IN ('pending','approved','rejected','expired','executed'))

-- Self-approval prevention (trigger)
IF NEW.status IN ('approved','rejected') AND NEW.reviewed_by = OLD.requested_by THEN
  RAISE EXCEPTION 'Agent cannot approve or reject its own pending actions';
END IF;

-- Timeout enforcement (scheduled job)
UPDATE pending_actions
SET status = 'expired'
WHERE status = 'pending' AND expires_at < now();

-- Safe concurrent processing (worker query)
SELECT id, action_type, payload
FROM pending_actions
WHERE status = 'approved' AND expires_at > now()
FOR UPDATE SKIP LOCKED
LIMIT 1;
```

---

## Wikilinks

- [[agent-workflow-ontology]] — agent, action, audit, approval, rollback, compensation
- [[agent-permission-ontology]] — agent role, permission boundary, least privilege
- [[mcp-tool-ontology]] — high-risk tool classification, approval trigger
- [[security-ontology]] — audit immutability, tamper evidence

---

## Key Invariants

1. Agents can only INSERT pending_actions (status='pending'); they cannot UPDATE status
2. An agent cannot approve or reject its own pending actions (trigger enforced)
3. Timeout always means expire, never auto-approve
4. Every approval decision (approved/rejected) is audit-logged permanently
5. Background workers use SKIP LOCKED to prevent duplicate action execution
6. Compensation events are INSERT-only records — they are never updates to existing rows
