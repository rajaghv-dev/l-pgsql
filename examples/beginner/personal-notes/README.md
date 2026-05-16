# Personal Notes Example

Level: Beginner
Domain: Simple note-taking app with tags and full-text search
Synthetic data: Yes

## Overview

A minimal personal notes application. Demonstrates basic CRUD operations,
PostgreSQL array columns for tags, and simple full-text search on note bodies.
A good first schema to explore SELECT, INSERT, UPDATE, and basic indexing.

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

CREATE TABLE notes (
    id          SERIAL PRIMARY KEY,
    title       TEXT        NOT NULL CHECK (char_length(title) > 0),
    body        TEXT        NOT NULL DEFAULT '',
    tags        TEXT[]      NOT NULL DEFAULT '{}',   -- e.g. ARRAY['work','ideas']
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- GIN index so array-containment queries (@>) use an index
CREATE INDEX idx_notes_tags      ON notes USING GIN (tags);

-- Full-text search index on body
CREATE INDEX idx_notes_body_fts  ON notes USING GIN (to_tsvector('english', body));
```

## Seed data

```sql
INSERT INTO notes (title, body, tags) VALUES
  ('Grocery run',
   'Pick up oat milk, brown rice, lentils, and a bag of apples.',
   ARRAY['personal','shopping']),

  ('Meeting prep',
   'Review Q3 slides, confirm agenda with team lead, bring printed copies.',
   ARRAY['work','meetings']),

  ('Book notes: Deep Work',
   'Key idea: distraction-free focus blocks produce the best output. '
   'Schedule 90-minute sessions every morning before email.',
   ARRAY['reading','productivity']),

  ('Weekend hiking plan',
   'Trail: Blue Ridge Loop, 8 miles. Start at 7am to beat the heat. '
   'Pack water, snacks, first-aid kit.',
   ARRAY['personal','fitness','outdoors']),

  ('Project ideas',
   'Explore a CLI tool for bulk SQL formatting. '
   'Also look into a small vector search demo using pgvector.',
   ARRAY['work','ideas','postgres']),

  ('Postgres study',
   'Practice window functions, CTEs, and EXPLAIN ANALYZE today.',
   ARRAY['work','postgres','study']),

  ('Recipe: lentil soup',
   'Sauté onion and garlic, add red lentils and vegetable broth, '
   'simmer 25 minutes, season with cumin and lemon.',
   ARRAY['personal','cooking']);
```

## Example queries

### Find all notes with a specific tag

```sql
-- Array containment operator @>
SELECT id, title, tags
FROM   notes
WHERE  tags @> ARRAY['work']
ORDER  BY created_at DESC;
```

### Find notes that have ALL of two given tags

```sql
SELECT id, title, tags
FROM   notes
WHERE  tags @> ARRAY['work','postgres']
ORDER  BY created_at DESC;
```

### Find notes that have ANY of a set of tags

```sql
SELECT id, title, tags
FROM   notes
WHERE  tags && ARRAY['fitness','cooking']
ORDER  BY created_at DESC;
```

### Full-text search on body

```sql
-- Returns ranked results for the keyword "focus"
SELECT id,
       title,
       ts_rank(to_tsvector('english', body),
               plainto_tsquery('english', 'focus')) AS rank
FROM   notes
WHERE  to_tsvector('english', body)
         @@ plainto_tsquery('english', 'focus')
ORDER  BY rank DESC;
```

### Most recent notes

```sql
SELECT id, title, created_at
FROM   notes
ORDER  BY created_at DESC
LIMIT  5;
```

### Notes created in the last 7 days

```sql
SELECT id, title, created_at
FROM   notes
WHERE  created_at >= NOW() - INTERVAL '7 days'
ORDER  BY created_at DESC;
```

### Count notes per tag (unnest the array)

```sql
SELECT tag, COUNT(*) AS note_count
FROM   notes, unnest(tags) AS t(tag)
GROUP  BY tag
ORDER  BY note_count DESC;
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- 1. Row count should be 7
SELECT COUNT(*) AS total_notes FROM notes;

-- 2. Tags index exists
SELECT indexname FROM pg_indexes WHERE tablename = 'notes' AND indexname = 'idx_notes_tags';

-- 3. FTS index exists
SELECT indexname FROM pg_indexes WHERE tablename = 'notes' AND indexname = 'idx_notes_body_fts';

-- 4. Array containment works
SELECT COUNT(*) AS work_notes FROM notes WHERE tags @> ARRAY['work'];
-- Expected: 3

-- 5. FTS returns at least one result
SELECT COUNT(*) FROM notes
WHERE to_tsvector('english', body) @@ plainto_tsquery('english', 'lentil');
-- Expected: 2
```

## Practice tasks

1. **Add a note and search for it.** Insert a new note with tags `['study','postgres']`
   and verify it appears when you search for notes tagged `postgres`.

2. **Update a note's tags.** Pick any note and append a new tag using
   `array_append(tags, 'archived')` in an UPDATE statement. Confirm the change.

3. **Full-text search with ranking.** Search for the word `water` and return
   the top 3 results ordered by `ts_rank`. Which notes appear?

4. **Tag frequency report.** Using `unnest(tags)`, produce a report of every
   tag and how many notes carry it, sorted descending. Add a note with a brand-new
   tag and re-run the report.

5. **Recent notes dashboard.** Write a single query that returns the 3 most-recent
   notes along with how many tags each has (`array_length(tags, 1)`).

## MCP and agent perspective

An AI agent using this schema via MCP would:

- **Create memories quickly** — `INSERT INTO notes` with a free-text body and
  relevant tags. No rigid schema to conform to.
- **Retrieve by keyword** — use FTS queries to recall notes related to a topic
  without needing exact titles.
- **Filter by context** — `tags @> ARRAY['work']` narrows results to the current
  work context before a meeting.
- **Summarise tag space** — the `unnest` + `COUNT` query gives the agent a view
  of which topics it has covered most.

The schema is intentionally simple so an agent can use it without complex joins.
`tags` as a text array avoids a separate join table while still enabling GIN-indexed
lookups.

## Teardown

```sql
DROP INDEX IF EXISTS idx_notes_body_fts;
DROP INDEX IF EXISTS idx_notes_tags;
DROP TABLE IF EXISTS notes;
```

## References

- PostgreSQL Arrays: https://www.postgresql.org/docs/current/arrays.html
- Full-Text Search: https://www.postgresql.org/docs/current/textsearch.html
- GIN Indexes: https://www.postgresql.org/docs/current/gin.html
