# Solutions — Practice 15: Agent-Safe Actions

> All SQL is `-- blocked: Docker not accessible`.

---

## Exercise 1: Safe INSERT with Automatic Audit

```sql
-- blocked: Docker not accessible
BEGIN;
SET LOCAL app.agent_id = 'agent-alpha';

SELECT agent_remember(
  'agent-alpha',
  'episodic',
  'Processed invoice INV-2024-001 successfully',
  '{"invoice_id": "INV-2024-001", "amount": 5000}'::JSONB
);
-- Returns: {"memory_id": "...", "status": "stored"}

-- The audit_agent_memory trigger fires automatically on the INSERT.
-- Verify:
SELECT agent_id, action_type, target_table, outcome, logged_at
FROM agent_action_log
WHERE agent_id = 'agent-alpha'
ORDER BY logged_at DESC
LIMIT 1;
-- Returns: agent_id=agent-alpha, action_type=INSERT, target_table=agent_memory, outcome=success

COMMIT;
```

Key insight: The audit entry is created by a trigger, not by the function explicitly inserting it. This means the audit always fires on any INSERT to `agent_memory`, regardless of which code path triggered the INSERT.

---

## Exercise 2: RLS Isolation

```sql
-- blocked: Docker not accessible
-- Agent-A stores memory (already done)

-- Agent-B queries:
BEGIN;
SET LOCAL app.agent_id = 'agent-B';

SELECT agent_recall('agent-B');
-- Returns: [] — Agent-B has stored no memories yet. The function filters by agent_id='agent-B'.

SELECT * FROM agent_memory WHERE agent_id = 'agent-A';
-- Returns: 0 rows

COMMIT;
```

**Why 0 rows for the direct query?** The RLS policy `memory_own_agent` appends `agent_id = current_setting('app.agent_id', true)` to the query. Since `app.agent_id = 'agent-B'`, the effective WHERE is `agent_id = 'agent-A' AND agent_id = 'agent-B'` — which matches nothing. Agent-A's row is invisible to Agent-B.

Important: the direct query `WHERE agent_id = 'agent-A'` does NOT override RLS. RLS is ANDed with the user's WHERE clause, not replaced by it.

---

## Exercise 3: Unsafe Operations

**A: Hard DELETE**
```
ERROR: permission denied for table agent_memory
```
The `agent_write_role` has no GRANT DELETE on `agent_memory`. The agent can only UPDATE (via `agent_forget`) and INSERT (via `agent_remember`) — both through SECURITY DEFINER functions. Direct table access is denied.

**B: Modify the audit log**
```
ERROR: agent_action_log is INSERT-only. Operation UPDATE is not permitted.
```
The `enforce_log_immutability` trigger fires BEFORE the UPDATE and raises an exception, rolling back the entire statement.

**C: Invalid memory_type**
```
ERROR: new row for relation "agent_memory" violates check constraint "agent_memory_memory_type_check"
```
The CHECK constraint `memory_type IN ('episodic','semantic','procedural')` rejects 'hallucination'. This fires at the database level regardless of which code path triggered the INSERT.

**D: Empty content**
```
ERROR: new row for relation "agent_memory" violates check constraint "agent_memory_content_check"
```
The CHECK constraint `length(content) > 0` rejects empty strings. An empty string is not the same as NULL — this CHECK specifically catches empty strings.

---

## Exercise 4: Soft-Delete Pattern

```sql
-- blocked: Docker not accessible

-- 1. Soft-delete via function
SELECT agent_forget('agent-alpha', 'memory-uuid-here');
-- Returns: {"memory_id": "...", "status": "deactivated"}

-- 2. Count active vs. inactive
SELECT
  is_active,
  count(*) AS count
FROM agent_memory
WHERE agent_id = 'agent-alpha'
GROUP BY is_active
ORDER BY is_active DESC;
-- Returns something like:
-- is_active | count
-- ----------+------
-- true      |   5
-- false     |   1

-- 3. Verify agent_recall excludes inactive
-- agent_recall uses WHERE is_active = true, so deactivated memories do not appear.
-- To confirm a specific memory is excluded:
SELECT id, is_active FROM agent_memory
WHERE id = 'memory-uuid-here' AND agent_id = 'agent-alpha';
-- Returns: is_active = false

SELECT * FROM agent_recall('agent-alpha')
-- No row with id = 'memory-uuid-here' should appear
```

---

## Exercise 5: agent_learn_procedure

```sql
-- blocked: Docker not accessible
CREATE OR REPLACE FUNCTION agent_learn_procedure(
  p_agent_id  TEXT,
  p_procedure TEXT,
  p_steps     JSONB
) RETURNS JSONB
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_mem_id UUID;
BEGIN
  IF p_agent_id IS NULL OR length(p_agent_id) = 0 THEN
    RAISE EXCEPTION 'agent_id must not be empty';
  END IF;
  IF p_procedure IS NULL OR length(p_procedure) = 0 THEN
    RAISE EXCEPTION 'procedure name must not be empty';
  END IF;
  IF p_steps IS NULL OR jsonb_typeof(p_steps) != 'array' THEN
    RAISE EXCEPTION 'steps must be a JSON array';
  END IF;
  IF jsonb_array_length(p_steps) = 0 THEN
    RAISE EXCEPTION 'steps array must not be empty';
  END IF;

  PERFORM set_config('app.agent_id', p_agent_id, true);
  PERFORM set_config('app.tool_name', 'learn_procedure', true);

  INSERT INTO agent_memory(agent_id, memory_type, content, metadata)
  VALUES (
    p_agent_id,
    'procedural',
    p_procedure,
    jsonb_build_object('steps', p_steps, 'step_count', jsonb_array_length(p_steps))
  )
  RETURNING id INTO v_mem_id;

  RETURN jsonb_build_object(
    'memory_id', v_mem_id,
    'procedure', p_procedure,
    'step_count', jsonb_array_length(p_steps)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION agent_learn_procedure TO agent_write_role;
```

---

## Exercise 6: Audit Log Queries

```sql
-- blocked: Docker not accessible

-- 1. Count successful INSERTs by agent-alpha
SELECT count(*) AS successful_inserts
FROM agent_action_log
WHERE agent_id = 'agent-alpha'
  AND action_type = 'INSERT'
  AND outcome = 'success';

-- 2. Most recent action by any agent in the last hour
SELECT agent_id, action_type, target_table, outcome, logged_at
FROM agent_action_log
WHERE logged_at > now() - INTERVAL '1 hour'
ORDER BY logged_at DESC
LIMIT 10;

-- 3. Any denied or constraint_violation outcomes in the last 24 hours
SELECT agent_id, action_type, outcome, error_detail, logged_at
FROM agent_action_log
WHERE outcome IN ('denied','constraint_violation')
  AND logged_at > now() - INTERVAL '24 hours'
ORDER BY logged_at DESC;
```

---

## Exercise 7: Memory Expiry Job

```sql
-- blocked: Docker not accessible

BEGIN;

-- Step 1: Mark expired memories as inactive
-- (An "expired" memory has an expires_at that has passed)
UPDATE agent_memory
SET is_active = false
WHERE is_active = true
  AND expires_at IS NOT NULL
  AND expires_at < now();

-- Step 2: Archive old inactive memories (30+ days old)
-- (Run as a privileged maintenance role, not the agent role)
INSERT INTO agent_memory_archive
SELECT * FROM agent_memory
WHERE is_active = false
  AND created_at < now() - INTERVAL '30 days';

-- Remove archived rows from the live table
DELETE FROM agent_memory
WHERE is_active = false
  AND created_at < now() - INTERVAL '30 days'
  AND id IN (
    SELECT id FROM agent_memory_archive
    WHERE created_at < now() - INTERVAL '30 days'
  );

COMMIT;
```

Note: The DELETE in step 2 is performed by a maintenance role (not the agent role), which has DELETE privileges. The agent role itself still cannot DELETE from `agent_memory`.
