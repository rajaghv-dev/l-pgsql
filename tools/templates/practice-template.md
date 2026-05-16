# Practice Session Template

> **How to use this file:**
> This template shows what each file in a practice folder should contain.
> When creating a new practice session at `practice/<level>/<topic>/`:
> 1. Copy the content blocks below into their respective files.
> 2. Replace every `<!-- TODO: ... -->` with real content.
> 3. Run and validate every SQL block before committing.
> 4. Level: Beginner / Intermediate / Advanced — delete the levels that do not apply.

---

## File: README.md

```markdown
# Practice: <!-- Topic Name -->

Level: Beginner / Intermediate / Advanced
Estimated time: <!-- e.g., 30–45 minutes -->
Concept file: `concepts/<!-- level -->/<!-- lesson-file.md -->`

## Goals

By the end of this session you will be able to:

1. <!-- goal 1 — measurable action verb: "write a query that...", "create a ... that...", "explain why..." -->
2. <!-- goal 2 -->
3. <!-- goal 3 -->

## Prerequisites

- [ ] Completed: `concepts/<!-- level -->/<!-- prerequisite-lesson -->.md`
- [ ] PostgreSQL container is running: `docker ps | grep cfp_postgres`
- [ ] Database is accessible: `docker exec cfp_postgres psql -U cfp -d cfp -c "SELECT 1"`

## Files in this folder

| File | Purpose |
|------|---------|
| `setup.sql` | Creates tables and inserts seed data |
| `00-setup-validation.md` | Validates that setup ran correctly |
| `exercises.md` | Step-by-step exercises |
| `solutions.md` | Full solutions with explanations |
| `reflection.md` | Thinking questions after the exercises |
| `ontology-notes.md` | Concept map for this topic |
| `troubleshooting.md` | Common errors and fixes |
| `references.md` | Topic-specific references |

## Quick start

```bash
# 1. Run setup
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/<!-- level -->/<!-- topic -->/setup.sql

# 2. Validate setup
# See 00-setup-validation.md

# 3. Open exercises.md and begin
```
```

---

## File: setup.sql

```sql
-- Practice: <!-- Topic Name -->
-- Level: Beginner / Intermediate / Advanced
-- Purpose: Creates the tables and seed data for this practice session.
-- Run with: docker exec cfp_postgres psql -U cfp -d cfp -f /path/to/setup.sql

-- ─── Tear down (idempotent re-run) ────────────────────────────────────────────
DROP TABLE IF EXISTS <!-- table_name --> CASCADE;
-- DROP TYPE / DROP FUNCTION / DROP EXTENSION IF NOT EXISTS as needed

-- ─── Extensions (if needed) ───────────────────────────────────────────────────
-- CREATE EXTENSION IF NOT EXISTS <!-- extension_name -->;

-- ─── Schema ───────────────────────────────────────────────────────────────────
CREATE TABLE <!-- table_name --> (
    id          SERIAL PRIMARY KEY,
    <!-- col1 --> <!-- type -->  NOT NULL,
    <!-- col2 --> <!-- type -->  DEFAULT <!-- default -->,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE <!-- table_name --> IS '<!-- one-line purpose -->';
COMMENT ON COLUMN <!-- table_name -->.<!-- col1 --> IS '<!-- one-line description -->';

-- ─── Seed data (synthetic only — no real personal data) ───────────────────────
INSERT INTO <!-- table_name --> (<!-- col1 -->, <!-- col2 -->)
VALUES
    ('<!-- val1a -->', <!-- val1b -->),
    ('<!-- val2a -->', <!-- val2b -->),
    ('<!-- val3a -->', <!-- val3b -->);

-- ─── Indexes (if the exercise covers indexing) ────────────────────────────────
-- CREATE INDEX idx_<!-- table -->_<!-- col --> ON <!-- table --> (<!-- col -->);

-- ─── Verification ─────────────────────────────────────────────────────────────
DO $$
BEGIN
    ASSERT (SELECT COUNT(*) FROM <!-- table_name -->) >= 3,
        'Seed data missing — expected at least 3 rows in <!-- table_name -->';
    RAISE NOTICE 'setup.sql: OK — % rows in <!-- table_name -->',
        (SELECT COUNT(*) FROM <!-- table_name -->);
END;
$$;
```

---

## File: 00-setup-validation.md

```markdown
# Setup Validation: <!-- Topic Name -->

Run each check after executing `setup.sql`. All checks must pass before starting exercises.

---

## Check 1: Table exists

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT table_name, table_type
  FROM information_schema.tables
  WHERE table_schema = 'public' AND table_name = '<!-- table_name -->';
"
```

**Expected output:**
```
  table_name   | table_type
---------------+------------
 <!-- table --> | BASE TABLE
```

**Why this exists:** Confirms `setup.sql` ran without error.
**Common error:** `relation "<!-- table -->" does not exist` — setup.sql did not complete. Re-run it.
**Ontology note:** A table is a named, typed, persistent relation. `[[table]]` → `[[relation]]`

---

## Check 2: Row count

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT COUNT(*) AS row_count FROM <!-- table_name -->;
"
```

**Expected output:**
```
 row_count
-----------
         <!-- expected count -->
```

**Why this exists:** Confirms seed data was inserted.
**Common error:** `0 rows` — INSERT block in setup.sql failed silently. Check for constraint violations.

---

## Check 3: <!-- Optional: extension / index / column -->

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: additional validation query -->
"
```

**Expected output:**
```
<!-- expected output -->
```

---

## Setup passed

If all checks above show expected output, setup is complete.
Open `exercises.md` and begin.
```

---

## File: exercises.md

```markdown
# Exercises: <!-- Topic Name -->

Level: Beginner / Intermediate / Advanced

Work through each exercise in order. Do not look at `solutions.md` until you have tried.

---

## Exercise 1: <!-- Exercise title -->

**Goal:** <!-- What the learner will accomplish -->

**First-principles question:** <!-- Why does this exercise exist? What deeper concept does it reveal? -->

**Setup:** (if extra setup beyond setup.sql is needed)
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- extra setup SQL if needed -->
"
```

**Task:** <!-- Precise description of what to do -->

**Hint:** <!-- One sentence that nudges without giving away the answer -->

**Your SQL:**
```sql
-- Write your solution here
```

**Expected result:**
```
<!-- paste what the correct output looks like -->
```

**Validation query:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- a query that confirms the exercise result is correct -->
"
```

**Critical-thinking question:** <!-- Something that makes them question an assumption -->

**Creative-thinking question:** <!-- An unusual or lateral application -->

**Systems-thinking question:** <!-- How does this fit into a larger system? -->

**Ontology-thinking question:** <!-- How does this concept relate to the concept map? -->

**Agent/MCP angle:**
- Agent scenario: <!-- e.g., "An agent needs to find all overdue tasks for a user" -->
- MCP tool name: `<!-- e.g., get_overdue_tasks -->`
- Tool input: `{ "user_id": "..." }`
- PostgreSQL operation: `<!-- the SQL the tool would run -->`
- Required permission: `SELECT` on `<!-- table -->` for role `<!-- role -->`
- Validation before execution: <!-- what the tool validates before issuing the query -->
- Audit log entry: `<!-- what gets written to the audit log, if anything -->`
- Human approval needed: No / Yes — <!-- why -->
- Failure mode: <!-- what can go wrong -->
- Recovery: <!-- how to handle failure -->
- Ontology connection: `[[<!-- concept -->]]`

**What this teaches:** <!-- The core takeaway in one sentence -->

**Where this applies in real systems:** <!-- A real production scenario that uses this pattern -->

**References:**
- <!-- specific section of a reference, not a generic link -->

---

## Exercise 2: <!-- Exercise title -->

<!-- repeat the pattern above -->

---

## Exercise 3 (stretch): <!-- Exercise title -->

<!-- Mark optional / stretch exercises clearly -->

**Difficulty:** Stretch — only attempt after completing exercises 1 and 2.

<!-- follow the same pattern -->
```

---

## File: solutions.md

```markdown
# Solutions: <!-- Topic Name -->

Level: Beginner / Intermediate / Advanced

Read `exercises.md` and attempt the exercises before opening this file.
Each solution includes an explanation of why it works and what to watch out for.

---

## Solution: Exercise 1 — <!-- Exercise title -->

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- full solution SQL -->
"
```

**Output:**
```
<!-- expected output -->
```

**Why this works:**
<!-- Explain the SQL in plain language. What does each clause do? -->
<!-- Why is this approach better than the naive alternative? -->

**Key learning:**
<!-- The one thing to remember from this exercise -->

**Variation / extension:**
<!-- What would change if the requirement were slightly different? -->

**Validation query:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- confirms the solution is correct -->
"
```

---

## Solution: Exercise 2 — <!-- Exercise title -->

<!-- repeat pattern -->
```

---

## File: reflection.md

```markdown
# Reflection: <!-- Topic Name -->

Answer these questions after completing all exercises.
Write your answers in a scratch file or journal — they are for you, not for grading.

---

## Comprehension questions

1. In your own words, what does <!-- concept --> do?
2. What is the difference between <!-- A --> and <!-- B -->?
3. When would you choose <!-- approach X --> over <!-- approach Y -->?

---

## Design questions

1. You have a table with 10 million rows. How does your approach in Exercise <!-- N --> change?
2. A colleague says "just use <!-- anti-pattern -->." What do you say to them?
3. Draw the data flow from a user action to the database write for the scenario in Exercise <!-- N -->.

---

## Connection questions

1. How does this topic connect to <!-- related concept you learned earlier -->?
2. What would you need to add to make this practice session's schema production-ready?
3. Which of the exercises would you refactor first if you had another hour?

---

## Open questions

List any questions this session raised that you cannot yet answer:

- ...
- ...

Bring these to `concepts/<!-- level -->/<!-- next-lesson -->` or search `references.md`.
```

---

## File: ontology-notes.md

```markdown
# Ontology Notes: <!-- Topic Name -->

These notes map the concepts in this practice session to the broader PostgreSQL concept graph.

---

## Concept map

```
<!-- ASCII concept map showing relationships -->
<!-- example:
table
  └── column (has many)
       └── type (has one)
            └── constraint (has many)
                 ├── NOT NULL
                 ├── UNIQUE
                 └── CHECK
-->
```

---

## Concept definitions

| Concept | Definition | Parent concept | Child concepts |
|---------|-----------|----------------|----------------|
| <!-- concept 1 --> | <!-- one sentence --> | <!-- parent --> | <!-- children --> |
| <!-- concept 2 --> | <!-- one sentence --> | <!-- parent --> | <!-- children --> |

---

## Key relationships

- **<!-- concept A --> IS A <!-- concept B -->:** <!-- explanation -->
- **<!-- concept A --> HAS MANY <!-- concept B -->:** <!-- explanation -->
- **<!-- concept A --> REQUIRES <!-- concept B -->:** <!-- explanation -->
- **<!-- concept A --> CONTRASTS WITH <!-- concept B -->:** <!-- explanation -->

---

## Obsidian graph links

(These become edges in the Obsidian graph view when the repo is opened as a vault.)

- `[[<!-- concept 1 -->]]`
- `[[<!-- concept 2 -->]]`
- `[[<!-- related concept from another lesson -->]]`

---

## Questions for deeper concept mapping

1. Is <!-- concept --> a specialization of something more general?
2. What concept is logically upstream — what must exist before this can exist?
3. What concepts does this make possible downstream?
```

---

## File: troubleshooting.md

```markdown
# Troubleshooting: <!-- Topic Name -->

Common errors encountered in this practice session and how to fix them.

---

## Error 1: `<!-- error message -->`

**Trigger:** <!-- what action causes this error -->

**Cause:** <!-- why PostgreSQL raises this error -->

**Fix:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- the corrected SQL -->
"
```

**Prevention:** <!-- how to write the code so this never happens -->

---

## Error 2: `<!-- error message -->`

**Trigger:** <!-- what action causes this error -->

**Cause:** <!-- why this happens -->

**Fix:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- fix -->
"
```

---

## Error 3: Silent failure (wrong results, no error)

**Symptom:** <!-- what you observe — wrong row count, missing data, etc. -->

**Cause:** <!-- why PostgreSQL does not raise an error but the result is wrong -->

**Diagnosis query:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- query to reveal the problem -->
"
```

**Fix:** <!-- how to correct the query or schema -->

---

## Setup troubleshooting

**Problem:** `setup.sql` fails with `permission denied`
**Fix:** Confirm you are using `-U cfp` and connecting to the `cfp` database.

**Problem:** Table already exists with different schema
**Fix:** The DROP TABLE at the top of `setup.sql` handles this. If it fails, run:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "DROP TABLE <!-- table --> CASCADE;"
```
Then re-run `setup.sql`.

**Problem:** Container is not running
**Fix:**
```bash
docker ps | grep cfp_postgres
# If not listed:
docker compose -f /mnt/d/wsl/l-pgsql/tools/dashboards/docker-compose.yml up -d cfp_postgres
```
```

---

## File: references.md

```markdown
# References: <!-- Topic Name -->

Topic-specific references for this practice session.

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|-----------|
| PostgreSQL docs — <!-- topic --> | https://www.postgresql.org/docs/current/<!-- page --> | Official docs | <!-- level --> | <!-- time --> | <!-- why --> |
| <!-- title --> | <!-- URL --> | <!-- type --> | <!-- level --> | <!-- time --> | <!-- why --> |

---

## Further reading

After completing this practice session, continue with:

- `concepts/<!-- level -->/<!-- next-lesson -->` — <!-- why this is the logical next step -->
- `practice/<!-- level -->/<!-- next-practice -->` — <!-- what it covers -->

---

## Reference quality note

All references in this file must be:
- Free to access
- Verified to exist
- Relevant to the specific exercises in this session

If a reference cannot be verified, write: `TODO: Find verified reference for this topic.`
```
