# Setup Validation — Practice 15

> All SQL is `-- blocked: Docker not accessible`.

---

## Checks to Run After setup.sql

### 1. Tables and constraints

```sql
-- blocked: Docker not accessible
\d agent_memory
-- Expect: agent_id NOT NULL with CHECK, memory_type CHECK constraint, expires_at CHECK

SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'agent_memory'::regclass;
```

---

### 2. RLS enabled on all tables

```sql
-- blocked: Docker not accessible
SELECT tablename, rowsecurity, forcerowsecurity
FROM pg_tables
WHERE tablename IN ('agent_memory','agent_action_log','unsafe_attempt_log');
-- Expect: rowsecurity=true, forcerowsecurity=true for all three
```

---

### 3. Audit trigger fires on INSERT

```sql
-- blocked: Docker not accessible
-- Set context and insert a memory
SET LOCAL app.agent_id = 'agent-test';
SELECT agent_remember('agent-test', 'episodic', 'Test memory content');

-- Check that audit entry was created
SELECT agent_id, action_type, target_table, outcome
FROM agent_action_log
WHERE agent_id = 'agent-test'
ORDER BY logged_at DESC
LIMIT 1;
-- Expect: agent_id='agent-test', action_type='INSERT', outcome='success'
```

---

### 4. RLS blocks cross-agent access

```sql
-- blocked: Docker not accessible
-- Insert memory as agent-A
SET LOCAL app.agent_id = 'agent-A';
SELECT agent_remember('agent-A', 'episodic', 'Agent A secret memory');

-- Switch context to agent-B, try to read
SET LOCAL app.agent_id = 'agent-B';
SELECT agent_recall('agent-B');
-- Expect: [] (empty array — agent-B's own memories, not agent-A's)

-- Direct table query as agent-B should also return no rows from agent-A:
SELECT * FROM agent_memory WHERE agent_id = 'agent-A';
-- Expect: 0 rows (RLS filters to agent-B's rows only)
```

---

### 5. Action log is immutable

```sql
-- blocked: Docker not accessible
-- Try to update a log entry
UPDATE agent_action_log SET outcome = 'success' WHERE id = '...';
-- Expect: ERROR: agent_action_log is INSERT-only. Operation UPDATE is not permitted.

-- Try to delete
DELETE FROM agent_action_log WHERE id = '...';
-- Expect: same error
```

---

### 6. Soft-delete works; hard DELETE is blocked

```sql
-- blocked: Docker not accessible
-- agent role cannot directly DELETE from agent_memory:
SET LOCAL app.agent_id = 'agent-test';
DELETE FROM agent_memory WHERE agent_id = 'agent-test';
-- Expect: ERROR: permission denied for table agent_memory
-- (No DELETE grant on the table; agent_forget uses UPDATE is_active=false)

-- Soft-delete via function:
SELECT agent_forget('agent-test', 'memory-uuid-here');
-- Expect: {"memory_id": "...", "status": "deactivated"}
```

---

### 7. Constraint violations are caught at the database level

```sql
-- blocked: Docker not accessible
-- Invalid memory_type
INSERT INTO agent_memory(agent_id, memory_type, content)
VALUES ('agent-1', 'invalid_type', 'content');
-- Expect: ERROR: new row for relation "agent_memory" violates check constraint

-- Empty agent_id
INSERT INTO agent_memory(agent_id, memory_type, content)
VALUES ('', 'episodic', 'content');
-- Expect: ERROR: new row for relation "agent_memory" violates check constraint

-- expires_at before created_at is conceptually validated, but since created_at defaults to now()
-- and expires_at CHECK is (expires_at > created_at), set both explicitly:
INSERT INTO agent_memory(agent_id, memory_type, content, created_at, expires_at)
VALUES ('agent-1', 'episodic', 'content', now(), now() - INTERVAL '1 hour');
-- Expect: ERROR: new row for relation "agent_memory" violates check constraint
```
