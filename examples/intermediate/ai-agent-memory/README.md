# AI Agent Memory Example

Level: Intermediate
Domain: PostgreSQL as an AI agent's persistent memory store with vector similarity search
Synthetic data: Yes

## Overview

Demonstrates how to use PostgreSQL as the memory backend for an AI agent.
Two tables cover distinct memory concerns:

- `memories` — the agent's factual and episodic memory, with a vector embedding
  for semantic retrieval via `pgvector`.
- `agent_actions` — a structured log of every action the agent takes, including
  human approval status for sensitive operations.

Row-Level Security isolates each agent's memory from others when multiple agents
share the database. JSONB columns (`input`, `output`) give flexibility for diverse
action schemas.

Note: `vector(3)` is used here for demonstration. A real deployment would use
`vector(1536)` (OpenAI) or `vector(4096)` (Llama 3) embeddings.

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

CREATE EXTENSION IF NOT EXISTS vector;

-- Each agent has a row in this registry
CREATE TABLE agents (
    id          SERIAL PRIMARY KEY,
    name        TEXT   NOT NULL UNIQUE,
    description TEXT   NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Memories: semantic + episodic facts stored per agent
CREATE TABLE memories (
    id          BIGSERIAL PRIMARY KEY,
    agent_id    INT         NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    content     TEXT        NOT NULL,
    embedding   VECTOR(3)   NOT NULL,   -- demo: 3 dims; production: 1536
    memory_type TEXT        NOT NULL DEFAULT 'general'
                            CHECK (memory_type IN ('general','episodic','semantic','procedural')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Approximate nearest-neighbour index (IVFFlat)
-- For vector(3) demo, lists=1 is sufficient; for vector(1536) use lists=100+
CREATE INDEX idx_memories_embedding ON memories
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 1);

CREATE INDEX idx_memories_agent_type ON memories (agent_id, memory_type);

-- Action log: every action the agent performs is recorded here
CREATE TABLE agent_actions (
    id               BIGSERIAL PRIMARY KEY,
    agent_id         INT         NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    action_type      TEXT        NOT NULL,   -- e.g. 'web_search', 'file_write', 'api_call'
    input            JSONB       NOT NULL DEFAULT '{}',
    output           JSONB,                  -- NULL if not yet completed
    requires_human_approval BOOLEAN NOT NULL DEFAULT FALSE,
    approved_by      TEXT,                   -- NULL until a human approves
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_agent_actions_agent_id ON agent_actions (agent_id);
CREATE INDEX idx_agent_actions_type     ON agent_actions (action_type);

-- RLS: each agent can only read/write its own rows
ALTER TABLE memories       ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_actions  ENABLE ROW LEVEL SECURITY;

-- app.agent_id must be set at the start of each session
CREATE POLICY memories_agent_isolation ON memories
    USING (agent_id = current_setting('app.agent_id', TRUE)::INT);

CREATE POLICY actions_agent_isolation ON agent_actions
    USING (agent_id = current_setting('app.agent_id', TRUE)::INT);
```

## Seed data

```sql
-- Agents
INSERT INTO agents (name, description) VALUES
  ('ResearchBot',  'General-purpose research and summarisation agent'),
  ('PlannerBot',   'Project planning and task decomposition agent');

-- ---- ResearchBot memories (agent_id = 1) ----
SET app.agent_id = '1';

INSERT INTO memories (agent_id, content, embedding, memory_type) VALUES
  (1, 'PostgreSQL supports vector similarity search via the pgvector extension.',
   '[0.8, 0.1, 0.3]', 'semantic'),

  (1, 'The user prefers concise summaries over detailed explanations.',
   '[0.2, 0.9, 0.1]', 'episodic'),

  (1, 'Window functions like ROW_NUMBER and RANK operate over partitioned result sets.',
   '[0.7, 0.2, 0.5]', 'semantic'),

  (1, 'User asked for a comparison of B-tree vs GIN indexes on 2024-03-15.',
   '[0.5, 0.6, 0.2]', 'episodic'),

  (1, 'To search semantically: embed the query, then ORDER BY embedding <-> query_vec LIMIT k.',
   '[0.9, 0.1, 0.4]', 'procedural');

-- ---- PlannerBot memories (agent_id = 2) ----
SET app.agent_id = '2';

INSERT INTO memories (agent_id, content, embedding, memory_type) VALUES
  (2, 'Project Lighthouse is due at end of Q3. Owner: Carol Jenkins.',
   '[0.3, 0.8, 0.6]', 'episodic'),

  (2, 'Break large tasks into subtasks of no more than 2 hours each.',
   '[0.1, 0.7, 0.9]', 'procedural'),

  (2, 'Sprint planning happens every other Monday at 10:00.',
   '[0.4, 0.5, 0.7]', 'episodic');

-- ---- Agent actions ----
SET app.agent_id = '1';

INSERT INTO agent_actions (agent_id, action_type, input, output, requires_human_approval, approved_by) VALUES
  (1, 'web_search',
   '{"query": "pgvector cosine similarity example"}',
   '{"results_count": 5, "top_url": "https://github.com/pgvector/pgvector"}',
   FALSE, NULL),

  (1, 'summarise',
   '{"document_id": 42, "max_words": 200}',
   '{"summary": "pgvector enables storing and querying high-dimensional vectors in PostgreSQL."}',
   FALSE, NULL),

  (1, 'file_write',
   '{"path": "/reports/pgvector-summary.md", "bytes": 1240}',
   NULL,
   TRUE, NULL);   -- requires human approval, not yet approved

SET app.agent_id = '2';

INSERT INTO agent_actions (agent_id, action_type, input, output, requires_human_approval, approved_by) VALUES
  (2, 'create_task',
   '{"title": "Draft Q3 roadmap", "assignee": "Carol Jenkins", "due": "2024-09-30"}',
   '{"task_id": "T-1012", "status": "created"}',
   FALSE, NULL),

  (2, 'send_email',
   '{"to": "carol@example.test", "subject": "Sprint planning reminder"}',
   NULL,
   TRUE, 'admin@example.test');   -- approved by human
```

## Example queries

### Semantic similarity search (k-NN)

```sql
-- Find the 3 memories most similar to a query vector
-- In a real system the query vector would come from an embedding model
SET app.agent_id = '1';

SELECT id,
       content,
       memory_type,
       embedding <-> '[0.85, 0.1, 0.35]' AS cosine_distance
FROM   memories
WHERE  agent_id = 1
ORDER  BY embedding <-> '[0.85, 0.1, 0.35]'
LIMIT  3;
```

### Filter semantic search by memory type

```sql
SET app.agent_id = '1';

SELECT id, content, memory_type,
       embedding <=> '[0.7, 0.2, 0.45]' AS cosine_similarity
FROM   memories
WHERE  agent_id    = 1
  AND  memory_type = 'semantic'
ORDER  BY embedding <=> '[0.7, 0.2, 0.45]' DESC
LIMIT  5;
```

Note: `<->` is L2 distance, `<=>` is cosine similarity (higher = more similar).

### View pending actions that need human approval

```sql
-- This query uses BYPASSRLS since it's for an admin dashboard
SELECT a.id,
       ag.name          AS agent_name,
       a.action_type,
       a.input,
       a.created_at
FROM   agent_actions a
JOIN   agents        ag ON ag.id = a.agent_id
WHERE  a.requires_human_approval = TRUE
  AND  a.approved_by IS NULL
ORDER  BY a.created_at ASC;
```

### Approve a pending action

```sql
UPDATE agent_actions
SET    approved_by = 'operator@example.test'
WHERE  id = 3
  AND  requires_human_approval = TRUE
  AND  approved_by IS NULL;
```

### Memory count and types per agent

```sql
SELECT ag.name,
       m.memory_type,
       COUNT(*) AS count
FROM   agents  ag
JOIN   memories m ON m.agent_id = ag.id
GROUP  BY ag.name, m.memory_type
ORDER  BY ag.name, count DESC;
```

### Recent actions for the current agent

```sql
SET app.agent_id = '1';

SELECT id, action_type, requires_human_approval, approved_by, created_at
FROM   agent_actions
ORDER  BY created_at DESC
LIMIT  10;
```

### RLS isolation check

```sql
SET app.agent_id = '1';
-- Attempt to read agent 2's memories (should return 0 rows)
SELECT COUNT(*) FROM memories WHERE agent_id = 2;
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

SELECT COUNT(*) FROM agents;
-- Expected: 2

SELECT COUNT(*) FROM memories;
-- Expected: 8 (superuser sees all)

SELECT COUNT(*) FROM agent_actions;
-- Expected: 5

-- Pending approvals
SELECT COUNT(*) FROM agent_actions
WHERE requires_human_approval = TRUE AND approved_by IS NULL;
-- Expected: 1

-- vector extension present
SELECT extname FROM pg_extension WHERE extname = 'vector';

-- RLS enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE tablename IN ('memories','agent_actions');
```

## Practice tasks

1. **Add a memory and retrieve it.** Set `app.agent_id = '1'`. Insert a new
   memory about a topic of your choice with a hand-crafted embedding vector.
   Then run the similarity search query and verify your new memory appears near
   the top when you search with a similar vector.

2. **Action approval workflow.** Insert a new action with
   `requires_human_approval = TRUE`. Run the pending-approvals query. Approve it.
   Run the query again to confirm it no longer appears as pending.

3. **Cross-agent isolation.** Set `app.agent_id = '1'`. Try to SELECT memories
   where `agent_id = 2`. Confirm you get 0 rows. Then explain why this is safer
   than filtering in application code.

4. **Memory type breakdown.** Write a single query that returns, for each agent,
   the count of memories grouped by `memory_type`. Which agent has the most
   procedural memories?

5. **Extend the schema.** Add a `confidence FLOAT CHECK (confidence BETWEEN 0 AND 1)`
   column to `memories`. Update existing rows with plausible confidence values.
   Modify the similarity search to return only memories with `confidence > 0.7`.

## MCP and agent perspective

This schema is designed specifically for agent use via MCP:

- **Memory storage** — after each conversation turn, the agent INSERTs key facts
  and embeddings into `memories`. No code changes needed to add new memory types.
- **Semantic recall** — before responding, the agent queries `memories` with the
  current query embedding to retrieve relevant past context.
- **Action logging** — every tool call (web search, file write, API call) is
  recorded in `agent_actions` automatically. This provides a complete audit trail.
- **Human-in-the-loop** — high-risk actions (`requires_human_approval = TRUE`)
  are queued in `agent_actions` until a human approves them. The agent does not
  proceed until `approved_by IS NOT NULL`.
- **Multi-agent safety** — RLS prevents Agent A from reading or writing Agent B's
  memory, even if they share the same database.

## Teardown

```sql
DROP TABLE IF EXISTS agent_actions;
DROP TABLE IF EXISTS memories;
DROP TABLE IF EXISTS agents;
DROP EXTENSION IF EXISTS vector;
```

## References

- pgvector: https://github.com/pgvector/pgvector
- pgvector distance operators: https://github.com/pgvector/pgvector#distance
- Row-Level Security: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- JSONB: https://www.postgresql.org/docs/current/datatype-json.html
