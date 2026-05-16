# Reflection — Practice 15: Agent-Safe Actions

---

## After the Exercises

**1. Why does RLS filter `WHERE agent_id = 'agent-A'` even when the query explicitly asks for `agent_A`'s rows?**

_Your answer:_

> RLS appends its predicate (agent_id = current_setting('app.agent_id')) to the WHERE clause. If current_setting('app.agent_id') is 'agent-B', the effective WHERE is: `agent_id = 'agent-A' AND agent_id = 'agent-B'`. This is always false — the user's WHERE clause and the RLS predicate are ANDed, and the user's clause cannot override RLS.

---

**2. Why is soft-delete (`is_active = false`) safer than hard DELETE for agent memory?**

_Your answer:_

> Hard DELETE removes the row permanently — there is no audit trail of what the agent "forgot". Soft-delete leaves the row in place (invisible to `agent_recall`) but readable by human administrators. The audit trigger captures the UPDATE. This means human reviewers can see the full history of what an agent knew and when it "forgot" it, which is important for compliance and debugging.

---

**3. The audit trigger fires AFTER INSERT. What happens if the INSERT succeeds but the audit trigger fails (e.g., due to a constraint violation on `agent_action_log`)?**

_Your answer:_

> If the AFTER trigger fails, the entire transaction is rolled back — including the INSERT that triggered it. PostgreSQL treats trigger failures as statement failures. This is the correct behavior: we never want a committed INSERT without an audit entry. The two events are atomic: they both succeed or both fail.

---

**4. An agent calls `agent_forget('agent-alpha', 'memory-uuid-of-agent-beta')`. What happens, and why?**

_Your answer:_

> The function executes: `UPDATE agent_memory SET is_active = false WHERE id = 'memory-uuid' AND agent_id = 'agent-alpha'`. Since the memory belongs to agent-beta (different agent_id), the WHERE clause matches 0 rows. `GET DIAGNOSTICS v_rows = ROW_COUNT` returns 0, and the function returns `{"error": "memory_not_found_or_not_owned"}`. Agent-alpha cannot soft-delete agent-beta's memory — the ownership check is in the WHERE clause, and RLS additionally ensures the row is not visible to agent-alpha.

---

**5. Design question: Should the `agent_action_log` be readable by the agent, or only by human administrators?**

_Think about this before reading the note:_

> This depends on the use case. In this schema, agents can read their own log entries (SELECT RLS policy is `agent_id = current_setting('app.agent_id')`). An agent can use its own log to understand what it has done ("what did I last write to agent_memory?"). If agents should not have any visibility into the audit log (fully opaque), remove the SELECT policy and grant SELECT only to human administrator roles. The trade-off: agent visibility enables self-monitoring; opacity enforces separation between actor and witness.
