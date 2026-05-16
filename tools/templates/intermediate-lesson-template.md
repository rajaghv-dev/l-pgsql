# <!-- TODO: fill in for this specific lesson -->

Level: Intermediate

> **Intermediate calibration rules:**
> - Assume the reader can write SELECT, INSERT, UPDATE, DELETE, and CREATE TABLE.
> - Emphasize design trade-offs and when to choose one approach over another.
> - Include EXPLAIN / EXPLAIN ANALYZE output and how to read it.
> - Cover performance implications: which operations are fast, which are slow, and why.
> - RLS, audit tables, and approval workflows are fair game at this level.
> - MCP/agent examples may include RLS, transactions, vector retrieval, audit writes.
> - Every major claim about performance should be verifiable with a local SQL test.

---

## One-line intuition

<!-- TODO: fill in for this specific lesson -->
One sentence that encodes the core trade-off or design insight.
Pattern: "X solves Y but costs Z — use it when the benefit outweighs the cost."

Example (partial indexes): "A partial index covers only the rows matching a WHERE clause — it is smaller, faster to maintain, and invisible to queries that don't match the condition."

---

## Why this exists

<!-- TODO: fill in for this specific lesson -->
Answer: "What specific design problem does this solve at intermediate scale?"

- What breaks at 10k–1M rows that worked fine at 100 rows?
- What schema design smell does this fix?
- What operational hazard does this prevent?
- When was this introduced in PostgreSQL and what motivated it?

---

## First-principles explanation

<!-- TODO: fill in for this specific lesson -->
Build from a known baseline (the beginner version of this concept).

1. Beginner baseline: "At the beginner level, you learned that X does Y."
2. The problem with the simple approach at scale: <!-- describe -->
3. The intermediate solution and why it works: <!-- describe -->
4. The cost or trade-off: <!-- describe -->

---

## Micro-concepts

<!-- TODO: fill in for this specific lesson -->
3–6 focused sub-concepts. Each links to a design decision or performance implication.

### Micro-concept 1: <!-- name -->

**What it is:** One sentence.
**Design implication:** One sentence about when you choose this vs. an alternative.
**Performance implication:** One sentence (fast/slow, reads/writes, scale boundary).

**Micro-practice:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: SQL demonstrating this micro-concept -->
"
```

**EXPLAIN it:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN ANALYZE <!-- TODO: same query with EXPLAIN ANALYZE -->;
"
```

**What to look for in EXPLAIN output:**
- `Seq Scan` vs. `Index Scan` — what it means here
- `cost=...` — what the estimated cost tells you
- `actual time=...` — how to interpret the actual timing

**Validation:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: system catalog query to verify the feature is active -->
"
```

**Design rule:** <!-- one-line rule for when to use this -->
**Anti-pattern:** <!-- one-line description of the mistake to avoid -->

---

### Micro-concept 2: <!-- name -->

<!-- repeat pattern above -->

---

## Beginner view

<!-- TODO: fill in for this specific lesson -->
One paragraph — quick recap for context. Do not duplicate the beginner lesson.

"If you are new to this topic, start with `concepts/beginner/<!-- file -->`.
The short version: <!-- one-sentence summary of beginner concept -->."

---

## Intermediate view

<!-- TODO: fill in for this specific lesson -->
This is the primary content at this level.

### Design trade-offs

| Approach | Advantage | Cost | Use when |
|----------|-----------|------|----------|
| <!-- A --> | <!-- advantage --> | <!-- cost --> | <!-- condition --> |
| <!-- B --> | <!-- advantage --> | <!-- cost --> | <!-- condition --> |

### Schema design angle

```sql
-- Well-designed schema for this topic
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: intermediate schema example -->
"
```

Why this design is better than the naive approach:
- <!-- reason 1 -->
- <!-- reason 2 -->

### Query planning angle

```bash
# Run EXPLAIN ANALYZE to see the plan
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
  <!-- TODO: query under analysis -->;
"
```

Key plan nodes to understand:
- `<!-- node type -->` — what it means and when to worry
- `<!-- node type -->` — what it means and when to worry

### RLS / audit angle

```sql
-- Example of applying RLS to this topic
docker exec cfp_postgres psql -U cfp -d cfp -c "
  ALTER TABLE <!-- table --> ENABLE ROW LEVEL SECURITY;

  CREATE POLICY <!-- policy_name --> ON <!-- table -->
    USING (<!-- condition -->);
"
```

Audit trigger pattern:
```sql
-- Record every write to this table
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE TABLE IF NOT EXISTS <!-- topic -->_audit (
    audit_id  BIGSERIAL PRIMARY KEY,
    op        TEXT NOT NULL,
    row_data  JSONB,
    changed_at TIMESTAMPTZ DEFAULT now(),
    changed_by TEXT DEFAULT current_user
  );

  CREATE OR REPLACE FUNCTION audit_<!-- topic -->()
  RETURNS TRIGGER LANGUAGE plpgsql AS \$\$
  BEGIN
    INSERT INTO <!-- topic -->_audit (op, row_data)
    VALUES (TG_OP, to_jsonb(NEW));
    RETURN NEW;
  END;
  \$\$;

  CREATE TRIGGER trg_audit_<!-- topic -->
    AFTER INSERT OR UPDATE OR DELETE ON <!-- table -->
    FOR EACH ROW EXECUTE FUNCTION audit_<!-- topic -->();
"
```

---

## Advanced view

<!-- TODO: fill in for this specific lesson -->
Brief pointer — one paragraph maximum.

"Deeper internals (MVCC visibility, buffer management, parallel execution) are covered in `concepts/advanced/<!-- file -->`.
At this stage, the key thing to understand is: <!-- one insight that bridges intermediate to advanced -->."

---

## Mental model

<!-- TODO: fill in for this specific lesson -->
A stable model for reasoning about trade-offs.

**The rule of thumb:** <!-- one sentence -->

**When it holds:** <!-- condition -->
**When it breaks:** <!-- edge case or scale limit -->

```
<!-- ASCII diagram illustrating the intermediate mental model -->
Write path: Client → [validation] → [constraint check] → [index update] → [WAL write] → Commit
Read path:  Client → [index scan] → [heap fetch] → [visibility check] → Result
```

---

## PostgreSQL view

<!-- TODO: fill in for this specific lesson -->
System catalog inspection relevant to this topic:

```bash
# Check configuration
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SHOW <!-- relevant_guc_parameter -->;
"

# Inspect system catalog
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT <!-- relevant columns -->
  FROM <!-- pg_class / pg_indexes / pg_policies / pg_stat_* -->
  WHERE <!-- filter -->;
"

# Check statistics
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT <!-- relevant columns -->
  FROM pg_stat_<!-- table or view -->
  WHERE relname = '<!-- table_name -->';
"
```

Relevant GUC parameters:
- `<!-- parameter -->` — what it controls, default value, when to change it
- `<!-- parameter -->` — what it controls, default value, when to change it

---

## SQL view

<!-- TODO: fill in for this specific lesson -->
Full syntax with all intermediate-relevant options:

```sql
-- Full syntax
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- SQL statement -->
    <!-- clause 1 -->   -- what it does and when to use it
    <!-- clause 2 -->   -- what it does and when to use it
    <!-- clause 3 -->   -- what it does and when to use it
"
```

Variants and when to choose each:
- `<!-- variant A -->` — use when <!-- condition -->
- `<!-- variant B -->` — use when <!-- condition -->

---

## Non-SQL or hybrid view

<!-- TODO: fill in for this specific lesson -->
How does this topic interact with JSONB, FTS, or vector search at the intermediate level?

```bash
# JSONB variant
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: JSONB / FTS / vector variant of this concept -->
"
```

Design decision: When to use the relational approach vs. the hybrid approach:
- Use relational when: <!-- condition -->
- Use JSONB when: <!-- condition -->
- Use hybrid when: <!-- condition -->

---

## Design principle

<!-- TODO: fill in for this specific lesson -->
The core design rule at intermediate level — usually a trade-off rule.

**Rule:** <!-- one-line statement of the principle -->

**Rationale:** <!-- two to three sentences explaining why this matters at scale -->

**Correct example:**
```sql
-- Do this at intermediate scale
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: correct intermediate SQL -->
"
```

**Counter-example:**
```sql
-- This seems fine but causes problems at 100k+ rows
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: anti-pattern SQL with comment explaining what breaks -->
"
```

**When to break this rule:** <!-- describe the justified exception -->

---

## Critical thinking

<!-- TODO: fill in for this specific lesson -->
Questions that require weighing trade-offs:

1. At what row count does the naive approach become unacceptable, and how would you measure it?
2. If you had to choose between <!-- approach A --> and <!-- approach B --> with no profiling data, what would guide your choice?
3. What schema change would be required to undo this decision, and what is the migration cost?
4. What does this design make impossible that was possible before?

---

## Creative thinking

<!-- TODO: fill in for this specific lesson -->
1. Could this feature solve a problem it was not designed for? What is the hidden use case?
2. If you could extend this PostgreSQL feature with one new clause, what would it be?
3. How would you explain the intermediate trade-offs to a junior developer in 2 minutes?

---

## Systems thinking

<!-- TODO: fill in for this specific lesson -->
Intermediate systems framing:

- **Upstream dependencies:** What must exist in the schema or config before this works?
- **Downstream effects:** What queries, indexes, triggers, or applications depend on this?
- **At 10x scale:** What breaks first and how would you detect it?
- **At 100x scale:** What architectural change becomes necessary?
- **Failure cascade:** If this fails, what else stops working?

---

## MCP and agent perspective

<!-- TODO: fill in for this specific lesson -->
Intermediate agent scenario with RLS and audit:

**Scenario:** <!-- e.g., "A multi-tenant agent that retrieves and writes documents scoped to a tenant" -->

- **State read:** <!-- what the agent reads -->
- **State written:** <!-- what the agent writes and its reversibility -->
- **MCP tool name:** `<!-- e.g., search_documents -->`
- **Tool input:** `{ "tenant_id": "...", "query": "...", "limit": 10 }`
- **PostgreSQL operations:**
  1. `SET app.tenant_id = '...'` — activate RLS context
  2. `SELECT ...` with RLS enforced automatically
- **Permission boundary:** Role `<!-- role_name -->`, RLS policy `<!-- policy_name -->`
- **Validation before execution:** Verify tenant_id is a valid UUID; reject wildcards
- **Audit event:** Written to `<!-- audit_table -->` via trigger, not by agent
- **Human approval required:** <!-- Yes/No/Conditional — describe -->
- **Failure mode:** <!-- describe what can go wrong -->
- **Recovery:** <!-- rollback / compensating transaction -->
- **Ontology connection:** `[[<!-- concept -->]]`

```bash
# Agent-safe pattern
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SET app.tenant_id = '42';
  SET app.agent_id = 'agent-xyz';
  -- RLS policy enforces tenant isolation automatically
  SELECT <!-- cols --> FROM <!-- table --> WHERE <!-- condition --> LIMIT 10;
"
```

---

## Ontology perspective

<!-- TODO: fill in for this specific lesson -->

- **Concept name:** <!-- TODO -->
- **Is a:** <!-- parent concept -->
- **Has parts:** <!-- child concepts -->
- **Related to:** <!-- sibling concepts — at same design level -->
- **Contrasts with:** <!-- opposing or alternative concept -->
- **Depends on:** <!-- prerequisite concepts -->

Obsidian links:
- `[[<!-- parent concept -->]]`
- `[[<!-- child concept 1 -->]]`
- `[[<!-- related concept -->]]`

---

## Practice session

```
practice/intermediate/<!-- topic-folder-name -->/
```

```bash
# Run setup
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/intermediate/<!-- topic-folder-name -->/setup.sql

# Validate
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: validation query showing tables and row counts -->
"
```

---

## References

<!-- TODO: fill in for this specific lesson -->

| Title | URL | Type | Level | Time |
|-------|-----|------|-------|------|
| PostgreSQL docs — <!-- topic --> | https://www.postgresql.org/docs/current/<!-- page --> | Official docs | Intermediate | 20 min |
| <!-- TODO: EXPLAIN / performance reference --> | <!-- URL --> | Blog | Intermediate | 10 min |
| <!-- TODO: design patterns reference --> | <!-- URL --> | Free book / article | Intermediate | 30 min |

> If a reference cannot be verified, write: `TODO: Find verified reference for this topic.`
