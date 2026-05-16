# AI Agent Memory Ontology

Level: Advanced
Domain: Agent Safety / PostgreSQL / AI

## Definition
AI agent memory refers to the mechanisms by which an autonomous agent (such as a Claude-based MCP agent) persists, retrieves, and reasons over past interactions, accumulated knowledge, and learned procedures — implemented in PostgreSQL using a combination of relational tables, vector embeddings, append-only event logs, and row-level security.

## Why this concept matters
Stateless LLMs forget everything between calls. Giving an agent durable memory in PostgreSQL enables continuity, accountability, and learning. The memory schema must be designed for auditability (who wrote what, when), tenant isolation (agents cannot read each other's memory), and retrieval efficiency (semantic search via pgvector + structured queries via SQL).

## Related concepts
- [[vector-search-ontology]] — child (semantic memory via pgvector)
- [[security-ontology]] — child (RLS, tenant isolation, BYPASSRLS)
- [[transaction-ontology]] — related (append-only log, audit trail)
- [[schema-design-ontology]] — related (memory table design)
- [[extension-ontology]] — related (pgvector, pgcrypto)
- [[domain-ontology-examples]] — related (memory applied to domains)

---

## Agent

One-line definition: An autonomous software process that perceives a context, selects and executes tools (MCP calls, SQL queries), and produces outputs — with its state persisted to a database between invocations.

In this repository: The Claude agent connects to PostgreSQL via MCP tools (`mcp__postgres`), reads from and writes to memory tables, and is constrained by RLS policies and column-level privileges.

---

## Tool (MCP)

One-line definition: A named function the agent can invoke via the Model Context Protocol to interact with external systems (databases, APIs, file systems); each call is an explicit, auditable action.

MCP tool categories for PostgreSQL agents:
| Tool type | Examples |
|-----------|---------|
| Read data | `query_database`, `list_tables`, `describe_table` |
| Write data | `execute_sql`, `insert_row` |
| Schema introspection | `get_schema`, `list_columns` |
| Memory | `store_memory`, `retrieve_similar` |

Agent constraints:
- Tools must be explicitly listed in the agent's allowed tool set.
- Each tool call is logged with timestamp, input, and output.
- Privileged tools (DDL, DELETE, BYPASSRLS) require human approval.

---

## Memory Types

### Episodic Memory
One-line definition: A log of specific past events and interactions, stored as timestamped records with context, enabling the agent to recall "what happened when."

```sql
-- blocked: Docker not accessible
CREATE TABLE agent_memory.episodes (
    id          BIGSERIAL PRIMARY KEY,
    agent_id    TEXT        NOT NULL,
    tenant_id   BIGINT      NOT NULL,
    session_id  UUID        NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    event_type  TEXT        NOT NULL,
    summary     TEXT        NOT NULL,
    detail      JSONB,
    embedding   vector(1536)  -- semantic index over summary
);

CREATE INDEX idx_episodes_agent ON agent_memory.episodes (agent_id, occurred_at DESC);
CREATE INDEX idx_episodes_embedding ON agent_memory.episodes USING hnsw (embedding vector_cosine_ops);
```

---

### Semantic Memory
One-line definition: Accumulated, generalized knowledge stored as text+embedding pairs, retrieved by semantic similarity to the current query — independent of specific past events.

```sql
-- blocked: Docker not accessible
CREATE TABLE agent_memory.knowledge (
    id          BIGSERIAL PRIMARY KEY,
    agent_id    TEXT        NOT NULL,
    tenant_id   BIGINT      NOT NULL,
    topic       TEXT        NOT NULL,
    content     TEXT        NOT NULL,
    embedding   vector(1536),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_knowledge_embedding ON agent_memory.knowledge
    USING hnsw (embedding vector_cosine_ops);
```

Retrieval:
```sql
-- blocked: Docker not accessible
-- Find the 5 most semantically relevant knowledge entries
SELECT topic, content, embedding <=> $1 AS distance
FROM agent_memory.knowledge
WHERE agent_id = $2 AND tenant_id = $3
ORDER BY embedding <=> $1
LIMIT 5;
```

---

### Procedural Memory
One-line definition: Stored sequences of steps or rules the agent has learned, enabling it to recall and reuse successful multi-step procedures without re-deriving them from scratch.

```sql
-- blocked: Docker not accessible
CREATE TABLE agent_memory.procedures (
    id          BIGSERIAL PRIMARY KEY,
    agent_id    TEXT NOT NULL,
    tenant_id   BIGINT NOT NULL,
    name        TEXT NOT NULL,
    description TEXT NOT NULL,
    steps       JSONB NOT NULL,  -- [{step, tool, params}, ...]
    success_count INTEGER DEFAULT 0,
    created_at  TIMESTAMPTZ DEFAULT now()
);
```

---

## Retrieval

One-line definition: The process of querying memory to surface relevant context for the current agent task, combining semantic similarity (vector search) with structured filters (SQL WHERE clauses).

```sql
-- blocked: Docker not accessible
-- Hybrid retrieval: semantic + recency + agent scope
WITH semantic AS (
    SELECT id, summary, embedding <=> $query_embedding AS dist
    FROM agent_memory.episodes
    WHERE agent_id = $agent_id
      AND tenant_id = $tenant_id
      AND occurred_at > now() - interval '30 days'
    ORDER BY dist
    LIMIT 20
)
SELECT * FROM semantic WHERE dist < 0.3
ORDER BY dist
LIMIT 5;
```

---

## Audit Trail

One-line definition: An append-only, tamper-resistant record of every agent action (tool call, SQL executed, decision made) with timestamps and actor identity, enabling post-hoc review and compliance.

```sql
-- blocked: Docker not accessible
CREATE TABLE agent_memory.audit_log (
    id          BIGSERIAL PRIMARY KEY,
    agent_id    TEXT        NOT NULL,
    tenant_id   BIGINT      NOT NULL,
    session_id  UUID        NOT NULL,
    action_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    action_type TEXT        NOT NULL,  -- 'tool_call', 'sql_execute', 'decision'
    tool_name   TEXT,
    input_data  JSONB,
    output_data JSONB,
    status      TEXT        NOT NULL,  -- 'success', 'error', 'blocked'
    error_msg   TEXT
);

-- Append-only: no UPDATE or DELETE privilege for agent role
REVOKE UPDATE, DELETE ON agent_memory.audit_log FROM agent_role;
```

---

## RLS for Agent Tenant Isolation

One-line definition: Row-Level Security policies on all memory tables ensure each agent can only access its own tenant's data, even if it constructs SQL dynamically.

```sql
-- blocked: Docker not accessible
-- Enable RLS on all memory tables
ALTER TABLE agent_memory.episodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_memory.episodes FORCE ROW LEVEL SECURITY;

-- Policy: agent can only read/write its own tenant's episodes
CREATE POLICY agent_tenant_isolation ON agent_memory.episodes
    USING (tenant_id = current_setting('app.current_tenant')::BIGINT
           AND agent_id = current_setting('app.current_agent'));

-- Set context at session start (done by connection pool or application)
SET app.current_tenant = '42';
SET app.current_agent = 'claude-agent-v1';
```

Related: [[security-ontology]]

---

## Append-Only Event Log

One-line definition: A table where rows are only ever inserted, never updated or deleted; provides an immutable record of all state changes; the foundation of event sourcing patterns.

```sql
-- blocked: Docker not accessible
CREATE TABLE agent_memory.events (
    id          BIGSERIAL PRIMARY KEY,
    agent_id    TEXT        NOT NULL,
    tenant_id   BIGINT      NOT NULL,
    event_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    event_type  TEXT        NOT NULL,
    payload     JSONB       NOT NULL
);

-- Trigger to prevent updates and deletes
CREATE OR REPLACE FUNCTION prevent_modification()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'This table is append-only';
END;
$$;

CREATE TRIGGER no_modify_events
    BEFORE UPDATE OR DELETE ON agent_memory.events
    FOR EACH ROW EXECUTE FUNCTION prevent_modification();
```

---

## Human Approval Workflow

One-line definition: A pattern where high-risk agent actions (DDL, mass DELETE, privilege escalation) are staged as pending requests that require explicit human confirmation before execution.

```sql
-- blocked: Docker not accessible
CREATE TABLE agent_memory.approval_queue (
    id           BIGSERIAL PRIMARY KEY,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    agent_id     TEXT        NOT NULL,
    tenant_id    BIGINT      NOT NULL,
    action_type  TEXT        NOT NULL,
    action_sql   TEXT        NOT NULL,
    reason       TEXT,
    status       TEXT        NOT NULL DEFAULT 'pending',  -- pending, approved, rejected
    reviewed_by  TEXT,
    reviewed_at  TIMESTAMPTZ
);
```

Workflow:
1. Agent inserts a row into `approval_queue` with the proposed SQL.
2. Human reviews and sets `status = 'approved'` or `'rejected'`.
3. Agent polls (or is notified) and executes only if approved.
4. Execution result is appended to `audit_log`.

---

## Memory Schema Summary

```
agent_memory schema
├── episodes        — episodic events with embeddings
├── knowledge       — semantic facts with embeddings
├── procedures      — learned multi-step workflows
├── events          — append-only immutable event log
├── audit_log       — every agent action logged
└── approval_queue  — human-approval staging area
```

---

## System catalog reference
- `pg_policies` — RLS policies on memory tables
- `pg_roles` — agent role attributes (should lack SUPERUSER, BYPASSRLS)
- `pg_stat_activity` — active agent sessions
- `pg_extension` — verify pgvector is installed
- `pg_am` — hnsw and ivfflat index access methods

---

## Beginner mental model
An AI agent's memory is like a journal (episodic), a textbook (semantic), and a recipe book (procedural) — all stored as database tables. Row-level security ensures the agent can only read its own journal. The audit log is like a black box recorder that never gets erased.

## Intermediate mental model
Memory retrieval combines two methods: semantic search (pgvector finds similar past events by meaning) and structured queries (SQL filters by agent_id, tenant_id, time range). The two are combined in a CTE. RLS enforces tenant isolation at the database level, so even a bug in the agent's SQL cannot leak cross-tenant data.

## Advanced mental model
The append-only event log is the source of truth; episodic and semantic memory are projections (materialized views or derived tables) over it. This event-sourcing pattern enables replay, audit, and time-travel queries. Human approval workflows must be atomic: the approval record and the execution record must be in separate transactions to prevent the approval being rolled back if the execution fails. Vector index recall is imperfect — the retrieval layer must include a confidence threshold and a fallback to structured lookup.

## MCP and agent perspective
This ontology file describes the agent's own architecture. An agent reading this file understands its own memory model. Key operational rules:
1. Always `SET app.current_tenant` and `SET app.current_agent` before any memory operation.
2. Never execute DDL without an approved row in `approval_queue`.
3. Log every tool call to `audit_log` before and after execution.
4. Retrieve episodic memory with a time bound to prevent unbounded vector scans.
5. Treat `audit_log` as immutable — never attempt UPDATE or DELETE on it.

## Practical implication
| Situation | Implication |
|-----------|-------------|
| RLS not enforced on memory tables | Agent SQL bugs can leak cross-tenant data |
| No FORCE ROW LEVEL SECURITY | Table owner bypasses RLS; agent exploiting this privilege could read all memory |
| Vector search without tenant filter | Returns nearest-neighbors across all tenants before RLS filters; use pre-filter WHERE |
| Audit log with UPDATE privilege | Agent can overwrite evidence of its own errors; use REVOKE UPDATE |
| No human approval for DDL | Agent can silently modify schema, breaking other components |
| Embedding dimension mismatch | pgvector errors at insert time; pin model version in deployment config |

## Obsidian connections
[[vector-search-ontology]] [[security-ontology]] [[transaction-ontology]] [[schema-design-ontology]] [[extension-ontology]] [[domain-ontology-examples]] [[observability-ontology]]

## References
- pgvector: https://github.com/pgvector/pgvector
- PostgreSQL RLS: https://www.postgresql.org/docs/16/ddl-rowsecurity.html
- Model Context Protocol: https://modelcontextprotocol.io
- Event Sourcing pattern: https://martinfowler.com/eaaDev/EventSourcing.html
