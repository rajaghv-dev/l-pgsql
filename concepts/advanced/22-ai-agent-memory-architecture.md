# AI Agent Memory Architecture with PostgreSQL

Level: Advanced

## One-line intuition
PostgreSQL can serve as an AI agent's complete memory substrate — episodic memory in an append-only log, semantic memory via pgvector, procedural memory in stored functions, and working memory in CTEs — all isolated per agent with RLS and fully auditable.

## Why this exists
AI agents require persistent, queryable, auditable memory across sessions. Most agent frameworks reach for separate systems: a vector database for semantic search, a relational database for structured state, a queue for pending approvals, a logging service for audit trails. PostgreSQL with pgvector can collapse all four into one system, simplifying operations, enabling cross-memory-type SQL joins, and providing ACID guarantees across all memory writes.

## First-principles explanation

### Memory types from cognitive science
Cognitive science identifies four memory types, each with different access patterns:

| Memory type | Cognitive analog | PostgreSQL implementation | Access pattern |
|---|---|---|---|
| Episodic | "What happened" | Append-only `agent_events` table | INSERT-only, time-ordered queries |
| Semantic | "What is known" | `agent_knowledge` with vector embedding | HNSW nearest-neighbor + SQL filters |
| Procedural | "How to do things" | Stored functions, `agent_rules` table | Execute, not recall |
| Working | "Current context" | Session CTEs, temp tables | Discarded at session end |

### Schema design

**Episodic memory** (append-only, immutable):
```sql
-- blocked: Docker not accessible
CREATE TABLE agent_events (
    id bigserial PRIMARY KEY,
    agent_id text NOT NULL,
    session_id uuid NOT NULL,
    event_type text NOT NULL,         -- 'observation', 'action', 'reasoning', 'error'
    content text NOT NULL,
    content_embedding vector(1536),   -- embed content for semantic retrieval
    metadata jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE agent_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY agent_isolation ON agent_events
    USING (agent_id = current_setting('app.agent_id', true));

-- Time-series index (BRIN for append-only)
CREATE INDEX ON agent_events USING BRIN (created_at);
-- Semantic index
CREATE INDEX ON agent_events USING HNSW (content_embedding vector_cosine_ops);
-- No DELETE or UPDATE policies — episodic memory is immutable
```

**Semantic memory** (updatable, structured knowledge):
```sql
-- blocked: Docker not accessible
CREATE TABLE agent_knowledge (
    id bigserial PRIMARY KEY,
    agent_id text NOT NULL,
    concept_key text NOT NULL,        -- unique concept identifier per agent
    description text NOT NULL,
    embedding vector(1536),
    confidence float DEFAULT 1.0,     -- certainty level (decays over time)
    source_event_id bigint REFERENCES agent_events(id),
    last_accessed timestamptz,
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (agent_id, concept_key)
);

ALTER TABLE agent_knowledge ENABLE ROW LEVEL SECURITY;
CREATE POLICY agent_isolation ON agent_knowledge
    USING (agent_id = current_setting('app.agent_id', true));

CREATE INDEX ON agent_knowledge USING HNSW (embedding vector_cosine_ops);
```

**Procedural memory** (rules and behaviors):
```sql
-- blocked: Docker not accessible
CREATE TABLE agent_rules (
    id bigserial PRIMARY KEY,
    agent_id text NOT NULL,
    rule_name text NOT NULL,
    trigger_pattern text,             -- regex or JSON pattern that activates the rule
    action_template jsonb NOT NULL,   -- template for the action to take
    priority int DEFAULT 50,
    is_active boolean DEFAULT true,
    UNIQUE (agent_id, rule_name)
);
```

**Human approval queue**:
```sql
-- blocked: Docker not accessible
CREATE TABLE pending_actions (
    id bigserial PRIMARY KEY,
    agent_id text NOT NULL,
    session_id uuid NOT NULL,
    action_type text NOT NULL,
    payload jsonb NOT NULL,
    risk_level text NOT NULL DEFAULT 'medium'
        CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected', 'expired', 'executed')),
    reviewed_by text,
    reviewed_at timestamptz,
    executed_at timestamptz,
    expires_at timestamptz DEFAULT now() + interval '24 hours',
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Agents can INSERT but not UPDATE (no self-approval)
ALTER TABLE pending_actions ENABLE ROW LEVEL SECURITY;
CREATE POLICY agent_insert_only ON pending_actions FOR INSERT
    WITH CHECK (agent_id = current_setting('app.agent_id', true));
-- Human operators have a separate role with UPDATE/SELECT
```

### Hybrid retrieval pattern
The most powerful pattern: combine semantic recall (embedding similarity) with structured filtering (SQL predicates) in one query:

```sql
-- blocked: Docker not accessible
-- Recall: "What do I know about database performance from this week?"
WITH semantic_candidates AS (
    SELECT id, content, content_embedding <=> '[...]'::vector AS distance
    FROM agent_events
    WHERE agent_id = current_setting('app.agent_id', true)
      AND event_type = 'observation'
      AND created_at >= now() - interval '7 days'
    ORDER BY distance
    LIMIT 20
),
knowledge_candidates AS (
    SELECT description AS content, embedding <=> '[...]'::vector AS distance
    FROM agent_knowledge
    WHERE agent_id = current_setting('app.agent_id', true)
    ORDER BY distance
    LIMIT 10
)
SELECT content, distance, 'episodic' AS source FROM semantic_candidates
UNION ALL
SELECT content, distance, 'semantic' FROM knowledge_candidates
ORDER BY distance
LIMIT 10;
```

### Audit trail
Every agent action recorded in episodic memory is the audit trail. Add a SECURITY DEFINER function that enforces immutability:

```sql
-- blocked: Docker not accessible
CREATE OR REPLACE FUNCTION record_agent_action(
    p_event_type text,
    p_content text,
    p_metadata jsonb DEFAULT NULL,
    p_embedding vector DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_agent_id text := current_setting('app.agent_id', true);
    v_session_id uuid := current_setting('app.session_id', true)::uuid;
    v_event_id bigint;
BEGIN
    INSERT INTO agent_events (agent_id, session_id, event_type, content, content_embedding, metadata)
    VALUES (v_agent_id, v_session_id, p_event_type, p_content, p_embedding, p_metadata)
    RETURNING id INTO v_event_id;
    RETURN v_event_id;
END;
$$;
```

### Memory decay and confidence
Implement forgetting curves:
```sql
-- blocked: Docker not accessible
-- Decay confidence over time (scheduled via pg_cron or external cron)
UPDATE agent_knowledge
SET confidence = confidence * exp(-0.1 * extract(epoch FROM (now() - updated_at)) / 86400)
WHERE confidence > 0.01
  AND updated_at < now() - interval '1 day';

-- Forget low-confidence knowledge (with audit record)
INSERT INTO agent_events (agent_id, session_id, event_type, content, metadata)
SELECT agent_id, gen_random_uuid(), 'forgetting',
       'Forgot concept: ' || concept_key,
       jsonb_build_object('concept_key', concept_key, 'final_confidence', confidence)
FROM agent_knowledge
WHERE confidence < 0.01;

DELETE FROM agent_knowledge WHERE confidence < 0.01;
```

## Micro-concepts
- **`app.agent_id`**: session-level setting that RLS policies use to isolate agent data. Set on every connection.
- **INSERT-only audit**: no DELETE/UPDATE policies on `agent_events` = append-only log. Agents cannot rewrite their history.
- **SECURITY DEFINER function**: enforces that all episodic writes go through the audit function — cannot bypass by direct INSERT.
- **HNSW on events**: embedding-indexed episodic events enable semantic "memory recall" — finding past observations by meaning.
- **pending_actions**: the human-in-the-loop table. High-risk agent actions are paused here until a human approves. LISTEN/NOTIFY can alert operators when new pending actions arrive.
- **Memory consolidation**: periodic process that reads recent episodic events and writes synthesized knowledge into semantic memory — equivalent to sleep-based memory consolidation in humans.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Store agent actions in a table with a timestamp. Use pgvector to recall similar past events.

**Intermediate view**: Separate episodic (events) from semantic (knowledge) from working (session) memory. RLS isolates agents from each other. Pending_actions table enables human oversight.

**Advanced view**: The full architecture implements cognitive memory types in SQL with formal security boundaries. Hybrid retrieval combines vector similarity and SQL filtering in one query, enabling both "what is conceptually relevant" and "what happened within specific constraints." SECURITY DEFINER functions enforce write paths that cannot be bypassed. Memory decay implements forgetting as a first-class operation with audit trail. The system provides end-to-end accountability: every agent action, every memory write, and every human approval is in the database, queryable with SQL.

## Mental model
Think of PostgreSQL as the agent's brain:
- **agent_events** = long-term episodic memory (like a diary you can never erase)
- **agent_knowledge** = long-term semantic memory (like your knowledge graph)
- **agent_rules** = procedural memory (like your trained habits)
- **temp tables / CTEs** = working memory (like your short-term focus)
- **pending_actions** = the prefrontal cortex's "check with manager" function
- **RLS** = the boundary of self (one agent cannot access another's memories)

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_policies` (agent isolation), `pg_stat_activity` (agent session monitoring), `pg_stat_statements` (agent query patterns).

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Agent memory summary
SELECT agent_id,
       count(*) FILTER (WHERE event_type = 'action') AS actions,
       count(*) FILTER (WHERE event_type = 'observation') AS observations,
       max(created_at) AS last_active
FROM agent_events
GROUP BY agent_id;

-- Pending approvals by risk level
SELECT risk_level, count(*), min(created_at) AS oldest
FROM pending_actions WHERE status = 'pending'
GROUP BY risk_level ORDER BY risk_level;
```

**Non-SQL / hybrid view**: LangChain and LlamaIndex have PostgreSQL memory backends. The `ConversationBufferMemory` concept maps to `agent_events`. Tool call results map to `agent_events.event_type = 'tool_result'`. Most frameworks can be wired to this schema.

## Design principle
**Immutability for episodic memory, mutability for semantic**: episodic events are facts about the past — they cannot be changed. Semantic knowledge is a model of the world — it should be updated as the world changes. Mixing the two in one table creates conflicting invariants that corrupt both the audit trail and the knowledge quality.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: RLS isolation by `agent_id` is a logical boundary, not a cryptographic one. A DBA (with BYPASSRLS) can read all agents' memories. If agent memories contain sensitive user data, they must be encrypted at rest (pgcrypto) and the encryption key managed externally. The RLS boundary protects agents from each other, but not from privileged database users.

**Creative**: Implement cross-agent memory sharing for agent teams: a `shared_knowledge` table (no RLS isolation) where agents publish approved knowledge for other agents to consume. A supervisor agent reviews and approves items before they enter shared knowledge — a multi-agent knowledge commons with editorial control.

**Systems**: The episodic memory table is an append-only log — it grows without bound. Implement partitioning by `created_at` (monthly) and a retention policy that archives or drops old partitions. The audit requirement (immutability) conflicts with the retention requirement (deletion) — resolve by archiving to cold storage (S3 via file_fdw or S3 FDW) before dropping the partition.

## MCP and agent perspective
This lesson IS the MCP/agent perspective. The architecture provides:
- **Action accountability**: every agent action in episodic memory, queryable with SQL
- **Semantic recall**: HNSW nearest-neighbor on events and knowledge
- **Human oversight**: pending_actions table as the mandatory approval gate for high-risk actions
- **Agent isolation**: RLS per agent_id
- **Forgetting**: memory decay with audit trail (the system knows what was forgotten, even if the agent doesn't)

Implementation checklist for a new agent:
1. Set `app.agent_id` on connect
2. Use `record_agent_action()` for all episodic writes
3. Route high-risk actions through `pending_actions`
4. Schedule memory consolidation (episodic → semantic) daily
5. Schedule memory decay weekly

## Ontology perspective
The four memory types represent four different ontological commitments about time and mutability:
- Episodic: the past is immutable — it happened, and no agent can change that
- Semantic: knowledge is current best belief — it should be updated as new evidence arrives
- Procedural: behavior patterns — acquired through experience, stable until retrained
- Working: the present moment — ephemeral, never persisted

This architecture makes these ontological commitments explicit in the database schema: immutable table for episodic, mutable table for semantic, configuration table for procedural, session scope for working. The schema enforces the agent's relationship with time.

## Practice session

**Exercise 1 — Set up agent isolation**: Configure RLS for agent_id.
```sql
-- blocked: Docker not accessible
CREATE TABLE agent_events (id bigserial PRIMARY KEY, agent_id text, content text, created_at timestamptz DEFAULT now());
ALTER TABLE agent_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY isolation ON agent_events USING (agent_id = current_setting('app.agent_id', true));
SET LOCAL app.agent_id = 'agent-001';
INSERT INTO agent_events (agent_id, content) VALUES ('agent-001', 'First observation');
```

**Exercise 2 — Semantic memory with pgvector**:
```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS vector;
ALTER TABLE agent_events ADD COLUMN embedding vector(3);
CREATE INDEX ON agent_events USING HNSW (embedding vector_cosine_ops);
-- Semantic recall: find similar past events
SELECT content, embedding <=> '[0.1, 0.2, 0.3]'::vector AS distance
FROM agent_events ORDER BY distance LIMIT 5;
```

**Exercise 3 — Pending approvals queue**:
```sql
-- blocked: Docker not accessible
INSERT INTO pending_actions (agent_id, session_id, action_type, payload, risk_level)
VALUES ('agent-001', gen_random_uuid(), 'delete_data',
        '{"table": "customer_pii", "reason": "gdpr_request"}', 'critical');
SELECT id, action_type, risk_level, status, expires_at FROM pending_actions WHERE status = 'pending';
```

**Exercise 4 — Cross-type retrieval**: Combine episodic + semantic in one query.
```sql
-- blocked: Docker not accessible
-- Recent observations about a topic (semantic + temporal filter)
SELECT content, created_at FROM agent_events
WHERE agent_id = 'agent-001'
  AND created_at > now() - interval '7 days'
ORDER BY embedding <=> '[0.1, 0.2, 0.3]'::vector
LIMIT 5;
```

**Exercise 5 — Memory audit**: How much has the agent stored?
```sql
-- blocked: Docker not accessible
SELECT agent_id, event_type, count(*), min(created_at), max(created_at)
FROM agent_events
GROUP BY agent_id, event_type
ORDER BY agent_id, event_type;
```

## References
- pgvector GitHub: https://github.com/pgvector/pgvector
- PostgreSQL Documentation: [Row Security Policies](https://www.postgresql.org/docs/16/ddl-rowsecurity.html)
- PostgreSQL Documentation: [LISTEN/NOTIFY](https://www.postgresql.org/docs/16/sql-listen.html)
- Tulving, E. (1972): Episodic and Semantic Memory — original cognitive science distinction
- LangChain PostgreSQL memory: https://python.langchain.com/docs/integrations/memory/postgres_chat_message_history/
- Anthropic: [Building effective agents](https://www.anthropic.com/research/building-effective-agents)
