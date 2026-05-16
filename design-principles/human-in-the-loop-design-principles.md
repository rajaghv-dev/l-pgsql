# Human-in-the-Loop Design Principles

Five principles for designing human approval workflows that are database-backed, tamper-resistant, and reliable when integrated with AI agent systems.

---

## Principle 1: High-Risk Actions Always Require Human Approval

**Define "high-risk" at design time; never let the agent decide at runtime whether approval is needed.**

High-risk criteria are baked into the tool's design, not computed by the agent on each invocation. The agent cannot self-certify that its action is low-risk.

High-risk criteria (examples):
- Financial: amount > configurable threshold
- Regulated domain: any write to medical, legal, financial record tables
- Irreversible: archive, hard-delete, bulk status change
- Cross-tenant: any action that affects data outside the requesting agent's tenant
- Novel: first occurrence of an action type for this tenant

```sql
-- blocked: Docker not accessible

-- Tool enforces approval routing; agent cannot bypass
CREATE OR REPLACE FUNCTION close_invoice(p_invoice_id UUID, p_agent_id TEXT)
RETURNS JSONB SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_amount NUMERIC;
  v_pending_id UUID;
BEGIN
  SELECT amount INTO v_amount FROM invoices WHERE id = p_invoice_id;

  -- High-risk threshold: always route to pending_actions
  IF v_amount > 10000 THEN
    INSERT INTO pending_actions(action_type, target_table, target_id,
                                payload, requested_by, tenant_id)
    VALUES ('close_invoice', 'invoices', p_invoice_id,
            jsonb_build_object('invoice_id', p_invoice_id, 'amount', v_amount),
            p_agent_id, current_setting('app.tenant_id'))
    RETURNING id INTO v_pending_id;

    RETURN jsonb_build_object('status', 'pending_approval',
                              'pending_action_id', v_pending_id);
  END IF;
  -- Low-risk: execute directly
  UPDATE invoices SET status = 'closed' WHERE id = p_invoice_id;
  RETURN jsonb_build_object('status', 'executed');
END;
$$;
```

**Why**: If the agent decides what is high-risk, a misconfiguration or prompt injection can convince it that every action is low-risk. The threshold is code, not reasoning.

---

## Principle 2: Approval Workflow Is Database-Backed, Not In-Memory

**Store pending_actions in PostgreSQL, not in Redis, not in application memory, not in a message queue.**

An in-memory approval queue disappears on restart. A Redis queue loses durability guarantees. A message queue has at-least-once semantics that can lead to double-approval. PostgreSQL provides ACID durability: an approved action is committed or not; there is no ambiguous state.

```sql
-- blocked: Docker not accessible

-- The complete state is in the database:
-- pending → reviewed_by/reviewed_at set → status = 'approved'/'rejected'
-- Background worker picks up approved rows with FOR UPDATE SKIP LOCKED
-- If worker crashes mid-execution, the row is still 'approved' and will be retried

SELECT id, action_type, payload
FROM pending_actions
WHERE status = 'approved'
  AND expires_at > now()
ORDER BY reviewed_at ASC
FOR UPDATE SKIP LOCKED
LIMIT 1;
```

**Why**: Database-backed workflows survive crashes, restarts, and deployments. The approval state is always queryable, auditable, and consistent with business data in the same ACID transaction.

---

## Principle 3: An Agent Cannot Approve Its Own Requests

**Enforce self-approval prevention in the database, not in application code.**

An application-layer check ("if reviewer_id == requester_id, reject") can be bypassed by calling the database directly or by a bug in the application. A database trigger that raises an exception on self-approval cannot be bypassed by the agent (which lacks ALTER TABLE privileges).

```sql
-- blocked: Docker not accessible

CREATE OR REPLACE FUNCTION prevent_self_approval()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status IN ('approved', 'rejected') AND
     NEW.reviewed_by = OLD.requested_by THEN
    RAISE EXCEPTION
      'Self-approval denied: agent % cannot approve its own request',
      OLD.requested_by;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER no_self_approval
BEFORE UPDATE ON pending_actions
FOR EACH ROW EXECUTE FUNCTION prevent_self_approval();
```

**Why**: Structural enforcement is always more reliable than behavioral enforcement. The database trigger runs regardless of which code path updates the row.

---

## Principle 4: Timeout Makes Actions Expire Safely

**When a pending action is not reviewed within the expiry window, it expires — it is never auto-approved.**

A timeout that auto-approves is not a timeout — it is a delayed execution. The expiry window exists to bound how long an irreversible action can remain pending before the situation changes (the invoice is paid, the document is deleted, the context shifts). Expired actions are resubmitted fresh, with current context.

```sql
-- blocked: Docker not accessible

-- Scheduled job: runs every 15 minutes
UPDATE pending_actions
SET
  status = 'expired',
  review_notes = 'Automatically expired after timeout; resubmit if still needed'
WHERE status = 'pending'
  AND expires_at < now();

-- Agent is notified of expiry via NOTIFY (or polling this query):
SELECT id, action_type, requested_at, expires_at
FROM pending_actions
WHERE requested_by = current_setting('app.agent_id')
  AND status = 'expired'
  AND requested_at > now() - INTERVAL '1 hour';
```

**Why**: Auto-approval on timeout defeats the purpose of human oversight. The cost of re-submitting a request is lower than the cost of accidentally approving an outdated action.

---

## Principle 5: Human Decisions Are Logged Permanently

**Every approval and rejection decision is recorded in the audit log — permanently and immutably.**

The pending_actions table records the decision (reviewed_by, reviewed_at, review_notes, status). The audit trigger records the UPDATE that changed the status. Both records are immutable. Humans cannot retroactively claim they did not make a decision; agents cannot claim they did not request an action.

```sql
-- blocked: Docker not accessible

-- Audit trigger on pending_actions captures every status change:
CREATE TRIGGER audit_pending_action_decisions
AFTER UPDATE ON pending_actions
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION capture_audit_event();

-- Forensic query: all approval decisions made by reviewer X this week
SELECT
  pa.id,
  pa.action_type,
  pa.requested_by AS agent,
  pa.reviewed_by AS reviewer,
  pa.status AS decision,
  pa.review_notes,
  pa.reviewed_at
FROM pending_actions pa
WHERE pa.reviewed_by = $1
  AND pa.reviewed_at > now() - INTERVAL '7 days'
ORDER BY pa.reviewed_at DESC;
```

**Why**: Permanent decision logs create accountability for both humans (who approved) and agents (who requested). In regulated domains, this log is the compliance evidence that human oversight occurred.

---

## Summary

| # | Principle | Enforcement |
|---|-----------|------------|
| 1 | High-risk always needs approval | Tool function routes to pending_actions |
| 2 | Approval is database-backed | pending_actions table; ACID guarantees |
| 3 | Agent cannot self-approve | BEFORE UPDATE trigger raises exception |
| 4 | Timeout = expire, not auto-approve | Scheduled job sets status='expired' |
| 5 | Human decisions logged permanently | Audit trigger + immutable audit log |
