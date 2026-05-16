# Troubleshooting — Practice 15: Agent-Safe Actions

> All SQL is `-- blocked: Docker not accessible`.

---

## Error: `permission denied for table agent_memory`

**Cause**: Calling direct SQL on the table without going through the tool functions.

**Fix**: Use the SECURITY DEFINER functions (`agent_remember`, `agent_recall`, `agent_forget`). The agent role has no direct table grants.

---

## Error: `new row violates row-level security policy`

**Cause**: `app.agent_id` not set, or set to a different value than the `agent_id` being inserted.

**Fix**: Ensure `set_config('app.agent_id', p_agent_id, true)` is called before the INSERT, and the `agent_id` column matches the configured value.

```sql
-- blocked: Docker not accessible
-- The tool functions call this internally, but if testing directly:
SET LOCAL app.agent_id = 'agent-alpha';
INSERT INTO agent_memory(agent_id, memory_type, content)
VALUES ('agent-alpha', 'episodic', 'Test'); -- agent_id must match app.agent_id
```

---

## `agent_recall` returns `[]` but memories were inserted

**Possible causes**:
1. Memories were inserted with a different `agent_id` than what `agent_recall` was called with
2. Memories have `is_active = false` (soft-deleted)
3. Memories have `expires_at < now()` (expired)
4. `app.agent_id` is not set correctly during the recall query

**Diagnose**:
```sql
-- blocked: Docker not accessible
-- Check raw table contents (bypassing is_active filter):
SET LOCAL app.agent_id = 'agent-alpha';
SELECT id, agent_id, memory_type, is_active, expires_at, created_at
FROM agent_memory
WHERE agent_id = 'agent-alpha';
```

---

## Error: `agent_action_log is INSERT-only. Operation UPDATE is not permitted.`

**Cause**: Code attempted to UPDATE or DELETE a row in `agent_action_log`.

**Fix**: This is expected behavior — the log is immutable. If you need to record a correction, INSERT a new row with `action_type = 'correction'` and reference the original log entry in the payload.

---

## Trigger `audit_agent_memory` not firing

**Check**: Verify the trigger exists and is enabled:
```sql
-- blocked: Docker not accessible
SELECT tgname, tgenabled, tgtype
FROM pg_trigger
WHERE tgrelid = 'agent_memory'::regclass;
-- Expect: audit_agent_memory present, tgenabled = 'O'
```

If the trigger exists but is not firing: verify you are doing an INSERT or UPDATE (not a COPY or bulk load that bypasses triggers — though COPY still fires row-level triggers in PostgreSQL 16).

---

## `agent_forget` returns `{"error": "memory_not_found_or_not_owned"}`

**Cause**: Either the memory UUID does not exist, or it belongs to a different agent_id.

**Diagnose**:
```sql
-- blocked: Docker not accessible
-- Check if the memory exists and who owns it:
SELECT id, agent_id, is_active FROM agent_memory WHERE id = 'memory-uuid-here';
-- If agent_id does not match the calling agent, agent_forget will return not_found.
```

---

## CHECK constraint error on `expires_at`

The constraint is: `expires_at > created_at`. Since `created_at` defaults to `now()`, an `expires_at` that is in the past relative to insertion time will violate the constraint.

**Fix**: Set `expires_at` to a future timestamp:
```sql
-- blocked: Docker not accessible
INSERT INTO agent_memory(agent_id, memory_type, content, expires_at)
VALUES ('agent-1', 'episodic', 'Temp memory', now() + INTERVAL '7 days');
```
