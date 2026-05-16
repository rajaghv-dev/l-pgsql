# Ontology Notes — Practice 15: Agent-Safe Actions

---

## Core Concept Map

```
Agent Action
  │
  ├─ Safe (allowed)
  │    ├─ INSERT via agent_remember() → RLS checks agent_id ownership
  │    │    └─► audit_agent_memory trigger fires → agent_action_log INSERT
  │    ├─ SELECT via agent_recall() → RLS filters to own rows
  │    └─ Soft-delete via agent_forget() → UPDATE is_active=false
  │         └─► audit_agent_memory trigger fires → agent_action_log INSERT
  │
  └─ Unsafe (blocked)
       ├─ Hard DELETE → permission denied (no GRANT)
       ├─ UPDATE audit log → immutability trigger raises exception
       ├─ Invalid CHECK value → constraint violation
       └─ Cross-agent SELECT → RLS returns 0 rows (invisible)
```

---

## Safety Layers

Each unsafe operation is blocked by a different mechanism:

| Unsafe operation | Blocking mechanism |
|-----------------|-------------------|
| Direct DELETE | Missing GRANT (role has no DELETE privilege) |
| Modifying audit log | Immutability trigger (BEFORE UPDATE/DELETE) |
| Invalid memory_type | CHECK constraint |
| Empty content | CHECK constraint |
| Cross-agent SELECT | RLS policy (appends agent_id predicate) |
| NULL agent_id | CHECK constraint (length > 0) |

This layered approach is defense-in-depth: removing any one layer does not make the system completely unsafe — the other layers still apply.

---

## Relationships to Ontology Files

- **[[agent-workflow-ontology]]**: `agent_action_log` is the Audit concept; soft-delete is the Compensation concept applied to memory
- **[[security-ontology]]**: layered safety (permission + constraint + trigger); defense-in-depth
- **[[mcp-tool-ontology]]**: `agent_remember`, `agent_recall`, `agent_forget` are narrow tool functions with typed inputs
- **[[ai-agent-memory-ontology]]**: the three memory types (episodic, semantic, procedural) implemented as rows in `agent_memory`

---

## Key Insight: RLS Is Structural, Not Behavioral

An agent cannot "try harder" to bypass RLS. It cannot rewrite the RLS predicate. It cannot set `app.agent_id` to another agent's ID (the session variable is set by the tool function, and the tool validates the input matches the caller's identity). The safety is structural — it is part of the database's query execution, not part of the agent's behavior.

This is the fundamental difference between structural safety (enforced by the database) and behavioral safety (relying on the agent to behave correctly). Structural safety holds even if the agent malfunctions, is compromised, or produces unexpected outputs.
