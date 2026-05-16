# MCP Tool Ontology

> This ontology maps the structure, behavior, and safety properties of MCP tools backed by PostgreSQL.
> Use [[wikilink]] format to navigate between related ontology files.

---

## Core Concepts

### MCP Tool
A named, typed interface through which an AI agent interacts with a system. From the agent's perspective, a tool is a black box: it accepts typed inputs and returns typed outputs. From the database's perspective, a tool is a function with a fixed SQL operation.

- Related: [[agent-workflow-ontology]]
- Properties: name, input_schema, output_schema, side_effect_type

### Tool Schema
The JSON Schema definition of a tool's inputs and outputs. The tool schema is the contract between the agent and the database. Inputs that do not match the schema are rejected before any database operation runs.

- Format: JSON Schema (type, format, minimum, maximum, enum, required)
- Enforcement: application layer validates before calling PostgreSQL
- Related: [[security-ontology]]

### Input Validation
The process of verifying that every tool input matches the tool schema before any database interaction. Input validation prevents injection attacks, type errors, and out-of-range values.

- Location: application layer (before SQL)
- Rules: type check → range check → format check → business rule check
- Example: `invoice_amount NUMERIC` must be > 0 and < 1,000,000

### Output Schema
The typed structure returned by the tool. The output schema hides database internals — the agent sees field names defined by the tool contract, not database column names.

- Purpose: prevents the agent from learning database structure
- Design: return only the minimum fields needed for the agent's next decision

### Side Effect
The database mutation produced by a tool call. Side effects are classified:

| Class | Effect | Examples |
|-------|--------|---------|
| read-only | SELECT only; no writes | get_document, list_tasks |
| write-narrow | one INSERT to a specific table | log_read, submit_approval |
| write-wide | multiple writes across tables | execute_workflow (avoid) |
| destructive | UPDATE/DELETE/DDL | archive_record (human-approval required) |

### Permission Boundary
The set of database privileges and RLS policies that define what a tool (and by extension, an agent using that tool) can do. The permission boundary is enforced by the database, not by the tool's code.

- Components: role grants, RLS policies, function SECURITY DEFINER
- Related: [[agent-permission-ontology]]

### Audit Event
The row inserted into `agent_audit_log` by the trigger that fires on every tool-generated write. An audit event records: who (agent_id), what (tool_name, operation, table_name), when (changed_at), and the data (old_data, new_data JSONB).

- Related: [[agent-workflow-ontology]], [[security-ontology]]
- Immutability: audit events cannot be updated or deleted

### Human Approval Trigger
The condition under which a tool routes its operation through the pending_actions approval workflow instead of executing immediately. High-risk tools always trigger human approval.

- Criteria: operation is irreversible, amount exceeds threshold, data is sensitive, action affects many rows
- Related: [[human-approval-ontology]]

---

## Tool Classification

```
Tools
├── Read tools (safe to execute directly)
│   ├── get_document(id)
│   ├── list_pending_invoices()
│   └── find_similar_records(embedding)
│
├── Write-narrow tools (safe with audit trigger)
│   ├── log_access(record_id, purpose)
│   ├── create_draft(title, content)
│   └── submit_approval_request(invoice_id, reason)
│
└── Write-wide / Destructive tools (require human approval)
    ├── archive_document(id, reason)      → pending_actions
    ├── bulk_update_status(ids, status)   → pending_actions
    └── close_high_priority_task(id)      → pending_actions
```

---

## Tool Execution Flow

```
Agent calls tool
  │
  ▼
Input validation (application layer)
  │  fails → return error, log attempt
  ▼
Set session context
  SET LOCAL app.agent_id = '...'
  SET LOCAL app.tenant_id = '...'
  SET LOCAL app.tool_name = 'tool_name'
  │
  ▼
Begin transaction
  │
  ▼
Execute parameterized query / SECURITY DEFINER function
  │  RLS filters rows automatically
  │  CHECK constraints validate values
  │  Audit trigger fires on writes
  ▼
Commit transaction
  │  fails → automatic ROLLBACK
  ▼
Return typed output to agent
```

---

## Wikilinks

- [[agent-workflow-ontology]] — agent, action, memory, audit, approval, rollback
- [[agent-permission-ontology]] — agent_role, RLS policy, BYPASSRLS, least privilege
- [[security-ontology]] — injection prevention, parameterized queries, audit immutability
- [[human-approval-ontology]] — pending_action, reviewer, approval state machine

---

## Key Invariants

1. A tool never exposes raw SQL to the agent
2. A tool validates all inputs before any database call
3. A tool sets session context before every query
4. Every tool write produces an audit event in the same transaction
5. A tool that can fail irreversibly routes through pending_actions
6. Tool input and output schemas are immutable contracts — changes require versioning
