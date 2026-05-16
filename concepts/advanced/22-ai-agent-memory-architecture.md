# AI Agent Memory Architecture with PostgreSQL

Level: Advanced
PostgreSQL 16 | Container: `docker exec cfp_postgres psql -U cfp -d cfp`

## One-line intuition
PostgreSQL can serve as an agent's complete memory substrate: episodic memory in an append-only log, semantic memory via pgvector, procedural memory in SQL functions — all isolated by RLS.

## Why this exists
AI agents need persistent, queryable, auditable memory. PostgreSQL provides ACID writes, SQL retrieval, vector similarity search (pgvector), row-level isolation (RLS), and audit trails in a single system — eliminating the need for a separate vector database, a separate audit log, and a separate approval store.

## First-principles explanation
Cognitive science distinguishes three memory types: episodic (what happened), semantic (what is known), and procedural (how to do things). An agent backed by PostgreSQL maps these to: an append-only event log (episodic), a pgvector-indexed embeddings table (semantic), and a set of stored PL/pgSQL functions or rule tables (procedural). Working memory maps to session-scoped CTEs or temp tables.

## Micro-concepts
- **Episodic memory**: append-only `agent_events` table — time-ordered, immutable, auditable
- **Semantic memory**: `agent_knowledge` with `vector(N)` column — queried by cosine similarity
- **Procedural memory**: `agent_rules` table or stored PL/pgSQL functions — defines agent behaviors
- **Working memory**: per-session CTEs or temp tables — discarded after transaction
- **Pending approvals**: `pending_actions` table — high-risk actions requiring human sign-off

## Beginner view
PostgreSQL stores structured data. Agents read and write structured data. The connection is natural — the challenge is design.

## Intermediate view
Design separate tables for each memory type. Use RLS to isolate agent_id. Use pgvector for semantic retrieval. Use TRIGGER for audit on episodic memory.

## Advanced view
Hybrid retrieval: combine pgvector nearest-neighbor search (semantic) with SQL filtering (structured predicates) in a single query. The agent retrieves memories by meaning AND by metadata constraints simultaneously.

## Mental model
Think of the agent's memory as a personal database inside the shared database: RLS is the wall between agents, pgvector is the semantic search engine, the event log is the audit trail, and pending_actions is the human inbox.

## PostgreSQL view
```sql
-- blocked: Docker not accessible; validate against cfp_postgres when available

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Episodic memory (append-only)
CREATE TABLE agent_events (
    id BIGSERIAL PRIMARY KEY,
    agent_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    content TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE agent_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY agent_events_isolation ON agent_events
    USING (agent_id = current_setting('app.agent_id', true));

-- Semantic memory (pgvector)
CREATE TABLE agent_knowledge (
    id BIGSERIAL PRIMARY KEY,
    agent_id TEXT NOT NULL,
    concept TEXT NOT NULL,
    description TEXT,
    embedding vector(3),  -- use vector(1536) for real embeddings
    updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE agent_knowledge ENABLE ROW LEVEL SECURITY;
CREATE POLICY agent_knowledge_isolation ON agent_knowledge
    USING (agent_id = current_setting('app.agent_id', true));
CREATE INDEX ON agent_knowledge USING hnsw (embedding vector_cosine_ops);

-- Human approval queue
CREATE TABLE pending_actions (
    id BIGSERIAL PRIMARY KEY,
    agent_id TEXT NOT NULL,
    action_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','expired')),
    reviewed_by TEXT,
    reviewed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ DEFAULT now() + interval '24 hours',
    created_at TIMESTAMPTZ DEFAULT now()
);
```

## SQL view
```sql
-- blocked: Docker not accessible

-- Hybrid memory retrieval: semantic + temporal filter
SELECT content, embedding <=> '[0.1, 0.2, 0.3]' AS distance
FROM agent_events
WHERE agent_id = current_setting('app.agent_id', true)
  AND event_type = 'observation'
  AND created_at > now() - interval '7 days'
ORDER BY distance
LIMIT 5;

-- Submit for human approval
INSERT INTO pending_actions (agent_id, action_type, payload)
VALUES (
    current_setting('app.agent_id', true),
    'delete_customer_record',
    '{"customer_id": 42, "reason": "user requested"}'::jsonb
);
```

## Non-SQL or hybrid view
For very large semantic memory (> 1M embeddings), consider pgvector with HNSW and approximate search. For distributed agents, use RLS with separate schemas per agent_id for stronger isolation.

## Design principle
**Separate memory types into separate tables**: mixing episodic events (append-only) with semantic knowledge (updatable) in one table creates conflicting invariants and makes audit harder.

## Critical thinking
When would an agent's memory benefit from a graph structure rather than relational tables? (When relationships between memories are as important as the memories themselves.)

## Creative thinking
How would you design a memory forgetting mechanism that complies with "right to be forgotten" requirements while keeping an audit trail of what was forgotten?

## Systems thinking
If two agent instances share the same `agent_id`, what happens to RLS isolation? (Both see the same data — agent_id is a logical isolation boundary, not a cryptographic one.)

## MCP and agent perspective
This lesson IS the MCP/agent perspective. Key rules:
- One `pending_actions` row per high-risk action — never auto-execute without human approval
- Episodic memory is INSERT-only — agents cannot rewrite history
- Semantic memory is READ-WRITE but audited
- Working memory is never persisted

## Ontology perspective
[[ai-agent-memory-ontology]] [[vector-search-ontology]] [[security-ontology]] [[transaction-ontology]]

## References
- [pgvector](https://github.com/pgvector/pgvector) — vector similarity search for PostgreSQL
- [PostgreSQL RLS](https://www.postgresql.org/docs/16/ddl-rowsecurity.html) — row-level security
- [LISTEN/NOTIFY](https://www.postgresql.org/docs/16/sql-listen.html) — for human approval notifications
