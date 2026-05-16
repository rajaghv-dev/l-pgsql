# Practice 15: Agent-Safe Actions

**Level**: Intermediate
**Stage**: 26 — MCP and Agent Database Foundations
**Focus**: Implement write-narrow agent actions with RLS-protected memory, audit triggers, and constraint-enforced safety

---

## What You Will Build

An agent memory and action system that demonstrates:

- A `agent_memory` table with RLS (each agent sees only its own rows)
- Safe INSERT patterns with audit logging
- Constraint-enforced rejection of unsafe operations
- Simulation of what happens when an agent attempts an unsafe operation

---

## Learning Goals

1. Write a safe INSERT that automatically triggers an audit log entry (same transaction)
2. Write a SELECT that respects RLS — agent A cannot see agent B's memory
3. Simulate constraint violations when an agent tries an unsafe operation
4. Design a soft-delete pattern as an alternative to hard DELETE
5. Understand the difference between permission denial (RLS) and constraint violation (CHECK)

---

## Prerequisites

- Practice 14: MCP Tool Database Design
- Concept 23: Agent-Safe Database Actions
- Concept 24: Agent Memory and Audit Trails

---

## Schema Overview

```
agent_memory
  id UUID PK
  agent_id TEXT NOT NULL
  memory_type TEXT CHECK (episodic|semantic|procedural)
  content TEXT NOT NULL
  metadata JSONB
  is_active BOOLEAN DEFAULT true
  created_at TIMESTAMPTZ
  expires_at TIMESTAMPTZ

agent_action_log (INSERT-ONLY audit)
  id UUID PK
  agent_id TEXT NOT NULL
  action_type TEXT NOT NULL
  target_table TEXT
  target_id UUID
  payload JSONB
  outcome TEXT CHECK (success|denied|constraint_violation|error)
  logged_at TIMESTAMPTZ

unsafe_attempt_log (INSERT-ONLY, records blocked operations)
  id UUID PK
  agent_id TEXT NOT NULL
  attempted_operation TEXT NOT NULL
  reason_blocked TEXT
  attempted_at TIMESTAMPTZ
```

---

## Files in This Folder

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `setup.sql` | Schema DDL with RLS, triggers, functions |
| `00-setup-validation.md` | Verification queries |
| `exercises.md` | Hands-on exercises |
| `solutions.md` | Reference solutions |
| `reflection.md` | Thinking prompts |
| `ontology-notes.md` | Concept connections |
| `troubleshooting.md` | Common errors |
| `references.md` | Documentation links |

---

## Key Scenarios

- Agent A inserts a memory → audit log entry created automatically
- Agent A tries to SELECT agent B's memory → RLS returns no rows
- Agent A tries to DELETE a memory row → permission denied (no DELETE grant)
- Agent A tries to INSERT a memory with a NULL agent_id → NOT NULL constraint fails
- Agent A tries to set memory_type = 'invalid' → CHECK constraint fails
