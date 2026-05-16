# Exercises — Practice 15: Agent-Safe Actions

> All SQL is `-- blocked: Docker not accessible`.

---

## Exercise 1: Safe INSERT with Automatic Audit

Write a sequence of SQL statements (within one transaction) that:
1. Sets the agent context for agent 'agent-alpha'
2. Calls `agent_remember` to store an episodic memory
3. Verifies the audit entry was created automatically

```sql
-- blocked: Docker not accessible
BEGIN;
SET LOCAL app.agent_id = 'agent-alpha';

-- Your code here: call agent_remember(...)

-- Verify audit entry
SELECT agent_id, action_type, outcome, logged_at
FROM agent_action_log
ORDER BY logged_at DESC
LIMIT 1;

COMMIT;
```

---

## Exercise 2: RLS Isolation — Cannot See Other Agent's Memory

Simulate two agents interacting with the memory table:

```sql
-- blocked: Docker not accessible
-- Step 1: Agent-A stores a memory
BEGIN;
SET LOCAL app.agent_id = 'agent-A';
SELECT agent_remember('agent-A', 'procedural', 'How to process invoices: verify, then submit');
COMMIT;

-- Step 2: Agent-B tries to access Agent-A's memories
BEGIN;
SET LOCAL app.agent_id = 'agent-B';

-- Via the recall function (should return [] because agent-B has no memories)
SELECT agent_recall('agent-B');

-- Via direct table query (should return 0 rows for agent-A, filtered by RLS)
SELECT * FROM agent_memory WHERE agent_id = 'agent-A';
-- Predict: how many rows will be returned?

COMMIT;
```

Write your prediction for each query's result and explain why.

---

## Exercise 3: Simulate Unsafe Operations

For each operation below, predict whether it will succeed, fail with a permission error, or fail with a constraint error — and explain why:

**A**: Agent tries hard DELETE:
```sql
-- blocked: Docker not accessible
SET LOCAL app.agent_id = 'agent-alpha';
DELETE FROM agent_memory WHERE agent_id = 'agent-alpha' AND id = 'some-uuid';
```

**B**: Agent tries to modify the audit log:
```sql
-- blocked: Docker not accessible
UPDATE agent_action_log SET outcome = 'success' WHERE agent_id = 'agent-alpha';
```

**C**: Agent tries to INSERT a memory with an invalid type:
```sql
-- blocked: Docker not accessible
SET LOCAL app.agent_id = 'agent-alpha';
INSERT INTO agent_memory(agent_id, memory_type, content)
VALUES ('agent-alpha', 'hallucination', 'I know everything');
```

**D**: Agent tries to INSERT a memory with empty content:
```sql
-- blocked: Docker not accessible
SET LOCAL app.agent_id = 'agent-alpha';
INSERT INTO agent_memory(agent_id, memory_type, content)
VALUES ('agent-alpha', 'episodic', '');
```

---

## Exercise 4: Write the Soft-Delete Pattern

Instead of hard DELETE, the system uses `is_active = false`. Write queries that:

1. Soft-delete a specific memory using the `agent_forget` function
2. Count how many active vs. inactive memories agent-alpha has
3. Show that soft-deleted memories are excluded from `agent_recall` results

```sql
-- blocked: Docker not accessible
-- 1. Soft-delete
SELECT agent_forget('agent-alpha', 'memory-uuid-here');

-- 2. Count active vs. inactive
SELECT
  is_active,
  count(*) AS count
FROM agent_memory
WHERE agent_id = 'agent-alpha'
-- Add your conditions and GROUP BY here

-- 3. Verify agent_recall excludes inactive
SELECT agent_recall('agent-alpha');
-- How would you verify a specific memory is excluded?
```

---

## Exercise 5: Add Procedural Memory Tool

Write a new function `agent_learn_procedure(p_agent_id TEXT, p_procedure TEXT, p_steps JSONB)` that:
- Validates inputs (non-empty procedure name, steps must be a JSON array)
- Inserts into `agent_memory` with `memory_type = 'procedural'`
- Stores the steps array in `metadata`
- Returns the memory ID

```sql
-- blocked: Docker not accessible
CREATE OR REPLACE FUNCTION agent_learn_procedure(
  p_agent_id  TEXT,
  p_procedure TEXT,
  p_steps     JSONB
) RETURNS JSONB
SECURITY DEFINER LANGUAGE plpgsql AS $$
BEGIN
  -- Your validation and INSERT here
END;
$$;
```

---

## Exercise 6: Query the Audit Log

Write queries that answer:

1. How many successful INSERTs has agent-alpha made to `agent_memory`?
2. What was the most recent action by any agent in the last hour?
3. Are there any 'denied' or 'constraint_violation' outcomes in the last 24 hours?

```sql
-- blocked: Docker not accessible
-- Your queries here
```

---

## Exercise 7: Design a Memory Expiry Job

Write the SQL for a maintenance job that:
1. Marks expired memories as inactive (`is_active = false`)
2. Archives memories that are both inactive AND older than 30 days

```sql
-- blocked: Docker not accessible
-- Step 1: Mark expired as inactive
UPDATE agent_memory
SET is_active = false
WHERE -- Your conditions here

-- Step 2: Archive old inactive memories
-- (Assume an agent_memory_archive table exists with the same schema)
INSERT INTO agent_memory_archive
SELECT * FROM agent_memory
WHERE -- Your conditions here

DELETE FROM agent_memory
WHERE -- Your conditions here
```
