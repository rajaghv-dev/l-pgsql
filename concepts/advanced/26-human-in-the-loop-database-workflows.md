# Human-in-the-Loop Database Workflows
Level: Advanced

## One-line intuition
High-risk agent actions should not execute immediately — they enter a database-backed approval queue where a human must explicitly approve or reject before the action proceeds.

## Why this exists
AI agents can be wrong. They can misinterpret instructions, hallucinate context, or produce actions that look correct but are not. For irreversible or high-impact operations, the cost of a mistake exceeds the cost of a human review. The human-in-the-loop pattern makes this review mandatory — and the database enforces it, not the agent's self-assessment.

## First-principles explanation
The pattern is a state machine stored in a `pending_actions` table:

```
pending → approved → executed
       → rejected
       → expired (timeout)
```

The agent can only move from "none" to "pending". A human moves from "pending" to "approved" or "rejected". A background job moves from "approved" to "executed". The agent cannot skip steps, cannot approve its own requests, and cannot read other agents' pending actions (RLS).

NOTIFY/LISTEN provides real-time notification: when a new pending action is inserted, a trigger fires NOTIFY, and the human reviewer's application receives the event instantly without polling.

SKIP LOCKED in the execution queue prevents two worker processes from picking up the same approved action simultaneously.

## Micro-concepts
- **pending_actions table**: the database-backed approval queue
- **Status machine**: pending → approved/rejected/expired, enforced by CHECK constraint
- **NOTIFY/LISTEN**: PostgreSQL's built-in pub/sub for real-time approval notifications
- **SKIP LOCKED**: skips rows locked by another transaction — safe concurrent queue processing
- **Timeout**: an `expires_at` column; a background job marks stale pending rows as 'expired'
- **Compensation**: if an approved action fails during execution, a compensation event is inserted
- **Agent cannot self-approve**: enforced by a trigger that checks `requested_by != approved_by`

## Beginner view
Imagine a pending_actions table as a physical inbox on a manager's desk. The agent drops a request note in the inbox (INSERT with status='pending'). The manager reads it, stamps "approved" or "rejected" (UPDATE by human). A mail room worker picks up approved notes and executes them (background job with SKIP LOCKED). The agent cannot stamp its own notes.

## Intermediate view
```sql
-- blocked: Docker not accessible

CREATE TABLE pending_actions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_type   TEXT NOT NULL,
  target_table  TEXT NOT NULL,
  target_id     UUID,
  payload       JSONB NOT NULL,
  requested_by  TEXT NOT NULL,  -- agent_id
  tenant_id     TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','approved','rejected','expired','executed')),
  requested_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '24 hours',
  reviewed_by   TEXT,
  reviewed_at   TIMESTAMPTZ,
  review_notes  TEXT,
  executed_at   TIMESTAMPTZ
);

-- Enforce: agent cannot approve its own request
CREATE OR REPLACE FUNCTION check_self_approval()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status IN ('approved','rejected') AND
     NEW.reviewed_by = OLD.requested_by THEN
    RAISE EXCEPTION 'Agent cannot approve or reject its own pending actions';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER no_self_approval
BEFORE UPDATE ON pending_actions
FOR EACH ROW EXECUTE FUNCTION check_self_approval();
```

## Advanced view
```sql
-- blocked: Docker not accessible

-- NOTIFY on new pending action (triggers real-time reviewer notification)
CREATE OR REPLACE FUNCTION notify_new_pending_action()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_notify(
    'pending_actions',
    json_build_object(
      'id', NEW.id,
      'action_type', NEW.action_type,
      'requested_by', NEW.requested_by,
      'tenant_id', NEW.tenant_id
    )::text
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER notify_on_insert
AFTER INSERT ON pending_actions
FOR EACH ROW EXECUTE FUNCTION notify_new_pending_action();

-- Worker picks up approved actions without conflicts
SELECT id, action_type, payload
FROM pending_actions
WHERE status = 'approved'
  AND expires_at > now()
ORDER BY reviewed_at ASC
FOR UPDATE SKIP LOCKED
LIMIT 1;

-- Expire stale pending actions (run as a scheduled job)
UPDATE pending_actions
SET status = 'expired'
WHERE status = 'pending'
  AND expires_at < now();
```

## Mental model
The pending_actions table is a **two-key safe**: the agent can open the first keyhole (INSERT pending action), but the safe only opens when a human turns the second key (UPDATE to approved). The background worker is the door mechanism — it only engages when both keys have been turned. SKIP LOCKED ensures two workers do not both try to turn the mechanism at the same time.

## PostgreSQL view
```sql
-- blocked: Docker not accessible

-- Human reviewer dashboard query
SELECT
  pa.id,
  pa.action_type,
  pa.requested_by,
  pa.payload,
  pa.requested_at,
  pa.expires_at,
  extract(epoch from (pa.expires_at - now()))/3600 AS hours_remaining
FROM pending_actions pa
WHERE pa.status = 'pending'
  AND pa.tenant_id = current_setting('app.tenant_id')
  AND pa.expires_at > now()
ORDER BY pa.requested_at ASC;

-- Human approves an action
UPDATE pending_actions
SET
  status = 'approved',
  reviewed_by = current_setting('app.user_id'),
  reviewed_at = now(),
  review_notes = 'Verified against source document'
WHERE id = $1
  AND status = 'pending'
  AND expires_at > now();

-- LISTEN in application code (pseudocode for documentation)
-- conn.execute("LISTEN pending_actions")
-- while True:
--   notification = conn.wait_for_notify(timeout=30)
--   if notification: process_new_approval_request(notification.payload)
```

## SQL view
The pending_actions status machine is enforced by a CHECK constraint (valid status values) and a trigger (no self-approval). The workflow is entirely in the database — no application-layer state machine is needed, which means no way to bypass it by calling the database directly.

## Non-SQL or hybrid view
Many systems implement approval workflows in application code (Airflow, Temporal, custom state machines). This is risky because the workflow state is in memory or a separate system — a crash or race condition can leave the database in an inconsistent state. PostgreSQL-backed workflows are durable: the state survives crashes, the constraint logic is atomic, and the NOTIFY/LISTEN mechanism handles real-time coordination without an external message broker.

## Design principle
**Approval workflow must be database-backed, not in-memory.** If the approval state is stored in the application process, a restart loses it. If it is stored in Redis, a Redis failure loses it. PostgreSQL provides ACID durability — approved actions are committed or not. There is no ambiguous state.

## Critical thinking
- **What if no human reviews in time?** The expires_at trigger marks the action 'expired'. The agent is notified and can resubmit with a fresh expiry window. Never auto-approve on timeout.
- **What if the human approves but execution fails?** The worker catches the exception, inserts a compensation event (what was attempted, what failed, what state was left), and marks the action 'failed' (add 'failed' to the status CHECK). The human is notified.
- **What if there are thousands of pending actions?** Index on (status, tenant_id, expires_at). Partition by status if needed. The SKIP LOCKED queue handles concurrent workers cleanly.
- **What if a human reviewer is also an agent?** The trigger that prevents self-approval should check against a `human_users` table — approved_by must be a human user ID, not an agent ID.

## Creative thinking
Design a **tiered approval** system: low-risk actions auto-approve after 1 hour with no objection (passive approval). Medium-risk require explicit human approval within 24 hours. High-risk require approval from two different humans. All tiers route through the same pending_actions table with a `risk_tier` column and different NOTIFY channels.

## Systems thinking
The human-in-the-loop pattern introduces a **feedback loop** between agent autonomy and human oversight. As the agent's track record improves (low error rate in audit logs), human reviewers can reduce review time or raise the risk threshold for human approval. As errors occur, the threshold drops. The pending_actions table is the connection point for this feedback loop.

## MCP and agent perspective
From the MCP perspective, high-risk tools do not execute immediately — they return a `pending_action_id`. The agent's next call is `get_approval_status(pending_action_id)`. If approved, the action has already been executed by the background worker. The agent never gets direct execution control over high-risk operations.

## Ontology perspective
The pending_actions table encodes an **approval ontology**: every row is an instance of the class PendingAction, with attributes (requested_by, payload, status) and relationships (to the acting Agent, to the reviewing Human, to the executed Action). The status transitions are the edges of a directed acyclic graph from 'pending' to terminal states.

## Practice session
1. Write the full pending_actions DDL with all constraints, including the self-approval trigger.
2. Write the NOTIFY trigger that fires when a new pending action is inserted.
3. Write the worker query using SKIP LOCKED that processes one approved action at a time.
4. Design the expires_at refresh workflow: how should the agent request a timeout extension for a pending action that has not yet been reviewed?
5. Add a `risk_tier` column and write a policy that auto-approves tier-1 actions after 30 minutes if no rejection.

## References
- PostgreSQL NOTIFY/LISTEN: https://www.postgresql.org/docs/16/sql-notify.html
- SELECT FOR UPDATE SKIP LOCKED: https://www.postgresql.org/docs/16/sql-select.html
- PostgreSQL CHECK constraints: https://www.postgresql.org/docs/16/ddl-constraints.html
- HITL patterns: https://lilianweng.github.io/posts/2023-06-23-agent/
