# <!-- TODO: fill in for this specific lesson -->

Level: Beginner

> **Beginner calibration rules:**
> - Lead with intuition and everyday analogies. No internal PostgreSQL details.
> - Every SQL block must be runnable immediately with the local setup.
> - Every micro-concept must have a micro-practice with a validation query.
> - Skip EXPLAIN internals, MVCC, and buffer-level details — link to intermediate instead.
> - MCP/agent examples stay simple: search notes, create a task, update status, log an action.
> - Keep each section to 3–8 sentences. Prefer a link over a paragraph.

---

## One-line intuition

<!-- TODO: fill in for this specific lesson -->
One sentence. Make it click like a lightbulb.
Pattern: "X is like [familiar everyday thing], but for [database context]."

Example: "A table is like a spreadsheet tab — rows are records, columns are fields, but the database enforces the rules automatically."

---

## Why this exists

<!-- TODO: fill in for this specific lesson -->
Answer: "What problem does this solve?"
Use a pain-point story, not a textbook definition.

- What would break or be painful without this?
- Who was suffering before this existed?
- What does PostgreSQL do automatically so you don't have to?

---

## First-principles explanation

<!-- TODO: fill in for this specific lesson -->
Build the concept from zero. Assume the reader knows basic SQL SELECT.

Step 1 — the problem without this feature:
Step 2 — the naive manual workaround:
Step 3 — why the naive workaround breaks:
Step 4 — how this feature solves it cleanly:

Use a concrete tiny example (3–5 rows, 2–3 columns).

---

## Micro-concepts

<!-- TODO: fill in for this specific lesson -->
Break the topic into 2–4 atomic pieces. Each must be learnable in under 5 minutes.

### Micro-concept 1: <!-- name -->

**What it is:** One sentence.
**Everyday analogy:** <!-- analogy -->
**Why it matters for a beginner:** One sentence.

**Micro-practice — run this now:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: simplest possible SQL to show this concept -->
"
```

**Expected output:**
```
<!-- TODO: paste actual expected output -->
```

**Validation — confirm it worked:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: SELECT that verifies the micro-practice ran correctly -->
"
```

**What you should see:** <!-- one line describing success output -->

**If it fails:** <!-- TODO: most common beginner error and fix -->

---

### Micro-concept 2: <!-- name -->

<!-- repeat pattern above -->

---

## Beginner view

<!-- TODO: fill in for this specific lesson -->
This is the main beginner explanation. Keep it grounded.

- Use a running example with a simple, relatable scenario (tasks, notes, products, users).
- Show the SQL in full — do not abbreviate.
- Call out any syntax that looks surprising and explain it.

```bash
# Create a simple table to experiment with
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE TABLE IF NOT EXISTS <!-- TODO: table name --> (
    id SERIAL PRIMARY KEY,
    <!-- TODO: columns -->
  );
"

# Insert a couple of rows
docker exec cfp_postgres psql -U cfp -d cfp -c "
  INSERT INTO <!-- TODO: table --> VALUES <!-- TODO: values -->;
"

# Query it
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT * FROM <!-- TODO: table -->;
"
```

---

## Intermediate view

<!-- TODO: fill in for this specific lesson -->
Brief pointer only — do not duplicate intermediate content here.

"When you are comfortable with the basics, explore:
- <!-- trade-off or design decision to investigate next -->
- See: `concepts/intermediate/<!-- file -->` for deeper coverage."

---

## Advanced view

<!-- TODO: fill in for this specific lesson -->
One sentence pointer only.

"Advanced topics (internals, performance forensics, failure modes) are covered in `concepts/advanced/<!-- file -->`."

---

## Mental model

<!-- TODO: fill in for this specific lesson -->
Give the beginner one sticky analogy they can carry forward.

The rule: "Always think of <!-- concept --> as <!-- analogy -->."

This works because:
- <!-- reason 1 -->
- <!-- reason 2 -->

This breaks down when: <!-- edge case — note it so they are not surprised later -->

---

## PostgreSQL view

<!-- TODO: fill in for this specific lesson -->
Show the beginner one system catalog query so they can see the feature is real.

```bash
# See it in the system catalog
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: simple pg_class / pg_tables / information_schema query -->
"
```

Keep this brief. Do not dive into GUC parameters or `postgresql.conf` — link to intermediate.

---

## SQL view

<!-- TODO: fill in for this specific lesson -->
Show the most common SQL syntax for this topic. Label each part.

```sql
-- Full pattern (run via docker exec as shown above)
<!-- keyword --> <!-- object_name -->    -- what this word does
  <!-- clause_1 -->                      -- what this clause does
  <!-- clause_2 -->                      -- what this clause does
;
```

Common mistakes beginners make:
- Forgetting `<!-- TODO: syntax detail -->` — causes `<!-- TODO: error -->`
- Using `<!-- TODO: wrong approach -->` — use `<!-- TODO: correct approach -->` instead

---

## Non-SQL or hybrid view

<!-- TODO: fill in for this specific lesson -->
One paragraph. Show a simple JSONB or array example only if directly relevant.
Otherwise: "This concept is primarily relational. JSONB and hybrid angles are covered at intermediate level."

---

## Design principle

<!-- TODO: fill in for this specific lesson -->
The one rule a beginner should always follow with this topic.

**Rule:** <!-- one sentence -->

**Do this:**
```sql
<!-- TODO: correct beginner SQL -->
```

**Not this:**
```sql
-- This works but causes problems later — here is why
<!-- TODO: anti-pattern SQL with inline comment explaining the problem -->
```

---

## Critical thinking

<!-- TODO: fill in for this specific lesson -->
Keep to 2–3 questions appropriate for a beginner:

1. What would go wrong if you skipped this step?
2. Can you think of a real situation where you would need this?
3. What question does this raise that you don't know how to answer yet?

---

## Creative thinking

<!-- TODO: fill in for this specific lesson -->
1. Can you use this for something it was not obviously designed for?
2. How would you explain this concept to a friend who has never touched a database?

---

## Systems thinking

<!-- TODO: fill in for this specific lesson -->
Keep simple at beginner level:

- What is upstream of this (what has to exist first)?
- What is downstream (what depends on this)?
- What breaks if this step is skipped?

---

## MCP and agent perspective

<!-- TODO: fill in for this specific lesson -->
Beginner agent scenario — keep it simple:

**Scenario:** An AI assistant that manages a task list for a user.

- **What the agent does with this concept:** <!-- e.g., "the agent INSERTs a new task when the user says 'add task'" -->
- **MCP tool name:** `<!-- e.g., create_task -->`
- **Tool input:** `{ "title": "...", "due_date": "..." }`
- **PostgreSQL operation:** `INSERT INTO tasks (...) VALUES (...)`
- **Validation before execution:** Check that required fields are non-null
- **Audit log entry:** `agent created task #<id> at <timestamp>`
- **What must NOT be exposed:** Internal IDs of other users' tasks
- **Failure mode:** Duplicate task — use `ON CONFLICT` or check first

```bash
# What the agent's INSERT looks like
docker exec cfp_postgres psql -U cfp -d cfp -c "
  INSERT INTO <!-- TODO: table --> (<!-- cols -->) VALUES (<!-- values -->)
  RETURNING id;
"
```

---

## Ontology perspective

<!-- TODO: fill in for this specific lesson -->

- **Concept name:** <!-- TODO -->
- **Is a:** <!-- parent concept, e.g., "database object" -->
- **Has parts:** <!-- child concepts if any -->
- **Related to:** <!-- sibling concepts -->

Obsidian links:
- `[[<!-- parent -->]]`
- `[[<!-- related 1 -->]]`

---

## Practice session

Hands-on exercises for this topic:

```
practice/beginner/<!-- topic-folder-name -->/
```

Start here:
```bash
# Run setup
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/<!-- topic-folder-name -->/setup.sql

# Verify setup
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: validation query -->;
"
```

---

## References

<!-- TODO: fill in for this specific lesson -->

| Title | URL | Type | Level | Time |
|-------|-----|------|-------|------|
| PostgreSQL Tutorial — <!-- topic --> | https://www.postgresqltutorial.com/<!-- page --> | Tutorial | Beginner | 10 min |
| PostgreSQL official docs — <!-- topic --> | https://www.postgresql.org/docs/current/<!-- page --> | Official docs | Beginner | 15 min |

> If a reference cannot be verified, write: `TODO: Find verified reference for this topic.`
