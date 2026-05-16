# Ontology Notes — Practice 14: MCP Tool Database Design

This practice introduces three core concepts in the agent-database ontology:

---

## Concept Map

```
MCP Tool (narrow interface)
  │
  ├─► Tool Function (SECURITY DEFINER)
  │     └─► Parameterized Query → Documents table
  │                              └─► (RLS filters by tenant_id)
  │
  ├─► Audit Entry (mcp_tool_calls, INSERT-only)
  │     └─► Immutability Trigger prevents modification
  │
  └─► Approval Request (pending_approvals)
        └─► Human Reviewer
              └─► Background Worker (SKIP LOCKED)
                    └─► Executes the deferred action
```

---

## Key Concepts in This Practice

### Document State Machine
```
draft → review → published
                      ↓
                 archived (via pending_approvals only)
```

Status transitions are enforced by: CHECK constraint (valid values) + tool function logic (only valid transitions allowed).

### Audit Immutability
The `mcp_tool_calls` table models the **event sourcing** pattern: every action is an append-only event. The trigger that prevents modification models the **append-only log** invariant.

### Approval Workflow State Machine
```
pending → approved (human) → executed (worker)
       → rejected (human)
       → expired (scheduled job)
```

The state machine is enforced by: CHECK constraint (valid status values) + self-approval trigger + scheduled expiry job.

---

## Relationships to Other Ontologies

- **[[mcp-tool-ontology]]**: this practice implements the tool schema and side effect classification concepts
- **[[agent-workflow-ontology]]**: the pending_approvals table is an instance of the Approval concept
- **[[security-ontology]]**: INSERT-only audit, RLS isolation, SECURITY DEFINER boundary
- **[[transaction-ontology]]**: tool function wraps business write + audit write in one transaction

---

## Questions to Ponder

1. Is `mcp_tool_calls` an audit log or a memory table? (It is both — it is episodic memory AND an audit trail. In a real system, you might separate these.)

2. The `pending_approvals` table is both a queue (ordered by expires_at) and a state machine (status transitions). What are the implications of using a relational table for both purposes?

3. If you needed to partition `mcp_tool_calls` by month for storage management, would the immutability trigger still work on each partition? (Yes — triggers apply to all partitions of a partitioned table in PostgreSQL 16.)
