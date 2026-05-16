# Practice 14: MCP Tool Database Design

**Level**: Intermediate
**Stage**: 26 — MCP and Agent Database Foundations
**Focus**: Design and implement a PostgreSQL backend for an MCP tool-driven document management system

---

## What You Will Build

A document management system backend designed to be safely operated by AI agents via MCP tools. The schema includes:

- `documents` — the primary business records
- `mcp_tool_calls` — audit log for every tool invocation (INSERT-only)
- `pending_approvals` — human approval queue for high-risk document operations

---

## Learning Goals

1. Design a schema that exposes narrow MCP tool interfaces, not raw tables
2. Implement an INSERT-only audit table with trigger-based immutability
3. Write RLS policies that isolate tenants and agent identities
4. Design a "narrow insert" tool that only accepts specific, validated fields
5. Build a pending_approvals workflow for irreversible document operations

---

## Prerequisites

- Practice 10: RLS and Multi-Tenancy
- Practice 11: Audit Triggers
- Concept 22: PostgreSQL for MCP Tools
- Concept 23: Agent-Safe Database Actions

---

## Schema Overview

```
documents
  id UUID PK
  title TEXT
  body TEXT
  status TEXT CHECK (draft|review|published|archived)
  tenant_id TEXT
  created_by TEXT (agent_id or user_id)
  created_at TIMESTAMPTZ
  updated_at TIMESTAMPTZ

mcp_tool_calls
  id UUID PK
  tool_name TEXT
  agent_id TEXT
  tenant_id TEXT
  input_json JSONB
  output_json JSONB
  called_at TIMESTAMPTZ
  success BOOLEAN
  error_message TEXT
  [INSERT-ONLY: UPDATE and DELETE raise exception]

pending_approvals
  id UUID PK
  document_id UUID FK → documents
  action_type TEXT CHECK (archive|publish|bulk_delete)
  payload JSONB
  requested_by TEXT (agent_id)
  tenant_id TEXT
  status TEXT CHECK (pending|approved|rejected|expired)
  requested_at TIMESTAMPTZ
  expires_at TIMESTAMPTZ
  reviewed_by TEXT
  reviewed_at TIMESTAMPTZ
  review_notes TEXT
```

---

## Files in This Folder

| File | Purpose |
|------|---------|
| `README.md` | This file — overview and goals |
| `setup.sql` | Schema DDL with all tables, constraints, triggers, RLS |
| `00-setup-validation.md` | How to verify setup is working |
| `exercises.md` | Hands-on exercises |
| `solutions.md` | Reference solutions with explanations |
| `reflection.md` | Thinking prompts after completing exercises |
| `ontology-notes.md` | Concept map for this practice domain |
| `troubleshooting.md` | Common errors and fixes |
| `references.md` | Links to documentation |

---

## Blocked Operations

All SQL in this practice is marked `-- blocked: Docker not accessible`. Study the SQL patterns and apply them when Docker becomes available.
