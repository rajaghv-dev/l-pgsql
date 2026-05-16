# Full-Text Search — Intuition

Level: Beginner

## One-line intuition

Full-text search finds documents that contain meaningful words — it understands language (stemming, stop words) instead of just matching exact strings.

## Why this exists

`LIKE '%keyword%'` has three problems: it cannot use an index (sequential scan), it matches substrings (finds "cats" inside "education"), and it does not understand that "running" and "run" are the same word. Full-text search solves all three.

## First-principles explanation

PostgreSQL full-text search converts text into a `tsvector` (a processed list of lexemes — normalized word stems) and a query into a `tsquery` (a parsed query expression). The `@@` operator checks if a query matches a document.

```
text → to_tsvector() → tsvector (normalized, stop-words removed)
query → to_tsquery()  → tsquery  (parsed, normalized)
tsvector @@ tsquery   → boolean  (does the doc match the query?)
```

A GIN index on the tsvector column makes this fast — O(log n) instead of O(n).

## Micro-concepts

| Concept | Meaning |
|---------|---------|
| `tsvector` | Processed document: normalized words + positions |
| `tsquery` | Parsed query: words, AND/OR/NOT/phrase operators |
| `to_tsvector(config, text)` | Convert text to tsvector |
| `to_tsquery(config, query)` | Convert string to tsquery |
| `plainto_tsquery(config, text)` | Convert plain text to AND query (no syntax needed) |
| `websearch_to_tsquery(config, text)` | Converts Google-style search syntax |
| `@@` operator | Matches tsvector against tsquery |
| `ts_rank(tsvector, tsquery)` | Relevance score (0.0–1.0) |
| `ts_headline(text, tsquery)` | Highlighted snippet |
| `english` | Text search configuration (language-specific stemming) |

## Beginner view

Book catalog example: find all books that mention "quantum":

```sql
-- LIKE approach (slow, no index, no stemming)
SELECT title FROM books WHERE description LIKE '%quantum%';

-- FTS approach (fast with GIN index, language-aware)
SELECT title
FROM books
WHERE to_tsvector('english', description) @@ to_tsquery('english', 'quantum');
-- Also matches: "quantums", "quantum's", "Quantum"
```

The key difference: `to_tsvector` reduces "running", "runs", "ran" all to the lexeme "run". A query for 'run' matches all of them.

## Intermediate view

**Stored tsvector column** (precompute, then index):

```sql
-- Add a generated column for the tsvector
ALTER TABLE books ADD COLUMN fts tsvector
    GENERATED ALWAYS AS (
        to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(description, ''))
    ) STORED;

-- GIN index on the generated column
CREATE INDEX idx_books_fts ON books USING GIN (fts);

-- Query is now fast
SELECT title, ts_rank(fts, query) AS rank
FROM books, to_tsquery('english', 'quantum & physics') query
WHERE fts @@ query
ORDER BY rank DESC
LIMIT 10;
```

**Query operators** in `to_tsquery`:

| Operator | Meaning | Example |
|----------|---------|---------|
| `&` | AND | `'quantum & physics'` |
| `\|` | OR | `'quantum \| relativity'` |
| `!` | NOT | `'physics & !biology'` |
| `<->` | FOLLOWED BY (phrase) | `'quantum <-> mechanics'` |

**`websearch_to_tsquery`** (PostgreSQL 11+): accepts Google-style input (`"quantum physics" -biology`) — easier to use in user-facing search.

## Advanced view

- **Text search configurations**: `english`, `spanish`, `french`, etc. Each config has a parser (splits text into tokens), a dictionary (maps tokens to lexemes), and stop words. Use `\dF` in psql to list configurations.
- **Custom dictionaries**: extend with domain-specific synonyms (e.g., "PostgreSQL" = "Postgres" = "PG").
- **Ranking**: `ts_rank` and `ts_rank_cd` (cover density) weight matches by position and frequency. Tune weights with the `weights` parameter.
- **pg_trgm** (trigram index): covers cases where FTS does not — partial word matching, spelling errors. Used with `%` (similarity operator) or `ILIKE` with GIN/GiST index. Not a replacement for FTS — complementary.

## Mental model

Think of FTS as a librarian with a card catalog:

1. **Indexing**: for each book, the librarian extracts all meaningful words, removes stop words ("the", "a", "is"), stems them ("books" → "book"), and records "book → pages 1, 7, 23" on a card.
2. **Searching**: the librarian looks up your query word on the cards and returns only the matching page numbers (row IDs).

A GIN index IS that card catalog. Without it, the librarian reads every book to search — that is the sequential scan.

## PostgreSQL view

```sql
-- Inspect a tsvector
SELECT to_tsvector('english', 'The quick brown fox jumps over the lazy dog');
-- Result: 'brown':3 'dog':9 'fox':4 'jump':5 'lazi':8 'quick':2
-- "the" and "over" are stop words (removed)
-- "jumps" is stemmed to "jump", "lazy" to "lazi"

-- Test a query match
SELECT to_tsvector('english', 'PostgreSQL full-text search') @@
       to_tsquery('english', 'text & search');
-- Result: true

-- Highlighted snippet
SELECT ts_headline('english',
    'PostgreSQL provides powerful full-text search capabilities.',
    to_tsquery('english', 'search'));
-- Result: PostgreSQL provides powerful full-text <b>search</b> capabilities.
```

## SQL view

```sql
-- Library catalog: find books matching a user search query
CREATE TABLE books (
    id          SERIAL PRIMARY KEY,
    title       TEXT NOT NULL,
    description TEXT,
    fts         TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('english',
            COALESCE(title, '') || ' ' || COALESCE(description, ''))
    ) STORED
);

CREATE INDEX idx_books_fts ON books USING GIN (fts);

-- blocked: Docker not accessible; validate against cfp_postgres when available
SELECT
    title,
    ts_rank(fts, query) AS rank,
    ts_headline('english', description, query) AS snippet
FROM
    books,
    websearch_to_tsquery('english', 'science fiction space') query
WHERE fts @@ query
ORDER BY rank DESC
LIMIT 5;
```

## Non-SQL or hybrid view

Elasticsearch and Solr are dedicated full-text search engines. They are more powerful for complex search (facets, fuzzy, autocomplete) but require running a separate service. PostgreSQL FTS covers 80% of use cases inside the database — no extra service, no sync complexity, consistent with transactional writes.

## Design principle

**Use FTS for language-aware text search; use `LIKE` only for exact substring matching.** Add the generated tsvector column from the start — it is cheap and enabling FTS later requires a full table rewrite.

## Critical thinking

- FTS does not handle typos by default. "Quatum" will not match "Quantum". For fuzzy matching, combine with pg_trgm or use a custom dictionary with `unaccent` and synonym files.
- `ts_rank` is a relevance heuristic, not a semantic similarity score. For true semantic similarity (find conceptually related documents even without shared words), use vector search (lesson 19).

## Creative thinking

Combine FTS with JSONB to search inside flexible metadata:

```sql
WHERE to_tsvector('english', metadata->>'description') @@ query
```

## Systems thinking

In a production application, the FTS index must be kept in sync with the underlying text columns. The generated column approach (STORED) handles this automatically — any update to `title` or `description` triggers a recompute. Without a generated column, you need a trigger to maintain the tsvector, or you run `to_tsvector()` at query time (slower).

## MCP and agent perspective

An agent handling user search queries should:

1. Sanitize input with `websearch_to_tsquery` (prevents tsquery syntax injection).
2. Use parameterized queries: `WHERE fts @@ websearch_to_tsquery('english', $1)`.
3. Apply `LIMIT` to prevent returning thousands of results.
4. Return `ts_headline` output for display — do not return full text to the agent unnecessarily.

## Ontology perspective

- `tsvector` is a **document representation** — the processed form of text for indexing.
- `tsquery` is a **query representation** — the parsed form of a search expression.
- The `@@` operator implements **relevance matching** — a Boolean predicate on documents.
- `ts_rank` implements **relevance scoring** — a numeric measure of match quality.
- A GIN index on tsvector is an **inverted index** — maps lexemes to document IDs.
- FTS is a specialization of **information retrieval** applied inside a relational database.

## Practice session

FTS is demonstrated in `practice/beginner/08-views-and-functions-basics/`. A dedicated FTS practice session appears in the intermediate stage.

## References

| Resource | URL | Why |
|----------|-----|-----|
| PostgreSQL docs — Full Text Search | https://www.postgresql.org/docs/current/textsearch.html | Complete chapter on FTS |
| PostgreSQL docs — tsvector type | https://www.postgresql.org/docs/current/datatype-textsearch.html | Type definitions |
| PostgreSQL docs — GIN Indexes for FTS | https://www.postgresql.org/docs/current/textsearch-indexes.html | Choosing GIN vs GiST |
| PostgreSQL docs — Text Search Functions | https://www.postgresql.org/docs/current/functions-textsearch.html | Full function list |
| pg_trgm docs | https://www.postgresql.org/docs/current/pgtrgm.html | Fuzzy matching complement |
