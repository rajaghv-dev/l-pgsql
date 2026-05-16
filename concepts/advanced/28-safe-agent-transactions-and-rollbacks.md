# Safe Agent Transactions and Rollbacks
Level: Advanced

## One-line intuition
Multi-step agent operations must execute inside a single PostgreSQL transaction so they atomically succeed or fail — and when they fail, a compensation event documents what was attempted and what state was left.

## Why this exists
An agent that performs five writes across three tables can succeed at steps 1-3 and fail at step 4. Without a transaction boundary, steps 1-3 have been committed and cannot be undone — the database is now in a partially-updated state. With a transaction, step 4's failure rolls back steps 1-3 as well. The agent never leaves the database in an inconsistent intermediate state.

## First-principles explanation
PostgreSQL transactions give the agent an "all or nothing" guarantee. The BEGIN/COMMIT block defines the boundary. Inside the boundary, every write is tentative — it exists in the transaction's private snapshot but is not yet visible to other connections. On COMMIT, all writes become permanent simultaneously. On ROLLBACK (or failure), none of the writes persist.

SAVEPOINTs add partial rollback: within a transaction, a SAVEPOINT marks a safe point. A ROLLBACK TO SAVEPOINT reverts to that point without aborting the entire transaction. This lets an agent attempt an optional step, and if it fails, revert just that step and continue.

The compensation pattern handles the case where a multi-step operation committed successfully but the downstream consequence must be undone: instead of rolling back committed data (impossible after COMMIT), a compensation event records the failure mode and triggers a reverse action.

## Micro-concepts
- **Transaction boundary**: BEGIN...COMMIT wraps all agent writes; failure rolls back all of them
- **SAVEPOINT**: marks a point in a transaction; ROLLBACK TO SAVEPOINT reverts only to that point
- **Compensation event**: a new INSERT that records a failed outcome and triggers a reverse action — used when rollback is insufficient (committed data must be corrected logically)
- **lock_timeout**: prevents an agent from holding a lock forever; SET LOCAL lock_timeout = '5s'
- **statement_timeout**: prevents a single query from running forever; SET LOCAL statement_timeout = '30s'
- **Idempotency**: designing operations so that executing them twice produces the same result as executing once — critical for retry safety
- **Retry with exponential backoff**: on serialization failure (ERROR 40001), retry the transaction after a short delay

## Beginner view
A transaction is a shopping cart: you add items (writes) as you shop. When you check out (COMMIT), all items are purchased atomically. If your card is declined (failure), nothing is purchased — you do not get some items and not others. A SAVEPOINT is a "hold this cart while I try the expensive item" — if the expensive item fails, you revert to the held cart and check out with what you had.

## Intermediate view
```sql
-- blocked: Docker not accessible

-- Agent multi-step operation in one transaction
BEGIN;

-- Set timeouts to prevent agent from holding locks indefinitely
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- Set agent context
SET LOCAL app.agent_id = 'agent-abc';
SET LOCAL app.tenant_id = 'tenant-xyz';
SET LOCAL app.tool_name = 'process_invoice';

-- Step 1: Read the invoice (SELECT does not lock here)
-- Step 2: Insert an approval request
INSERT INTO approval_requests(invoice_id, requested_by, status)
VALUES ($1, current_setting('app.agent_id'), 'pending');

-- Step 3: Log the agent action
INSERT INTO agent_audit_log(table_name, operation, agent_id, new_data, tool_name)
VALUES ('approval_requests', 'INSERT', current_setting('app.agent_id'),
        jsonb_build_object('invoice_id', $1, 'status', 'pending'),
        current_setting('app.tool_name'));

COMMIT;
-- If step 2 or 3 fails, NEITHER write persists
```

## Advanced view
```sql
-- blocked: Docker not accessible

-- SAVEPOINT for optional steps within a complex transaction
BEGIN;
SET LOCAL app.agent_id = 'agent-abc';

-- Mandatory step
INSERT INTO tasks(title, assignee_id, status)
VALUES ('Process Q4 invoices', $1, 'open')
RETURNING id INTO v_task_id;

-- Optional step: try to send a notification
SAVEPOINT before_notification;
BEGIN
  INSERT INTO notification_queue(task_id, channel, message)
  VALUES (v_task_id, 'slack', 'New task assigned');
EXCEPTION WHEN OTHERS THEN
  -- Notification failed — revert just this step, continue with the transaction
  ROLLBACK TO SAVEPOINT before_notification;
  -- Record that notification was skipped
  INSERT INTO task_events(task_id, event_type, notes)
  VALUES (v_task_id, 'notification_skipped', SQLERRM);
END;

-- Continue: mandatory audit
INSERT INTO agent_audit_log(table_name, operation, agent_id, new_data)
VALUES ('tasks', 'INSERT', current_setting('app.agent_id'),
        jsonb_build_object('task_id', v_task_id));

COMMIT;

-- Idempotency: insert only if not already exists
INSERT INTO tasks(id, title, assignee_id, status)
VALUES ($1, $2, $3, 'open')
ON CONFLICT (id) DO NOTHING;
-- Safe to retry — duplicate insert is silently skipped

-- Compensation: when a committed transaction has wrong outcomes
-- (This runs in a NEW transaction after the original committed)
INSERT INTO compensation_events(
  original_transaction_id,
  action_type,
  target_table,
  target_id,
  reason,
  compensating_action
) VALUES (
  $1, 'reverse_task_creation', 'tasks', v_task_id,
  'Downstream service rejected the task',
  jsonb_build_object('set_status', 'cancelled', 'reason', $2)
);
```

## Mental model
A transaction is a controlled experiment. You set up the conditions, run the experiment, and observe the result. If the result is wrong, you discard the entire experiment (ROLLBACK) and try again. SAVEPOINTs are intermediate checkpoints — like saving in a video game before trying a difficult section. Compensation events are the "undo" button for when the game has already saved in a bad state — you cannot undo the save, but you can apply a patch.

## PostgreSQL view
```sql
-- blocked: Docker not accessible

-- Handle serialization failures with retry logic
-- (Application code concept — shown as SQL pseudocode)

-- Transaction isolation levels for agent operations:
-- READ COMMITTED (default): safe for most reads, some phantom reads possible
-- REPEATABLE READ: consistent snapshot across multiple reads in one transaction
-- SERIALIZABLE: full isolation; may fail with serialization errors (40001)

-- For an agent that reads then writes based on what it read:
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- Agent reads the current state
SELECT status FROM invoices WHERE id = $1;
-- Agent decides based on this read
-- PostgreSQL guarantees this read value will not change during the transaction
UPDATE invoices SET status = 'processing' WHERE id = $1 AND status = 'pending';
-- If another transaction modified status between our read and write, this UPDATE
-- will see 0 rows (or raise serialization error at SERIALIZABLE level)
COMMIT;

-- lock_timeout prevents deadlocks from hanging indefinitely
SET LOCAL lock_timeout = '3s';
-- If a lock cannot be acquired in 3 seconds, statement fails with error
-- The application catches LockNotAvailable and retries or queues
```

## SQL view
The key SQL patterns for safe agent transactions:
- `BEGIN` / `COMMIT` / `ROLLBACK` for boundaries
- `SAVEPOINT name` / `ROLLBACK TO SAVEPOINT name` / `RELEASE SAVEPOINT name` for partial rollback
- `ON CONFLICT DO NOTHING` or `ON CONFLICT DO UPDATE` for idempotent inserts
- `SET LOCAL lock_timeout` / `SET LOCAL statement_timeout` for timeout safety
- `SELECT ... FOR UPDATE` for explicit row locking within a transaction

## Non-SQL or hybrid view
Application-level saga patterns (common in microservices) implement multi-step operations with explicit compensation steps. PostgreSQL stored procedures can implement the same pattern inside the database: each step is a SAVEPOINT, failure triggers ROLLBACK TO SAVEPOINT and compensation INSERT. The advantage over sagas: everything is ACID within one database connection.

## Design principle
**Idempotency by design.** Every agent write operation should be safe to retry. Use `ON CONFLICT DO NOTHING` for INSERTs; include a unique idempotency_key column. For UPDATE operations, include the expected current state in the WHERE clause (optimistic concurrency). If the operation has already been applied, the second call produces no change.

## Critical thinking
- **What if the transaction holds a lock for too long?** SET LOCAL lock_timeout = '5s' causes the transaction to abort rather than wait indefinitely. The agent retries with backoff.
- **What if the compensation event itself fails?** Insert the compensation event in a separate transaction from the error handler. If that also fails, escalate to an alert. The compensation event must be as simple as possible.
- **What if two agents try to process the same pending action?** SELECT FOR UPDATE SKIP LOCKED in the worker prevents this. One agent gets the lock; the other skips the row and tries the next.
- **What if retrying a non-idempotent operation creates duplicate records?** This is a design flaw. Every agent operation must be idempotent. Add a unique constraint on (agent_id, idempotency_key) and use ON CONFLICT handling.

## Creative thinking
Design a **transaction journal**: before executing a multi-step agent operation, INSERT a row into a transaction_journal table with status='started'. At COMMIT, UPDATE status to 'completed'. On failure, UPDATE to 'failed' with error details in a new transaction. Any 'started' rows older than 10 minutes are stale — an alerting job catches them and initiates compensation.

## Systems thinking
Safe agent transactions are the mechanism that ensures the database always transitions between valid states — never through invalid intermediate states. The transaction boundary is not a performance feature; it is a correctness guarantee. Without it, the database can contain partially-applied changes that violate business invariants in ways that are invisible until they cause downstream failures.

## MCP and agent perspective
From the MCP perspective, each tool invocation is one transaction. The tool function wraps its writes in BEGIN/COMMIT. If any write fails, the tool returns an error and the entire transaction rolls back. The agent receives the error, logs it to its episodic memory, and decides whether to retry (with exponential backoff) or escalate to a compensation workflow.

## Ontology perspective
A transaction is a **state transition event**: the database moves from pre-state to post-state atomically. SAVEPOINTs create nested state transitions. Rollback is a return to the pre-state. Compensation is a deliberate forward transition to a corrected state (not a rollback — committed data cannot be uncommitted, only corrected). These are distinct concepts in the ontology of database operations.

## Practice session
1. Write a five-step agent operation (two inserts, one update, one conditional insert, one audit insert) inside a single transaction with SET LOCAL timeouts.
2. Add a SAVEPOINT around the conditional insert. Write the exception handler that rolls back just the conditional insert and logs the failure.
3. Write an idempotent INSERT that uses ON CONFLICT to handle duplicate calls safely.
4. Design the compensation_events table schema and write the INSERT that records a failed outcome.
5. Write the query that finds all transactions that started but never completed (stale transaction journal entries).

## References
- PostgreSQL Transactions: https://www.postgresql.org/docs/16/tutorial-transactions.html
- PostgreSQL SAVEPOINT: https://www.postgresql.org/docs/16/sql-savepoint.html
- PostgreSQL Lock Timeout: https://www.postgresql.org/docs/16/runtime-config-client.html
- Idempotency patterns: https://www.postgresql.org/docs/16/sql-insert.html (ON CONFLICT)
- Saga pattern: https://microservices.io/patterns/data/saga.html
