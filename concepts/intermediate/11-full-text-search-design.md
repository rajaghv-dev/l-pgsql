# Full-Text Search Design
Level: Intermediate

## One-line intuition
PostgreSQL's built-in FTS converts text into normalized lexeme vectors, enabling fast ranked search over natural language content without an external search engine.

## Why this exists
LIKE and ILIKE patterns do not understand language: they cannot match "running" when searching "run", cannot rank results by relevance, and cannot ignore stop words like "the". FTS solves all three: it normalizes words (stemming), removes noise words, ranks by term frequency, and indexes efficiently with GIN.

## First-principles explanation
Full-text search has two core types:

**tsvector** — a sorted list of normalized lexemes (stemmed words) with their position and weight:
```
'cat' 'jump' 'quick' 'run'
```

**tsquery** — a boolean expression of lexemes:
```
'quick' & 'cat'   -- AND
'cat' | 'dog'     -- OR
!'dog'            -- NOT
'quick' <-> 'cat' -- phrase (adjacent)
```

The pipeline:
1. `to_tsvector('english', text)` — tokenizes, stems, removes stop words, produces tsvector
2. `to_tsquery('english', 'running cats')` — normalizes query terms
3. `@@` operator — matches a tsvector against a tsquery
4. `ts_rank(tsvector, tsquery)` — relevance score based on term frequency and position
5. `ts_headline(text, tsquery)` — returns an excerpt with matching terms highlighted

**Weights:** tsvectors can assign weights A/B/C/D to lexemes, allowing title matches to outrank body matches:
```sql
setweight(to_tsvector('english', title), 'A') ||
setweight(to_tsvector('english', body), 'B')
```

## Micro-concepts
- **lexeme** — the normalized form of a word (stem); "running" → "run"
- **text search configuration** — language-specific dictionary chain (tokenizer + stemmer + stop words); e.g., `english`, `simple`, `french`
- **GIN index** — the correct index type for tsvector; supports `@@` operator efficiently
- **stored tsvector column** — materialize `to_tsvector()` in a generated or trigger-updated column for query efficiency
- **plainto_tsquery()** — parses a plain string without operators; safe for user input
- **phraseto_tsquery()** — requires terms to appear in sequence
- **websearch_to_tsquery()** — parses Google-style search syntax (quoted phrases, minus for NOT)
- **ts_rank_cd()** — coverage density ranking; considers how many distinct terms match

## Beginner view
FTS is like a smart search box. Instead of matching the exact word "running", it understands that "running", "ran", and "run" are the same concept. It also ignores filler words ("the", "a", "in") and can rank results by relevance.

## Intermediate view
The key implementation choice is where to store the tsvector:
- **On-the-fly**: `WHERE to_tsvector('english', body) @@ query` — no storage cost, but recomputes every query
- **Stored column**: Add a `search_vector TSVECTOR` column, populate via trigger or generated column, index it — fast queries, extra storage

For production use, always store the tsvector and index it:
```sql
ALTER TABLE articles ADD COLUMN search_vector TSVECTOR;
UPDATE articles SET search_vector = to_tsvector('english', title || ' ' || body);
CREATE INDEX ON articles USING gin(search_vector);
```

## Advanced view
Multi-language FTS requires per-row configuration columns. Use `regconfig` type to store which language config applies to each row. Custom dictionaries (synonym files, stop-word lists) can be loaded via `CREATE TEXT SEARCH DICTIONARY`. For typo tolerance, combine FTS with pg_trgm: use FTS for recall, pg_trgm similarity for re-ranking.

## Mental model
Think of FTS as building a book's index: every word is extracted, normalized, and recorded with its page number. The GIN index is that back-of-book index. A search query looks up terms in the index and finds the pages where all requested terms appear. Ranking counts how many times terms appear and how prominently (title vs body).

## PostgreSQL view
```sql
-- Create articles table with stored tsvector
CREATE TABLE articles (
    id            SERIAL PRIMARY KEY,
    title         TEXT NOT NULL,
    body          TEXT NOT NULL,
    language      REGCONFIG NOT NULL DEFAULT 'english',
    search_vector TSVECTOR GENERATED ALWAYS AS (
        setweight(to_tsvector(language::regconfig, title), 'A') ||
        setweight(to_tsvector(language::regconfig, body), 'B')
    ) STORED
);

CREATE INDEX ON articles USING gin(search_vector);

-- Search
SELECT id, title, ts_rank(search_vector, q) AS rank
FROM articles, to_tsquery('english', 'postgresql & performance') AS q
WHERE search_vector @@ q
ORDER BY rank DESC;

-- User-input-safe query
SELECT id, title
FROM articles
WHERE search_vector @@ websearch_to_tsquery('english', 'postgresql performance tuning');

-- Highlighted excerpts
SELECT ts_headline('english', body, to_tsquery('english', 'postgres'))
FROM articles
WHERE id = 1;
```

## SQL view
The SQL standard does not define FTS. MySQL has FULLTEXT index with MATCH...AGAINST. Elasticsearch/OpenSearch are purpose-built FTS engines with richer ranking models (BM25). PostgreSQL FTS is sufficient for moderate-scale use cases (millions of documents) without the operational overhead of a separate search cluster.

## Non-SQL or hybrid view
For very large corpora or complex relevance requirements, synchronize data to Elasticsearch or OpenSearch. Use PostgreSQL as the source of truth and stream changes via logical replication or a CDC tool (Debezium). PostgreSQL FTS is ideal when you want search without the operational burden of a separate system.

## Design principle
**Use FTS within PostgreSQL as long as your document count is under a few million and ranking requirements are simple.** Avoid rebuilding tsvectors on every query — store and index them. Use language-aware configurations for multilingual content. When queries become complex (faceted search, boosting by recency or custom signals), consider Elasticsearch.

## Critical thinking
- `to_tsvector('english', text)` silently ignores words not in the English dictionary. For code, proper nouns, and abbreviations, use the `simple` configuration (no stemming, no stop words).
- Phrase search (`<->` operator) only works correctly when position information is stored in the tsvector. `setweight` does not affect position information.
- GIN indexes are write-heavy: every INSERT/UPDATE to indexed text triggers an index update. For write-heavy tables, use `gin_pending_list_limit` tuning or BRIN-based approaches.

## Creative thinking
Combine FTS with jsonb: store article metadata as JSONB and the search vector as a separate column. Use `jsonb_each_text()` to extract fields and concatenate them into the tsvector. This allows dynamic field inclusion in the search vector without schema changes.

## Systems thinking
FTS ranking is a function of what is in the database, not of the user's context. A document published 5 years ago ranks the same as one published yesterday. To incorporate recency, use a composite score: `ts_rank(...) * decay_factor(created_at)`. This requires a custom ranking expression but keeps all logic inside the database.

## MCP and agent perspective
An MCP agent performing document retrieval should use `websearch_to_tsquery()` for user-provided search strings — it handles quoted phrases, minus signs, and operator-like input safely without SQL injection risk. For agent-generated structured queries, use `to_tsquery()` with explicit boolean operators. Always include `LIMIT` and `ORDER BY rank` to return top-k results efficiently.

## Ontology perspective
FTS operates on the lexeme layer of the ontology — it understands that "PostgreSQL", "postgres", and "pgsql" might refer to the same concept (if synonyms are configured). The tsvector is a projection of a document onto the ontology's vocabulary: it retains the concepts present (as lexemes) and discards linguistic decoration (stop words, inflection). A richer ontology would map synonyms, hierarchical terms (hyponyms), and related concepts — achievable via custom text search dictionaries.

## Practice session
See `practice/intermediate/07-full-text-and-fuzzy-search/` for hands-on exercises with FTS and pg_trgm.

## References
- PostgreSQL docs — Full Text Search: https://www.postgresql.org/docs/16/textsearch.html
- PostgreSQL docs — Text Search Functions: https://www.postgresql.org/docs/16/functions-textsearch.html
- PostgreSQL docs — GIN Indexes: https://www.postgresql.org/docs/16/gin.html
- PostgreSQL docs — GENERATED columns: https://www.postgresql.org/docs/16/ddl-generated-columns.html
- "PostgreSQL Full Text Search in the Wild": https://www.crunchydata.com/blog/postgres-full-text-search-in-the-wild
