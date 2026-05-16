# Agent Memory and Audit Trails
Level: Intermediate

## One-line intuition
Agents need memory to function across sessions, and PostgreSQL provides three memory types — episodic, semantic, procedural — each with appropriate storage, retrieval, and immutable audit protection.

## Why this exists
A stateless agent that forgets everything between calls cannot improve, cannot track prior actions, and cannot maintain context across a workflow. But agent memory stored in a database that can be tampered with is not trustworthy. The combination of structured memory tables, pgvector semantic search, and INSERT-only audit triggers solves both problems.

## First-principles explanation
Human memory has three well-studied types: **episodic** (specific events: "I called this API at 14:32"), **semantic** (general knowledge: "invoices over $10k require approval"), and **procedural** (how-to: "to close a ticket, first verify, then notify"). Each type needs different storage and retrieval:

- Episodic: timestamped rows, full-text searchable, append-only
- Semantic: vector embeddings (pgvector), nearest-neighbor search
- Procedural: structured rows with step sequences, versioned

The audit trail is separate from memory — it records what the agent *did* (actions), while memory records what the agent *knows* (state). Both must be immutable from the agent's perspective.

## Micro-concepts
- **Episodic memory**: what happened, when, in what context — rows with timestamps
- **Semantic memory**: what is known, as vector embeddings — pgvector similarity search
- **Procedural memory**: step-by-step how-to knowledge — ordered rows with a procedure_id
- **INSERT-only table**: a table with a trigger that raises an exception on UPDATE or DELETE
- **Audit trigger**: fires AFTER INSERT on any write table; records old/new JSONB
- **Retention policy**: archive old events to cold storage; never delete them
- **RLS on memory**: each agent sees only its own memory rows

## Beginner view
Think of agent memory as three notebooks: a diary (episodic — what I did), an encyclopedia (semantic — what I know), and a recipe book (procedural — how I do things). The audit trail is a notarized copy of every page you ever wrote, locked in a vault where you cannot edit or remove pages.

## Intermediate view
```sql
-- blocked: Docker not accessible

-- Episodic memory: what happened
CREATE TABLE agent_episodic_memory (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id    TEXT NOT NULL,
  event_type  TEXT NOT NULL,
  context     JSONB,
  summary     TEXT,
  happened_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Semantic memory: what is known (requires pgvector)
CREATE TABLE agent_semantic_memory (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id    TEXT NOT NULL,
  content     TEXT NOT NULL,
  embedding   vector(1536),
  source      TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ON agent_semantic_memory
  USING ivfflat (embedding vector_cosine_ops);

-- Procedural memory: how to do things
CREATE TABLE agent_procedural_memory (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id     TEXT NOT NULL,
  procedure    TEXT NOT NULL,
  step_number  INT NOT NULL,
  step_desc    TEXT NOT NULL,
  version      INT NOT NULL DEFAULT 1
);
```

## Advanced view
The INSERT-only audit trigger pattern:

```sql
-- blocked: Docker not accessible

CREATE TABLE agent_audit_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name  TEXT NOT NULL,
  operation   TEXT NOT NULL,
  agent_id    TEXT NOT NULL,
  old_data    JSONB,
  new_data    JSONB,
  logged_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Prevent any modification to the audit log
CREATE OR REPLACE FUNCTION enforce_audit_immutability()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'audit_log is INSERT-only: % is not permitted', TG_OP;
END;
$$;

CREATE TRIGGER no_audit_modification
BEFORE UPDATE OR DELETE ON agent_audit_log
FOR EACH ROW EXECUTE FUNCTION enforce_audit_immutability();

-- Generic audit trigger for any write table
CREATE OR REPLACE FUNCTION write_audit_log()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO agent_audit_log(table_name, operation, agent_id, old_data, new_data)
  VALUES (
    TG_TABLE_NAME,
    TG_OP,
    current_setting('app.agent_id', true),
    CASE WHEN TG_OP = 'DELETE' THEN row_to_json(OLD)::JSONB ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN row_to_json(NEW)::JSONB ELSE NULL END
  );
  RETURN NEW;
END;
$$;
```

## Mental model
Imagine a bank safety deposit box for the audit log: you can put items in (INSERT), but you cannot take them out or modify them (no UPDATE, no DELETE). Even the bank manager (superuser) would need to physically break the box to tamper with it — and that action itself would be visible.

Agent memory is a filing cabinet in the agent's office: the agent can read its own files, add new files, but cannot read other agents' cabinets (RLS). The audit log is the notary's record of every file the agent ever touched.

## PostgreSQL view
```sql
-- blocked: Docker not accessible

-- RLS: agents only see their own memory
ALTER TABLE agent_episodic_memory ENABLE ROW LEVEL SECURITY;

CREATE POLICY agent_sees_own_episodic ON agent_episodic_memory
  USING (agent_id = current_setting('app.agent_id'));

-- FTS on episodic memory
ALTER TABLE agent_episodic_memory
  ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (to_tsvector('english', coalesce(summary, '') || ' ' || coalesce(event_type, '')))
  STORED;

CREATE INDEX ON agent_episodic_memory USING GIN(search_vector);

-- Retrieve similar past events (semantic)
SELECT content, 1 - (embedding <=> $1::vector) AS similarity
FROM agent_semantic_memory
WHERE agent_id = current_setting('app.agent_id')
ORDER BY embedding <=> $1::vector
LIMIT 5;
```

## SQL view
Episodic memory uses standard timestamped INSERTs and FTS queries. Semantic memory uses pgvector's `<=>` cosine distance operator. Procedural memory is ordered by step_number with a WHERE procedure = $1. All three are RLS-protected.

## Non-SQL or hybrid view
Some systems store agent memory in vector databases (Pinecone, Weaviate) for the semantic layer and Redis for ephemeral episodic data. PostgreSQL with pgvector consolidates both into one ACID-compliant system, which is preferable when auditability matters more than raw retrieval speed.

## Design principle
**Memory and audit are separate concerns.** Memory is operational — the agent reads it to function. Audit is evidential — humans read it to verify. Never store audit evidence only in memory tables; always write to a separate INSERT-only audit table that the agent cannot read (RLS blocks it).

## Critical thinking
- What if the agent's embedding model changes? Old embeddings become incomparable to new ones. Store the model version alongside every embedding.
- What if episodic memory grows unboundedly? Archive rows older than a retention threshold to a cold storage table. Never DELETE them — archive moves rows, it does not remove them.
- What if an agent tries to read another agent's memory? RLS denies it with a "no rows returned" response — the policy is invisible to the agent, so it cannot tell if the memory exists or not. This is correct behavior.

## Creative thinking
Design a "memory consolidation" job that runs nightly: it reads all episodic memories from the past 24 hours, clusters similar ones, and inserts summarized entries into semantic memory. This mimics human sleep-based memory consolidation. The job itself is an agent, and its writes are audited like any other agent write.

## Systems thinking
Agent memory is a feedback loop: the agent reads memory to inform its next action, takes the action, which creates new episodic memory, which informs future actions. The audit trail sits outside this loop — it is a write-only side channel that records every state of the loop without participating in it.

## MCP and agent perspective
From the MCP perspective, memory access is itself a tool: `recall_recent_events(event_type, limit)`, `find_similar_knowledge(query_embedding)`, `get_procedure_steps(procedure_name)`. These tools never expose raw SQL to the agent — they return structured results, and the underlying implementation uses the memory tables above.

## Ontology perspective
Agent memory creates a **knowledge graph** in time: episodic nodes are events, semantic nodes are concepts, procedural nodes are workflows. Edges connect events to the concepts they demonstrated and the workflows they executed. The audit trail is a separate **provenance graph** — tracking who wrote what and when.

## Practice session
1. Create the three memory tables (episodic, semantic, procedural) with appropriate indexes.
2. Write the INSERT-only trigger that protects the audit log from modification.
3. Write a query that finds the 5 most semantically similar past events for a given embedding.
4. Write the RLS policy that prevents agent A from reading agent B's episodic memory.
5. Design a retention policy: after 90 days, episodic memory rows should move to an archive table. Write the SQL for the archive INSERT and the delete-from-live step, and explain why both must be in one transaction.

## References
- pgvector: https://github.com/pgvector/pgvector
- PostgreSQL Full Text Search: https://www.postgresql.org/docs/16/textsearch.html
- PostgreSQL Triggers: https://www.postgresql.org/docs/16/plpgsql-trigger.html
- Episodic/Semantic/Procedural memory: Tulving (1972), Squire (1992)
