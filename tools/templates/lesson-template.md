# <!-- TODO: fill in for this specific lesson -->

Level: Beginner / Intermediate / Advanced

> **How to use this template:**
> Replace every `<!-- TODO: ... -->` comment with real content.
> Delete this instruction block when the lesson is complete.
> Keep sections short. Prefer links over long prose.
> Run every SQL block with: `docker exec cfp_postgres psql -U cfp -d cfp -c "..."`

---

## One-line intuition

<!-- TODO: fill in for this specific lesson -->
One sentence that makes the concept click immediately.
Write it as: "X is like Y, but for Z."

Example (indexes): "An index is like a book's back-matter index — you look up the word, get the page number, skip straight there instead of reading every page."

---

## Why this exists

<!-- TODO: fill in for this specific lesson -->
Answer the question: "What problem does this solve, and what was the world like before it existed?"

- What failure or pain does this prevent?
- What would you have to do manually without this feature?
- When did PostgreSQL add this, and why?

---

## First-principles explanation

<!-- TODO: fill in for this specific lesson -->
Build the concept from scratch. No assumed vocabulary. One step at a time.

1. Start with the raw problem.
2. Show the naive solution and why it breaks.
3. Show the correct solution.
4. Explain the trade-off.

Use a simple concrete example. Avoid jargon until you define it.

---

## Micro-concepts

<!-- TODO: fill in for this specific lesson -->
Break the topic into 3–7 atomic sub-concepts. Each micro-concept has:

### Micro-concept 1: <!-- name -->

**What it is:** One sentence.

**Why it matters:** One sentence.

**Micro-practice:**
```sql
-- Run this to see it in action
docker exec cfp_postgres psql -U cfp -d cfp -c "SELECT version();"
```

**Expected output:**
```
<!-- paste expected output here -->
```

**Validation query:**
```sql
-- Run this to confirm the micro-practice worked
docker exec cfp_postgres psql -U cfp -d cfp -c "<!-- TODO: validation SQL -->"
```

**Common error:** `<!-- TODO: common error message -->`
**Fix:** <!-- TODO: fix -->

**Ontology note:** This concept is a child of `<!-- parent concept -->`.

---

### Micro-concept 2: <!-- name -->

<!-- repeat pattern above -->

---

## Beginner view

<!-- TODO: fill in for this specific lesson -->
Explain as if talking to someone who knows how to write a SELECT statement but nothing else.

- Use everyday analogies (spreadsheets, filing cabinets, etc.)
- Show the simplest possible SQL that demonstrates the idea
- No internal PostgreSQL details yet

```sql
-- Simplest beginner example
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: beginner SQL example -->
"
```

---

## Intermediate view

<!-- TODO: fill in for this specific lesson -->
Explain trade-offs, design decisions, and configuration options.

- When should you use this vs. the alternative?
- What does EXPLAIN show?
- What configuration matters?
- How does this interact with indexes, transactions, or RLS?

```sql
-- Intermediate example with EXPLAIN
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN ANALYZE <!-- TODO: intermediate SQL example -->;
"
```

---

## Advanced view

<!-- TODO: fill in for this specific lesson -->
Explain internals, failure modes, and operational concerns.

- What happens at the page/buffer level?
- What are the failure modes at scale?
- What does the PostgreSQL source code / documentation say about limits?
- What does this look like in a production system?

---

## Mental model

<!-- TODO: fill in for this specific lesson -->
Give the reader a stable mental model to reason from. Options:

- An analogy that holds up under pressure
- A diagram (ASCII or Mermaid)
- A simple rule: "Think of X as always doing Y"

```
<!-- ASCII diagram if useful -->
Request → [step 1] → [step 2] → [step 3] → Result
```

---

## PostgreSQL view

<!-- TODO: fill in for this specific lesson -->
How does PostgreSQL specifically implement this?

- Which system catalog tables are involved? (`pg_class`, `pg_index`, `pg_stat_*`)
- Which configuration parameters control this? (`postgresql.conf`, `GUC`)
- Which version introduced or changed this?

```sql
-- Inspect the system catalog
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT <!-- TODO: catalog query -->;
"
```

---

## SQL view

<!-- TODO: fill in for this specific lesson -->
Show the full SQL syntax with all relevant options.

```sql
-- Full syntax example
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: full SQL syntax example -->
"
```

Key clauses:
- `CLAUSE_A` — what it does
- `CLAUSE_B` — what it does

---

## Non-SQL or hybrid view

<!-- TODO: fill in for this specific lesson -->
How does this topic relate to non-relational or hybrid approaches?

- JSONB angle: could you store this as document data instead?
- Full-text search angle: does this interact with `tsvector`?
- Vector angle: does this interact with `pgvector`?
- When would you use a hybrid approach?

```sql
-- JSONB / FTS / vector example if applicable
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: non-SQL or hybrid SQL example -->
"
```

---

## Design principle

<!-- TODO: fill in for this specific lesson -->
What is the core design rule this topic teaches?

**Rule:** <!-- one-line rule -->

**Rationale:** <!-- one paragraph explaining why this rule exists -->

**Correct example:**
```sql
-- Do this
<!-- TODO: correct SQL -->
```

**Counter-example:**
```sql
-- Not this — here is why
<!-- TODO: incorrect SQL with explanation -->
```

---

## Critical thinking

<!-- TODO: fill in for this specific lesson -->
Questions that push the reader to think harder:

1. What would break if this feature did not exist?
2. What is the hidden cost of using this feature?
3. When is NOT using this feature the right choice?

---

## Creative thinking

<!-- TODO: fill in for this specific lesson -->
Unusual or lateral applications:

1. Could you use this to solve a problem it was not designed for?
2. What would a 10x version of this feature look like?
3. How would you teach this to a non-technical stakeholder?

---

## Systems thinking

<!-- TODO: fill in for this specific lesson -->
How does this fit into larger systems?

- What upstream events trigger this operation?
- What downstream systems depend on the output?
- What happens at 10x scale? 100x?
- What is the cascade failure if this breaks?

---

## MCP and agent perspective

<!-- TODO: fill in for this specific lesson -->

What an AI agent needs to know about this topic:

- **State read:** What does the agent read to make a decision about this?
- **State written:** What does the agent write, and is it reversible?
- **MCP tool:** What would the MCP tool be named and what would it accept?
- **Must NOT expose:** What should never be surfaced to an agent?
- **Permission boundary:** What role or RLS policy is required?
- **Validation before execution:** What checks run before the agent acts?
- **Audit event:** What gets written to the audit log?
- **Human approval required:** Yes / No / Conditional — describe trigger
- **Failure mode:** What can go wrong?
- **Recovery / rollback:** How do you undo or compensate?
- **Ontology connection:** Which concept in the ontology graph does this link to?

```sql
-- Agent-safe query pattern example
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SET app.tenant_id = '1';
  SET app.agent_id = 'agent-xyz';
  <!-- TODO: agent-safe SQL -->
"
```

---

## Ontology perspective

<!-- TODO: fill in for this specific lesson -->

- **Concept name:** <!-- TODO -->
- **Is a:** <!-- parent concept -->
- **Has parts:** <!-- child concepts -->
- **Related to:** <!-- sibling concepts -->
- **Opposite of:** <!-- contrasting concept if any -->

Obsidian links for graph view:
- `[[<!-- parent concept -->]]`
- `[[<!-- child concept 1 -->]]`
- `[[<!-- child concept 2 -->]]`

---

## Practice session

Hands-on practice for this topic lives at:

```
practice/<!-- level -->/<!-- topic-folder-name -->/
```

Files in that folder:
- `README.md` — goals and overview
- `setup.sql` — creates tables, inserts seed data
- `00-setup-validation.md` — validates setup ran correctly
- `exercises.md` — step-by-step exercises
- `solutions.md` — full solutions with explanations
- `reflection.md` — thinking questions
- `ontology-notes.md` — concept map for this topic
- `troubleshooting.md` — common errors and fixes
- `references.md` — topic-specific references

Quick start:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -f /path/to/setup.sql
```

---

## References

<!-- TODO: fill in for this specific lesson -->

| Title | URL | Type | Level | Time |
|-------|-----|------|-------|------|
| PostgreSQL official docs — <!-- topic --> | https://www.postgresql.org/docs/current/<!-- page --> | Official docs | Beginner | 15 min |
| <!-- TODO: book or blog reference --> | <!-- URL --> | <!-- type --> | <!-- level --> | <!-- time --> |

> If a reference cannot be verified, write: `TODO: Find verified reference for this topic.`
