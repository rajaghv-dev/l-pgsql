# Agent Workflow Ontology

> This ontology maps the core concepts of AI agent workflows backed by PostgreSQL.
> Use [[wikilink]] format to navigate between related ontology files.

---

## Core Concepts

### Agent
An autonomous or semi-autonomous software process that uses MCP tools to interact with a database. An agent has an identity (agent_id), belongs to a tenant (tenant_id), and operates within a defined permission boundary.

- Related: [[mcp-tool-ontology]], [[agent-permission-ontology]]
- PostgreSQL representation: `agent_id TEXT` stored in current_setting('app.agent_id')

### Tool
A named, typed MCP interface that the agent invokes. Each tool corresponds to exactly one database operation or function. Tools are the only way agents interact with the database.

- Related: [[mcp-tool-ontology]]
- Constraint: one tool = one operation; no raw SQL exposure

### Action
A single execution of a tool by an agent. Actions are immutable events — they happened, they are recorded, they cannot be undone (only compensated).

- Stored in: `mcp_tool_calls`, `agent_audit_log`
- Related: [[security-ontology]]

### Memory
What the agent knows and can recall. Memory has three types:

| Type | What it stores | Retrieval method |
|------|---------------|-----------------|
| Episodic | Past events with timestamps | FTS, date range |
| Semantic | General knowledge as embeddings | pgvector similarity |
| Procedural | Step-by-step how-to knowledge | Ordered rows |

- Related: [[ai-agent-memory-ontology]]
- Protection: RLS by agent_id; INSERT-only audit on all memory writes

### Audit
The immutable record of all agent actions. Every write to any agent-controlled table triggers an INSERT into the audit log. The audit log is INSERT-only (trigger rejects UPDATE and DELETE).

- Table: `agent_audit_log`
- Related: [[security-ontology]]
- Key fields: `agent_id`, `table_name`, `operation`, `old_data JSONB`, `new_data JSONB`, `changed_at`

### Approval
The human-in-the-loop gateway for high-risk agent actions. Agents submit pending_actions; humans approve or reject them; background workers execute approved actions.

- Table: `pending_actions`
- Status machine: `pending → approved → executed` or `pending → rejected`, `pending → expired`
- Related: [[human-approval-ontology]]

### Rollback
The automatic reversal of all uncommitted writes in a failed transaction. An agent's multi-step operation either fully commits or fully rolls back — there are no partial outcomes.

- Mechanism: PostgreSQL transaction atomicity (ACID)
- Related: [[transaction-ontology]]

### Compensation
A forward-moving correction for a committed transaction whose outcome must be reversed. Unlike rollback (which reverts uncommitted data), compensation inserts a new event that triggers corrective action.

- Table: `compensation_events`
- Pattern: event-sourcing — compensation is a new event, not a modification of history

---

## Relationships

```
Agent
  └─ invokes ──────────────► Tool
                               └─ executes ─────► Action
                               └─ reads/writes ──► Memory
                               └─ submits ───────► Approval (pending_action)

Action
  └─ recorded in ──────────► Audit
  └─ may trigger ──────────► Approval (if high-risk)
  └─ may require ──────────► Rollback (if transaction fails)
  └─ may trigger ──────────► Compensation (if committed but wrong)

Approval
  └─ reviewed by ──────────► Human
  └─ executed by ──────────► Background Worker
  └─ times out as ─────────► Expired (automatic)
```

---

## Wikilinks

- [[ai-agent-memory-ontology]] — episodic, semantic, procedural memory; pgvector; FTS
- [[security-ontology]] — RLS, permission boundaries, least privilege, BYPASSRLS risk
- [[mcp-tool-ontology]] — tool schema, input validation, output schema, side effects
- [[human-approval-ontology]] — pending_action state machine, reviewer, NOTIFY/LISTEN
- [[transaction-ontology]] — ACID, MVCC, SAVEPOINT, compensation, idempotency

---

## Key Invariants

1. An agent cannot read or modify another agent's memory (RLS by agent_id)
2. An agent cannot delete audit log entries (immutability trigger)
3. An agent cannot approve its own pending actions (self-approval trigger)
4. An agent role has no BYPASSRLS, no superuser, no DDL privileges
5. All agent writes are wrapped in transactions (atomicity)
6. Every write to any agent-controlled table produces an audit entry
