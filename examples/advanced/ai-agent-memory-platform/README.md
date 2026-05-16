# AI Agent Memory Platform Example

Level: Advanced
Domain: Full agent memory lifecycle — episodic, semantic, pending actions, and human approval
Synthetic data: Yes

## Overview

A production-oriented AI agent memory platform for a multi-agent system called
"AgentCore". This is the advanced companion to the intermediate `ai-agent-memory`
example. It adds:

- **Agent registry** with model metadata.
- **Episodic memory** — event-based memories with vector embeddings for semantic
  retrieval (what happened, when).
- **Semantic memory** — concept-level knowledge the agent has learned or was given
  (facts, rules, preferences).
- **Pending actions** — a human-in-the-loop approval queue. High-risk agent actions
  are staged here and must be approved before execution.
- **RLS by agent_id** — each agent can only read/write its own memory tables.
- **Vector similarity** — `pgvector` cosine distance for semantic recall across both
  memory types.

Schema note: `vector(3)` for demonstration. Real deployments use `vector(1536)`
(OpenAI) or `vector(768)` (Mistral/sentence-transformers).

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- for gen_random_uuid()

-- Agent registry
CREATE TABLE agents (
    id          SERIAL PRIMARY KEY,
    name        TEXT   NOT NULL UNIQUE,
    model       TEXT   NOT NULL,       -- e.g. 'claude-sonnet-4-6', 'gpt-4o'
    description TEXT   NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Episodic memory: what happened, when, with a vector for semantic retrieval
CREATE TABLE episodic_memory (
    id          BIGSERIAL PRIMARY KEY,
    agent_id    INT         NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    content     TEXT        NOT NULL,
    embedding   VECTOR(3)   NOT NULL,   -- demo: 3-dim; production: 1536-dim
    metadata    JSONB       NOT NULL DEFAULT '{}',
    -- metadata can include: {"session_id": "...", "user_id": "...", "importance": 0.8}
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_episodic_agent_id  ON episodic_memory (agent_id, created_at DESC);
CREATE INDEX idx_episodic_embedding ON episodic_memory
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 1);

-- Semantic memory: concepts, facts, rules the agent knows
CREATE TABLE semantic_memory (
    id          BIGSERIAL PRIMARY KEY,
    agent_id    INT         NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    concept     TEXT        NOT NULL,          -- e.g. "user preference: dark mode"
    description TEXT        NOT NULL DEFAULT '',
    embedding   VECTOR(3)   NOT NULL,
    confidence  FLOAT       NOT NULL DEFAULT 1.0
                            CHECK (confidence BETWEEN 0 AND 1),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_semantic_agent_id  ON semantic_memory (agent_id);
CREATE INDEX idx_semantic_embedding ON semantic_memory
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 1);
CREATE INDEX idx_semantic_concept   ON semantic_memory (agent_id, concept);

-- Pending actions: human-in-the-loop approval queue
CREATE TABLE pending_actions (
    id                      BIGSERIAL PRIMARY KEY,
    agent_id                INT         NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    action_type             TEXT        NOT NULL,
    payload                 JSONB       NOT NULL DEFAULT '{}',
    requires_human_approval BOOLEAN     NOT NULL DEFAULT FALSE,
    status                  TEXT        NOT NULL DEFAULT 'pending'
                                        CHECK (status IN ('pending','approved','rejected','executed')),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_by             TEXT,       -- human reviewer identifier
    reviewed_at             TIMESTAMPTZ
);

CREATE INDEX idx_actions_agent_id  ON pending_actions (agent_id, created_at DESC);
CREATE INDEX idx_actions_status    ON pending_actions (status) WHERE status = 'pending';

-- RLS: each agent can only see its own memory rows
ALTER TABLE episodic_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE semantic_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE pending_actions ENABLE ROW LEVEL SECURITY;

CREATE POLICY episodic_agent_isolation ON episodic_memory
    USING (agent_id = current_setting('app.agent_id', TRUE)::INT);

CREATE POLICY semantic_agent_isolation ON semantic_memory
    USING (agent_id = current_setting('app.agent_id', TRUE)::INT);

CREATE POLICY actions_agent_isolation ON pending_actions
    USING (agent_id = current_setting('app.agent_id', TRUE)::INT);
```

## Seed data

```sql
-- Agent registry
INSERT INTO agents (name, model, description) VALUES
  ('ResearchBot',  'claude-sonnet-4-6',
   'Research and summarisation agent for internal knowledge base queries.'),
  ('PlannerBot',   'claude-sonnet-4-6',
   'Project planning, task decomposition, and scheduling agent.'),
  ('GuardBot',     'claude-haiku-4-5',
   'Low-latency safety and content moderation agent.');

-- ---- ResearchBot (agent_id=1) episodic memories ----
SET app.agent_id = '1';

INSERT INTO episodic_memory (agent_id, content, embedding, metadata) VALUES
  (1,
   'User (alice@acme.example) asked for a summary of the Q3 performance report on 2024-06-10. '
   'Returned 5-paragraph summary. User rated it 5/5.',
   '[0.8, 0.3, 0.2]',
   '{"session_id": "sess-001", "user_id": "alice@acme.example", "importance": 0.9}'),

  (1,
   'Searched knowledge base for "GDPR Article 17 right to erasure". Found 3 relevant documents. '
   'Top result: internal legal memo from 2023-11-01.',
   '[0.5, 0.7, 0.1]',
   '{"session_id": "sess-002", "user_id": "bob@acme.example", "importance": 0.7}'),

  (1,
   'Attempted to access restricted document DOC-9001. Access denied. Logged for audit.',
   '[0.3, 0.4, 0.8]',
   '{"session_id": "sess-003", "user_id": "eve@acme.example", "importance": 1.0, "flag": "access_denied"}');

-- ---- ResearchBot (agent_id=1) semantic memories ----
INSERT INTO semantic_memory (agent_id, concept, description, embedding, confidence) VALUES
  (1,
   'user_preference:summary_length',
   'Alice prefers concise summaries of 200-300 words. Longer summaries receive lower ratings.',
   '[0.7, 0.6, 0.1]',
   0.92),

  (1,
   'domain_knowledge:gdpr',
   'GDPR Article 17 grants data subjects the right to request erasure of personal data under '
   'specific conditions. Retention obligations can override erasure requests.',
   '[0.4, 0.8, 0.2]',
   0.98),

  (1,
   'operational_rule:access_control',
   'Do not attempt to access documents with classification RESTRICTED without explicit '
   'user consent and a valid reason logged in the session.',
   '[0.2, 0.3, 0.9]',
   1.0);

-- ---- PlannerBot (agent_id=2) episodic memories ----
SET app.agent_id = '2';

INSERT INTO episodic_memory (agent_id, content, embedding, metadata) VALUES
  (2,
   'Created sprint plan for Project Lighthouse. 12 tasks decomposed across 3 engineers. '
   'Sprint duration: 2 weeks starting 2024-06-17.',
   '[0.6, 0.5, 0.4]',
   '{"session_id": "sess-101", "project": "lighthouse", "importance": 0.8}'),

  (2,
   'Rescheduled 3 tasks after Carol Jenkins reported sick leave until 2024-06-21. '
   'Reassigned tasks T-1012, T-1015, T-1019 to David Park.',
   '[0.5, 0.6, 0.5]',
   '{"session_id": "sess-102", "project": "lighthouse", "importance": 0.85}');

INSERT INTO semantic_memory (agent_id, concept, description, embedding, confidence) VALUES
  (2,
   'team_rule:task_size',
   'Tasks should not exceed 4 story points. Anything larger must be decomposed into subtasks.',
   '[0.3, 0.7, 0.6]',
   0.95),

  (2,
   'user_preference:sprint_length',
   'David Park prefers 2-week sprints with a mid-sprint check-in on Wednesdays.',
   '[0.4, 0.5, 0.7]',
   0.88);

-- ---- Pending actions ----
SET app.agent_id = '1';

INSERT INTO pending_actions (agent_id, action_type, payload, requires_human_approval, status) VALUES
  -- Low-risk: no approval needed
  (1, 'knowledge_base_search',
   '{"query": "GDPR data retention", "max_results": 5}',
   FALSE, 'executed'),

  -- Medium-risk: auto-approved
  (1, 'document_summarise',
   '{"document_id": "DOC-0042", "max_words": 250}',
   FALSE, 'executed'),

  -- High-risk: requires human approval (pending)
  (1, 'external_api_call',
   '{"endpoint": "https://api.acme.example/legal/erasure-request",
     "method": "POST",
     "body": {"subject_id": "user-9912", "reason": "user_request"}}',
   TRUE, 'pending'),

  -- High-risk: already approved
  (1, 'file_write',
   '{"path": "/reports/gdpr-audit-2024.md", "content_hash": "sha256:abc123"}',
   TRUE, 'approved');

UPDATE pending_actions
SET    reviewed_by  = 'compliance-officer@acme.example',
       reviewed_at  = NOW() - INTERVAL '30 minutes',
       status       = 'approved'
WHERE  action_type  = 'file_write'
  AND  status       = 'pending';

SET app.agent_id = '2';

INSERT INTO pending_actions (agent_id, action_type, payload, requires_human_approval, status) VALUES
  (2, 'calendar_event_create',
   '{"title": "Sprint Review - Project Lighthouse", "attendees": ["carol@acme.example","david@acme.example"],
     "start": "2024-06-28T14:00:00Z", "duration_minutes": 60}',
   TRUE, 'pending');
```

## Example queries

### Semantic similarity search across episodic memory

```sql
SET app.agent_id = '1';

-- Find episodic memories semantically similar to a query about security incidents
SELECT id,
       LEFT(content, 100)                         AS memory_snippet,
       metadata->>'importance'                    AS importance,
       embedding <=> '[0.25, 0.35, 0.85]'        AS cosine_distance
FROM   episodic_memory
WHERE  agent_id = 1
ORDER  BY cosine_distance
LIMIT  5;
```

### Retrieve semantic memories above a confidence threshold

```sql
SET app.agent_id = '1';

SELECT concept, description, confidence
FROM   semantic_memory
WHERE  agent_id   = 1
  AND  confidence >= 0.90
ORDER  BY confidence DESC;
```

### Combined episodic + semantic retrieval (UNION)

```sql
SET app.agent_id = '1';

WITH ep AS (
    SELECT 'episodic'  AS memory_type,
           id,
           content,
           embedding <=> '[0.4, 0.75, 0.15]' AS distance,
           created_at::TIMESTAMPTZ            AS ts
    FROM   episodic_memory
    WHERE  agent_id = 1
),
sem AS (
    SELECT 'semantic'  AS memory_type,
           id,
           description AS content,
           embedding <=> '[0.4, 0.75, 0.15]' AS distance,
           updated_at                         AS ts
    FROM   semantic_memory
    WHERE  agent_id = 1
)
SELECT memory_type, id, LEFT(content, 80) AS snippet, ROUND(distance::NUMERIC, 4) AS distance
FROM   (SELECT * FROM ep UNION ALL SELECT * FROM sem) all_mem
ORDER  BY distance
LIMIT  10;
```

### Pending actions queue (admin view — bypasses RLS)

```sql
-- This query is for a human operator dashboard; uses superuser/BYPASSRLS access
SELECT pa.id,
       a.name         AS agent_name,
       pa.action_type,
       pa.status,
       pa.requires_human_approval,
       pa.reviewed_by,
       pa.created_at
FROM   pending_actions pa
JOIN   agents          a  ON a.id = pa.agent_id
WHERE  pa.requires_human_approval = TRUE
ORDER  BY pa.status, pa.created_at;
```

### Approve a pending action

```sql
-- As human operator (must use BYPASSRLS or superuser to cross agent boundary)
UPDATE pending_actions
SET    status       = 'approved',
       reviewed_by  = 'ops-team@acme.example',
       reviewed_at  = NOW()
WHERE  id = 3
  AND  status = 'pending'
  AND  requires_human_approval = TRUE;
```

### Reject a pending action with a note in payload

```sql
UPDATE pending_actions
SET    status      = 'rejected',
       reviewed_by = 'compliance-officer@acme.example',
       reviewed_at = NOW(),
       payload     = payload || '{"rejection_reason": "erasure request requires DPO sign-off first"}'::JSONB
WHERE  id = 3
  AND  status = 'pending';
```

### Agent memory summary (admin dashboard)

```sql
SELECT a.name,
       COUNT(DISTINCT ep.id)  AS episodic_count,
       COUNT(DISTINCT sm.id)  AS semantic_count,
       COUNT(DISTINCT pa.id) FILTER (WHERE pa.status = 'pending' AND pa.requires_human_approval)
                              AS pending_approvals
FROM   agents         a
LEFT   JOIN episodic_memory ep ON ep.agent_id = a.id
LEFT   JOIN semantic_memory sm ON sm.agent_id = a.id
LEFT   JOIN pending_actions pa ON pa.agent_id = a.id
GROUP  BY a.id, a.name
ORDER  BY a.name;
```

### Upsert a semantic memory (update if concept exists, insert if not)

```sql
SET app.agent_id = '1';

INSERT INTO semantic_memory (agent_id, concept, description, embedding, confidence)
VALUES (
    1,
    'user_preference:summary_length',
    'Alice now prefers summaries of 150-200 words after feedback session on 2024-06-15.',
    '[0.7, 0.6, 0.1]',
    0.95
)
ON CONFLICT DO NOTHING;
-- For a real upsert by (agent_id, concept), add a UNIQUE constraint and use
-- ON CONFLICT (agent_id, concept) DO UPDATE SET ...
```

### Cross-agent isolation check

```sql
SET app.agent_id = '1';

-- PlannerBot's memories are not visible to ResearchBot
SELECT COUNT(*) FROM episodic_memory WHERE agent_id = 2;
-- Expected: 0 (RLS filters to agent_id = 1 only)
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

SELECT COUNT(*) FROM agents;
-- Expected: 3

SELECT COUNT(*) FROM episodic_memory;
-- Expected: 5 (superuser)

SELECT COUNT(*) FROM semantic_memory;
-- Expected: 5 (superuser)

SELECT COUNT(*) FROM pending_actions;
-- Expected: 6 (superuser)

-- Pending approvals count
SELECT COUNT(*) FROM pending_actions
WHERE status = 'pending' AND requires_human_approval = TRUE;
-- Expected: 2

-- RLS enabled
SELECT tablename, rowsecurity FROM pg_tables
WHERE tablename IN ('episodic_memory','semantic_memory','pending_actions');

-- Extensions present
SELECT extname FROM pg_extension WHERE extname IN ('vector','pgcrypto');

-- Vector search returns ordered results
SET app.agent_id = '1';
SELECT id, embedding <=> '[0.7, 0.6, 0.1]' AS dist
FROM episodic_memory ORDER BY dist LIMIT 3;
```

## Practice tasks

1. **Memory retrieval workflow.** Set `app.agent_id = '1'`. Insert a new episodic
   memory about a conversation where the user asked about data privacy. Choose a
   meaningful 3-dim embedding. Run the cosine-distance query to verify it surfaces
   near the top for a related query vector.

2. **Confidence decay.** Write an UPDATE that reduces the `confidence` of all semantic
   memories for agent 1 by 5% where `updated_at < NOW() - INTERVAL '30 days'`. This
   simulates memory staleness. What happens to memories that would go below 0? Add a
   CHECK constraint to prevent it.

3. **Human approval queue.** As a human operator (using a superuser session), run the
   pending-actions admin query. Approve the calendar event creation for PlannerBot.
   Verify the row shows `status = 'approved'` and `reviewed_by` is set.

4. **UNIQUE constraint for semantic memory.** Add a `UNIQUE (agent_id, concept)`
   constraint to `semantic_memory`. Re-run the upsert example using
   `ON CONFLICT (agent_id, concept) DO UPDATE SET description = EXCLUDED.description,
   confidence = EXCLUDED.confidence, updated_at = NOW()`. Verify the existing row
   is updated rather than duplicated.

5. **Memory lifecycle.** Design and implement a `memory_archive` table that stores
   episodic memories older than 90 days, compressed (just id, agent_id, summary TEXT,
   original_embedding). Write a query that moves old memories to the archive using a
   CTE with DELETE RETURNING. Why might you archive rather than delete?

## MCP and agent perspective

This schema implements the full agent memory lifecycle:

- **Every conversation turn** → INSERT into `episodic_memory` with the conversation
  summary and an embedding from the current turn.
- **Before each response** → vector similarity search across episodic + semantic
  memory to retrieve relevant context (k-NN query).
- **When learning a new fact** → UPSERT into `semantic_memory` with updated confidence.
- **Before high-risk actions** → INSERT into `pending_actions` with
  `requires_human_approval = TRUE`. Agent pauses and polls for `status = 'approved'`
  before proceeding.
- **RLS enforces separation** — Agent A literally cannot read Agent B's memories,
  even if its prompt is manipulated to try.
- **Human operator dashboard** — a separate BYPASSRLS session aggregates
  `pending_actions` across all agents for the compliance team.

The approval workflow is the critical safety mechanism: high-risk actions (external API
calls, file writes, data deletions) cannot execute until a human signs off in the database.

## Teardown

```sql
DROP TABLE IF EXISTS pending_actions;
DROP TABLE IF EXISTS semantic_memory;
DROP TABLE IF EXISTS episodic_memory;
DROP TABLE IF EXISTS agents;
DROP EXTENSION IF EXISTS pgcrypto;
DROP EXTENSION IF EXISTS vector;
```

## References

- pgvector: https://github.com/pgvector/pgvector
- IVFFlat index tuning: https://github.com/pgvector/pgvector#ivfflat
- Row-Level Security: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- JSONB operators: https://www.postgresql.org/docs/current/functions-json.html
- Human-in-the-loop AI safety: https://en.wikipedia.org/wiki/Human-in-the-loop
- pgcrypto gen_random_uuid: https://www.postgresql.org/docs/current/pgcrypto.html
