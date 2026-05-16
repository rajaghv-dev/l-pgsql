# Reflection — Practice 14: MCP Tool Database Design

Use these prompts after completing the exercises. Write your answers before reading the notes below each question.

---

## Conceptual Reflection

**1. The schema uses SECURITY DEFINER functions as the access boundary. What is the trade-off compared to granting the agent role direct table access?**

_Your answer:_

> Direct table access is simpler but gives the agent the ability to construct arbitrary queries — any SELECT, any WHERE clause, any column. SECURITY DEFINER functions restrict the agent to exactly the operations the function exposes. The trade-off is more function code to maintain, but the security boundary is explicit and auditable.

---

**2. The mcp_tool_calls table is INSERT-only. What happens to the audit log if the database itself crashes mid-INSERT?**

_Your answer:_

> PostgreSQL's WAL (Write-Ahead Log) ensures that even if the server crashes mid-INSERT, the transaction is either fully replayed or fully rolled back on recovery. There is no "partial INSERT" state. The audit entry and the business write (both in the same transaction) either both survive or both disappear — which is exactly what we want.

---

**3. Why is returning a JSONB error `{"error": "not_authorized"}` preferable to `RAISE EXCEPTION` in the submit_for_review function?**

_Your answer:_

> RAISE EXCEPTION causes the entire transaction to roll back — including any prior steps in the same transaction. A JSONB error return lets the calling code inspect the error, log it gracefully, and decide whether to retry with corrected parameters. For agent operations, a structured error is more useful than an exception stack trace.

---

## Design Reflection

**4. You need to add a tool that lets an agent "bulk assign" 50 documents to a new author. How would you design this tool, given the safety principles in this practice?**

_Consider: is this read-only or write-wide? Does it need human approval? What does the audit trail look like?_

> This is a write-wide operation (affects many rows) and potentially irreversible. It should route through pending_approvals with action_type='bulk_assign'. The payload would include the document IDs and the new author. A human reviews the list before the background worker executes. The audit trail records: one pending_approval INSERT (agent action), one pending_approval UPDATE (human decision), and one mcp_tool_calls entry per batch execution.

---

**5. A new requirement: agents should be able to "like" documents (a lightweight, low-risk operation). How does this change the design? Do you need pending_approvals?**

> "Like" is reversible, low-risk, and affects only one row. It does not need pending_approvals — it executes directly. It still needs an audit entry in mcp_tool_calls. The tool function is `mcp_like_document(doc_id, agent_id, tenant_id)` which INSERTs into a `document_likes` table and logs the call. No approval workflow needed.

---

## Systems Reflection

**6. The self-approval trigger prevents an agent from approving its own requests. What organizational process does this mirror?**

> It mirrors the "four-eyes principle" or "dual control" in financial and compliance settings: no single person (or agent) can both initiate and authorize a transaction. The database trigger enforces this structurally, just as job separation policies enforce it in organizations.

---

**7. If you were building a dashboard for human reviewers of pending_approvals, what information would you display for each pending action, and in what order?**

> Priority order: (1) expires_at — soonest to expire first; (2) action_type — archive/delete are more urgent than publish; (3) requested_by — who is the agent; (4) payload summary — what will happen; (5) requested_at — how long has it been waiting. The dashboard polls or LISTENs on the NOTIFY channel so new items appear in real time.
