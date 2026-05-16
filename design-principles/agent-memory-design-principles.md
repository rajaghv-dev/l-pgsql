# Agent Memory Design Principles

Six principles for designing agent memory systems backed by PostgreSQL. These principles apply to any system where AI agents need to persist, retrieve, and share knowledge across sessions.

---

## Principle 1: Separate Episodic from Semantic Memory

**Use distinct tables and retrieval methods for episodic (what happened) and semantic (what is known) memory.**

Episodic memory is timestamped event records — useful for recency, ordering, and pattern detection. Semantic memory is vector embeddings of knowledge — useful for similarity and conceptual retrieval. Mixing them in one table creates a retrieval mess: you cannot efficiently do both FTS on event descriptions and cosine similarity on knowledge embeddings.

Schema:
```sql
-- blocked: Docker not accessible
-- Episodic: timestamped events
CREATE TABLE agent_episodic_memory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  summary TEXT,
  context JSONB,
  happened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  search_vector tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(summary,'') || ' ' || coalesce(event_type,''))
  ) STORED
);

-- Semantic: embedded knowledge
CREATE TABLE agent_semantic_memory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id TEXT NOT NULL,
  content TEXT NOT NULL,
  embedding vector(1536),
  embedding_model TEXT NOT NULL,  -- track which model produced this
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**Why**: Retrieval methods are incompatible — FTS GIN indexes for episodic, IVFFlat/HNSW for semantic. Unified tables force compromises on both.

---

## Principle 2: Use pgvector for Semantic Retrieval

**Store knowledge as vector embeddings in a pgvector column; retrieve by cosine similarity.**

Keyword search fails for semantic questions: "what do I know about vendor payment timelines?" will not match a row that contains "supplier disbursement schedules". Cosine similarity on embeddings captures semantic relatedness without keyword overlap.

```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS vector;

-- Find the 5 most similar memories to a query embedding
SELECT content, 1 - (embedding <=> $1::vector) AS similarity
FROM agent_semantic_memory
WHERE agent_id = current_setting('app.agent_id')
ORDER BY embedding <=> $1::vector
LIMIT 5;
```

**Why**: pgvector keeps semantic search inside PostgreSQL with ACID guarantees. No separate vector database required for most workloads.

---

## Principle 3: Protect with RLS by agent_id

**Every memory table has RLS enabled; agents can only see and write their own memory.**

An agent that can read another agent's memory can free-ride on that agent's accumulated knowledge — or worse, be confused by another agent's context. RLS with `agent_id = current_setting('app.agent_id')` enforces isolation structurally.

```sql
-- blocked: Docker not accessible
ALTER TABLE agent_episodic_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_episodic_memory FORCE ROW LEVEL SECURITY;

CREATE POLICY own_episodic_only ON agent_episodic_memory
  FOR ALL TO mcp_agent_role
  USING (agent_id = current_setting('app.agent_id', true));
```

**Why**: Agent isolation prevents cross-contamination, protects privacy (one agent's context may contain sensitive data from its tenant), and makes agent behavior predictable.

---

## Principle 4: Audit All Memory Writes

**Every INSERT into a memory table generates an audit event in the same transaction.**

Memory writes are agent actions. An agent that can write unaudited memory can self-modify its own knowledge base in ways that are invisible to human oversight. The same audit trigger that applies to business data applies to memory tables.

**Why**: Memory manipulation is a class of agent behavior that requires oversight. Without audit, an agent could write false beliefs into its semantic memory and act on them in future sessions.

---

## Principle 5: TTL via Scheduled Deletion Job, Not Triggers

**Implement memory expiry by running a periodic job that deletes or archives expired rows — not via a trigger that fires on INSERT or UPDATE.**

A trigger-based TTL (e.g., "delete rows older than 90 days on every INSERT") creates unpredictable write latency: each memory INSERT triggers a potentially large DELETE. A scheduled job (run nightly) processes the batch of expired rows predictably.

```sql
-- blocked: Docker not accessible
-- Nightly archival job (run by a privileged maintenance role, not the agent)
BEGIN;

INSERT INTO agent_episodic_memory_archive
SELECT * FROM agent_episodic_memory
WHERE happened_at < now() - INTERVAL '90 days';

DELETE FROM agent_episodic_memory
WHERE happened_at < now() - INTERVAL '90 days'
  AND id IN (SELECT id FROM agent_episodic_memory_archive
             WHERE happened_at < now() - INTERVAL '90 days');

COMMIT;
```

**Why**: Predictable maintenance is safer than hidden write-time side effects. The agent should not bear the cost of archival.

---

## Principle 6: Never Expose Other Agents' Memories

**RLS must ensure zero cross-agent memory visibility — not just limited visibility.**

An agent that retrieves "similar memories" via pgvector cosine search must only search within its own agent_id. The WHERE clause alone is not enough — RLS provides the structural guarantee that even if the WHERE clause is removed (e.g., by a bug), the policy still filters.

```sql
-- blocked: Docker not accessible
-- Both the query WHERE and the RLS policy independently enforce isolation:
SELECT content, embedding <=> $1::vector AS distance
FROM agent_semantic_memory
WHERE agent_id = current_setting('app.agent_id')  -- explicit WHERE
ORDER BY distance
LIMIT 5;
-- RLS policy ALSO filters: no other agent's rows pass even without the WHERE clause
```

**Why**: Defense in depth. Two independent isolation mechanisms (explicit WHERE + RLS) means a bug in one does not compromise isolation.

---

## Summary

| # | Principle | Mechanism |
|---|-----------|-----------|
| 1 | Separate episodic from semantic | Distinct tables + distinct indexes |
| 2 | pgvector for semantic retrieval | vector column + cosine operator |
| 3 | RLS by agent_id | ENABLE ROW LEVEL SECURITY + policy |
| 4 | Audit all memory writes | AFTER INSERT trigger → audit_log |
| 5 | TTL via scheduled job | Nightly archival job, not trigger |
| 6 | Zero cross-agent visibility | RLS + explicit WHERE (defense in depth) |
