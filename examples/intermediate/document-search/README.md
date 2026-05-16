# Document Search Example

Level: Intermediate
Domain: Hybrid document search combining full-text search and fuzzy title matching
Synthetic data: Yes

## Overview

A document search engine for a fictional internal knowledge base called "Clarity KB".
Demonstrates two complementary search techniques available in PostgreSQL without
any external search engine:

- **Full-text search (FTS)** — GIN index on a pre-computed `tsvector_body` column;
  uses `ts_rank` to rank results by relevance.
- **Fuzzy search** — `pg_trgm` trigram index on `title`; finds documents even when
  the user's search term has typos or partial words.
- **Hybrid query** — combine both scores with weighted addition to get the best
  of both approaches.

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE documents (
    id              SERIAL PRIMARY KEY,
    title           TEXT        NOT NULL,
    body            TEXT        NOT NULL DEFAULT '',
    author          TEXT        NOT NULL,
    tags            TEXT[]      NOT NULL DEFAULT '{}',
    tsvector_body   TSVECTOR,            -- pre-computed FTS vector
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- GIN index on the pre-computed tsvector for fast FTS
CREATE INDEX idx_documents_fts    ON documents USING GIN (tsvector_body);

-- GIN trigram index on title for fuzzy matching
CREATE INDEX idx_documents_trgm   ON documents USING GIN (title gin_trgm_ops);

-- Optional: GIN on tags for array containment
CREATE INDEX idx_documents_tags   ON documents USING GIN (tags);

-- Trigger to keep tsvector_body updated automatically
CREATE OR REPLACE FUNCTION fn_documents_tsvector_update()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.tsvector_body :=
        setweight(to_tsvector('english', coalesce(NEW.title,  '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.author, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(NEW.body,   '')), 'C');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_documents_tsvector
BEFORE INSERT OR UPDATE ON documents
FOR EACH ROW EXECUTE FUNCTION fn_documents_tsvector_update();
```

## Seed data

```sql
INSERT INTO documents (title, body, author, tags) VALUES
  ('Introduction to PostgreSQL Indexes',
   'PostgreSQL supports several index types including B-tree, Hash, GIN, GiST, '
   'SP-GiST, and BRIN. Choosing the right index type depends on your data and '
   'query patterns. B-tree is the default and works for most comparison queries.',
   'Alice Moreno', ARRAY['postgres','indexing','beginner']),

  ('Full-Text Search in PostgreSQL',
   'Full-text search (FTS) allows you to search document bodies for keywords and '
   'phrases. PostgreSQL provides the tsvector and tsquery types along with GIN '
   'indexes to power fast, ranked document retrieval.',
   'Bob Stein', ARRAY['postgres','fts','search']),

  ('Row-Level Security: A Practical Guide',
   'Row-Level Security (RLS) lets you define fine-grained access control policies '
   'at the table level. Policies use expressions that are appended to WHERE clauses '
   'automatically, ensuring tenants can only see their own data.',
   'Carol Huang', ARRAY['postgres','security','rls','multitenancy']),

  ('Understanding VACUUM and Table Bloat',
   'PostgreSQL uses MVCC for concurrency, which means old row versions accumulate '
   'as dead tuples. The VACUUM command reclaims this space. AUTOVACUUM runs '
   'automatically but can be tuned via storage parameters.',
   'Alice Moreno', ARRAY['postgres','maintenance','vacuum','performance']),

  ('Getting Started with pgvector',
   'pgvector is a PostgreSQL extension for storing and querying vector embeddings. '
   'It supports L2, inner product, and cosine distance operators. Useful for '
   'semantic search, recommendations, and AI agent memory.',
   'David Park', ARRAY['postgres','vector','ai','pgvector']),

  ('pg_trgm: Fuzzy String Matching',
   'The pg_trgm extension enables fuzzy text search using trigram similarity. '
   'It is particularly useful for correcting typos in user input and finding '
   'approximate string matches without exact keyword knowledge.',
   'Bob Stein', ARRAY['postgres','trgm','fuzzy','search']),

  ('Window Functions Explained',
   'Window functions compute values across rows related to the current row without '
   'collapsing the result set like GROUP BY does. Functions include ROW_NUMBER, '
   'RANK, DENSE_RANK, LAG, LEAD, SUM OVER, and NTILE.',
   'Carol Huang', ARRAY['postgres','sql','window-functions','intermediate']),

  ('Connection Pooling with PgBouncer',
   'PgBouncer is a lightweight connection pooler for PostgreSQL. It reduces the '
   'overhead of establishing new connections by maintaining a pool of idle '
   'connections that clients can reuse.',
   'Eve Santos', ARRAY['postgres','pgbouncer','performance','infrastructure']),

  ('Partitioning Large Tables',
   'Table partitioning splits a large table into smaller physical pieces called '
   'partitions. PostgreSQL supports range, list, and hash partitioning. '
   'Partition pruning allows the query planner to skip irrelevant partitions.',
   'David Park', ARRAY['postgres','partitioning','performance','advanced']),

  ('Using JSONB for Flexible Schemas',
   'The JSONB type stores JSON data in a binary format that supports GIN indexing '
   'and efficient key lookups. It is ideal for semi-structured data where the '
   'schema varies between rows.',
   'Alice Moreno', ARRAY['postgres','jsonb','schema-design']);
```

## Example queries

### Pure full-text search

```sql
-- Search for documents about "fuzzy search trigram"
SELECT id,
       title,
       author,
       ts_rank(tsvector_body, query) AS rank
FROM   documents,
       plainto_tsquery('english', 'fuzzy search trigram') AS query
WHERE  tsvector_body @@ query
ORDER  BY rank DESC;
```

### FTS with phrase matching

```sql
-- Exact phrase "dead tuples"
SELECT id, title, author
FROM   documents
WHERE  tsvector_body @@ phraseto_tsquery('english', 'dead tuples');
```

### FTS with highlighted snippets

```sql
SELECT id,
       title,
       ts_headline(
         'english',
         body,
         plainto_tsquery('english', 'vacuum bloat'),
         'StartSel=<b>, StopSel=</b>, MaxWords=20, MinWords=5'
       ) AS snippet
FROM   documents
WHERE  tsvector_body @@ plainto_tsquery('english', 'vacuum bloat');
```

### Fuzzy title search (pg_trgm similarity)

```sql
-- Finds titles similar to "postgress indeces" (intentional typos)
SELECT id,
       title,
       author,
       similarity(title, 'postgress indeces') AS sim
FROM   documents
WHERE  title % 'postgress indeces'             -- % operator: similarity > threshold
ORDER  BY sim DESC;
```

### Adjust similarity threshold

```sql
-- Default threshold is 0.3; lower it to catch more results
SET pg_trgm.similarity_threshold = 0.2;

SELECT id, title, similarity(title, 'window funcs') AS sim
FROM   documents
WHERE  title % 'window funcs'
ORDER  BY sim DESC;

RESET pg_trgm.similarity_threshold;
```

### Hybrid search: combine FTS rank and trigram similarity

```sql
-- Weighted combination: 70% FTS rank + 30% trigram similarity on title
WITH fts AS (
    SELECT id,
           ts_rank(tsvector_body, query) AS fts_score
    FROM   documents,
           plainto_tsquery('english', 'vector embeddings search') AS query
    WHERE  tsvector_body @@ query
),
trgm AS (
    SELECT id,
           similarity(title, 'vector embeddings search') AS trgm_score
    FROM   documents
    WHERE  title % 'vector embeddings search'
              OR similarity(title, 'vector embeddings search') > 0.1
)
SELECT d.id,
       d.title,
       d.author,
       COALESCE(f.fts_score,   0) AS fts_score,
       COALESCE(t.trgm_score,  0) AS trgm_score,
       ROUND(
         (0.7 * COALESCE(f.fts_score,  0) +
          0.3 * COALESCE(t.trgm_score, 0))::NUMERIC, 4
       )                         AS hybrid_score
FROM   documents d
LEFT   JOIN fts  f ON f.id = d.id
LEFT   JOIN trgm t ON t.id = d.id
WHERE  f.id IS NOT NULL OR t.id IS NOT NULL
ORDER  BY hybrid_score DESC;
```

### Filter by tag and search

```sql
SELECT id, title, author
FROM   documents
WHERE  tags @> ARRAY['postgres','performance']
  AND  tsvector_body @@ plainto_tsquery('english', 'index');
```

### Author's documents, ranked by recency

```sql
SELECT id, title, created_at
FROM   documents
WHERE  author = 'Alice Moreno'
ORDER  BY created_at DESC;
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

SELECT COUNT(*) FROM documents;
-- Expected: 10

-- tsvector_body populated by trigger
SELECT COUNT(*) FROM documents WHERE tsvector_body IS NOT NULL;
-- Expected: 10

-- pg_trgm extension loaded
SELECT extname FROM pg_extension WHERE extname = 'pg_trgm';

-- GIN FTS index exists
SELECT indexname FROM pg_indexes
WHERE tablename = 'documents' AND indexname = 'idx_documents_fts';

-- GIN trigram index exists
SELECT indexname FROM pg_indexes
WHERE tablename = 'documents' AND indexname = 'idx_documents_trgm';

-- FTS returns results for 'vector'
SELECT COUNT(*) FROM documents
WHERE tsvector_body @@ plainto_tsquery('english', 'vector');
-- Expected: >= 2
```

## Practice tasks

1. **Typo tolerance.** Search the title field with the misspelling `'postgress vakuum'`.
   Adjust `pg_trgm.similarity_threshold` until at least one result appears. Which
   documents match?

2. **Weighted FTS.** The trigger gives `title` weight 'A' and `body` weight 'C'.
   Insert a new document where the term "encryption" appears only in the body.
   Compare `ts_rank` results with and without weight masking using the 4-element
   weight array `'{0.1, 0.2, 0.4, 1.0}'`.

3. **ts_headline.** Modify the `ts_headline` query to highlight the word "automatic"
   in any matching documents. Experiment with `MaxFragments` and `FragmentDelimiter`
   options.

4. **Combined tag + FTS filter.** Add a new document tagged `['postgres','security']`
   with body text about encryption. Write a query that finds all documents tagged
   `security` AND matching the FTS query `'encryption access control'`.

5. **Performance comparison.** Use `EXPLAIN ANALYZE` to compare:
   a) `WHERE body ILIKE '%window function%'`
   b) `WHERE tsvector_body @@ plainto_tsquery('english', 'window function')`
   Which one uses an index? What is the difference in planning and execution time?

## MCP and agent perspective

An agent powering a knowledge-base search via MCP would:

- **Serve keyword queries** — translate user questions into `plainto_tsquery` and
  return `ts_rank`-ordered results with highlighted snippets.
- **Handle typos** — `pg_trgm` similarity catches misspelled document titles without
  requiring a dedicated typo-correction service.
- **Hybrid retrieval** — combine FTS and trigram scores for a more robust ranking
  than either alone; the weights can be tuned without schema changes.
- **Tag-scoped search** — constrain searches to a specific topic area using GIN
  array containment before running FTS, reducing noise.
- **No external search engine** — Elasticsearch/OpenSearch is not needed for
  moderate corpora (< 10M documents). Pure PostgreSQL is simpler to operate.

## Teardown

```sql
DROP TRIGGER  IF EXISTS trg_documents_tsvector ON documents;
DROP FUNCTION IF EXISTS fn_documents_tsvector_update();
DROP INDEX    IF EXISTS idx_documents_tags;
DROP INDEX    IF EXISTS idx_documents_trgm;
DROP INDEX    IF EXISTS idx_documents_fts;
DROP TABLE    IF EXISTS documents;
DROP EXTENSION IF EXISTS pg_trgm;
```

## References

- Full-Text Search: https://www.postgresql.org/docs/current/textsearch.html
- ts_headline: https://www.postgresql.org/docs/current/textsearch-controls.html#TEXTSEARCH-HEADLINE
- pg_trgm: https://www.postgresql.org/docs/current/pgtrgm.html
- GIN Indexes: https://www.postgresql.org/docs/current/gin.html
