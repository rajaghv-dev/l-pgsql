# Advanced Full-Text and Hybrid Search

Level: Advanced

## One-line intuition
PostgreSQL's full-text search goes far beyond basic `to_tsquery` — with phrase search, custom text search configurations, ranked results, and the ability to combine FTS scores with vector similarity for hybrid retrieval that beats either approach alone.

## Why this exists
Basic FTS (`plainto_tsquery + GIN`) handles keyword matching but misses: phrase order ("quick brown fox" vs "fox brown quick"), negation, custom synonym expansion, language-specific normalization, and relevance ranking with document position. Advanced FTS uses the full query language and ranking infrastructure. Hybrid search adds semantic understanding via pgvector — enabling retrieval that matches both keywords and meaning.

## First-principles explanation

### tsvector and tsquery internals
`tsvector`: a normalized list of (lexeme, positions, weights). Each word is reduced to its stem; positions track where in the document each lexeme appears (used for phrase queries and ranking).

```sql
-- blocked: Docker not accessible
SELECT to_tsvector('english', 'Quick brown foxes are jumping over lazy dogs');
-- 'brown':2 'dog':8 'fox':3 'jump':5 'lazi':7 'quick':1
-- Positions are used for phrase matching and proximity ranking
```

`tsquery`: a query tree of lexemes and operators:
- `&` AND, `|` OR, `!` NOT
- `<->` phrase (adjacent), `<N>` within N words
- `*` prefix match

### Query constructors
```sql
-- blocked: Docker not accessible
-- Basic: splits by whitespace, ANDs terms
plainto_tsquery('english', 'quick brown fox')
-- => 'quick' & 'brown' & 'fox'

-- Phrase: requires adjacency
phraseto_tsquery('english', 'quick brown fox')
-- => 'quick' <-> 'brown' <-> 'fox'

-- Raw: full control over operators
to_tsquery('english', 'quick & (fox | dog) & !lazy')

-- WebSearch: user-friendly syntax (PG 11+)
websearch_to_tsquery('english', '"quick brown" -lazy')
-- => 'quick' <-> 'brown' & !'lazy'
```

### Ranking functions
**`ts_rank`**: ranks based on term frequency.
**`ts_rank_cd`**: ranks based on term frequency and cover density (proximity of terms matters more).

```sql
-- blocked: Docker not accessible
SELECT id, title,
       ts_rank(to_tsvector('english', body), query) AS rank,
       ts_rank_cd(to_tsvector('english', body), query) AS rank_cd
FROM documents,
     websearch_to_tsquery('english', 'postgresql performance') AS query
WHERE to_tsvector('english', body) @@ query
ORDER BY rank_cd DESC
LIMIT 20;
```

**Ranking with weights**: `tsvector` entries can have weights A, B, C, D (A = most important, D = least). Use to boost title matches over body matches:
```sql
-- blocked: Docker not accessible
-- Combine title (weight A) and body (weight D)
SELECT id,
       ts_rank(
           setweight(to_tsvector('english', title), 'A') ||
           setweight(to_tsvector('english', body), 'D'),
           query
       ) AS rank
FROM documents,
     plainto_tsquery('english', 'postgresql') AS query
WHERE (
    setweight(to_tsvector('english', title), 'A') ||
    setweight(to_tsvector('english', body), 'D')
) @@ query
ORDER BY rank DESC;
```

**Store pre-computed tsvector** (critical for performance):
```sql
-- blocked: Docker not accessible
ALTER TABLE documents ADD COLUMN search_vector tsvector
    GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title,'')), 'A') ||
        setweight(to_tsvector('english', coalesce(body,'')), 'D')
    ) STORED;

CREATE INDEX idx_docs_fts ON documents USING GIN (search_vector);
```

Using a generated stored column means: GIN index is always current, query is simple, no repeated `to_tsvector()` call at query time.

### Custom text search configurations
Default: `'english'` configuration uses the built-in English stemmer and stop words.

Custom configuration steps:
1. Install `unaccent` extension for diacritic handling
2. Create a synonym dictionary
3. Create a new text search configuration based on English + unaccent + synonyms

```sql
-- blocked: Docker not accessible
CREATE EXTENSION unaccent;

-- Create an unaccent-aware configuration
CREATE TEXT SEARCH CONFIGURATION english_unaccent (COPY = english);
ALTER TEXT SEARCH CONFIGURATION english_unaccent
    ALTER MAPPING FOR hword, hword_part, word WITH unaccent, english_stem;

-- Use in queries
SELECT to_tsvector('english_unaccent', 'café résumé naïve')
-- 'cafe':1 'naiv':3 'resum':2  — diacritics stripped
```

Synonym dictionary (thesaurus):
```sql
-- blocked: Docker not accessible
-- Create /etc/postgresql/16/main/ts_synonym.txt:
-- postgresql postgres pg
-- Create dictionary and bind to configuration:
CREATE TEXT SEARCH DICTIONARY pg_synonyms (
    TEMPLATE = synonym,
    SYNONYMS = ts_synonym
);
ALTER TEXT SEARCH CONFIGURATION english
    ALTER MAPPING FOR word WITH pg_synonyms, english_stem;
```

### Prefix and partial matching
Standard FTS requires complete words (stems). For prefix matching:
```sql
-- blocked: Docker not accessible
-- Prefix: 'postg:*' matches 'postgresql', 'postgres', etc.
SELECT * FROM documents
WHERE search_vector @@ to_tsquery('english', 'postg:*');

-- OR: use pg_trgm for partial matching (not stem-based)
CREATE EXTENSION pg_trgm;
CREATE INDEX idx_title_trgm ON documents USING GIN (title gin_trgm_ops);
SELECT * FROM documents WHERE title % 'postgre';       -- similarity
SELECT * FROM documents WHERE title ILIKE '%postgre%'; -- uses trgm index
```

### Hybrid search: FTS + pgvector
Hybrid search combines FTS keyword matching with vector semantic similarity:
```sql
-- blocked: Docker not accessible
-- Hybrid: normalize both scores and combine
WITH fts AS (
    SELECT id,
           ts_rank_cd(search_vector, query) AS fts_score
    FROM documents,
         plainto_tsquery('english', 'postgresql performance') AS query
    WHERE search_vector @@ query
),
semantic AS (
    SELECT id,
           1 - (embedding <=> '[0.1, 0.2, ...]'::vector) AS sem_score
    FROM documents
    ORDER BY embedding <=> '[0.1, 0.2, ...]'::vector
    LIMIT 100
)
SELECT d.id, d.title,
       coalesce(f.fts_score, 0) * 0.3 + coalesce(s.sem_score, 0) * 0.7 AS hybrid_score
FROM documents d
LEFT JOIN fts f ON f.id = d.id
LEFT JOIN semantic s ON s.id = d.id
WHERE f.id IS NOT NULL OR s.id IS NOT NULL
ORDER BY hybrid_score DESC
LIMIT 20;
```

**Reciprocal Rank Fusion (RRF)** — a more principled score combination:
```sql
-- blocked: Docker not accessible
-- RRF: score = 1 / (rank + k) summed across retrieval methods
WITH fts_ranked AS (
    SELECT id, row_number() OVER (ORDER BY ts_rank_cd(search_vector, query) DESC) AS rank
    FROM documents, plainto_tsquery('english', 'query text') AS query
    WHERE search_vector @@ query
    LIMIT 100
),
sem_ranked AS (
    SELECT id, row_number() OVER (ORDER BY embedding <=> '[...]'::vector) AS rank
    FROM documents
    ORDER BY embedding <=> '[...]'::vector
    LIMIT 100
)
SELECT d.id, d.title,
       coalesce(1.0 / (60 + f.rank), 0) + coalesce(1.0 / (60 + s.rank), 0) AS rrf_score
FROM documents d
LEFT JOIN fts_ranked f ON f.id = d.id
LEFT JOIN sem_ranked s ON s.id = d.id
WHERE f.id IS NOT NULL OR s.id IS NOT NULL
ORDER BY rrf_score DESC
LIMIT 20;
```

RRF is more robust than score normalization because it is rank-based and not sensitive to score scale differences between retrieval methods.

### Highlighting results
```sql
-- blocked: Docker not accessible
SELECT id, title,
       ts_headline('english', body,
           plainto_tsquery('english', 'postgresql performance'),
           'MaxWords=50, MinWords=15, ShortWord=3, HighlightAll=false'
       ) AS excerpt
FROM documents
WHERE search_vector @@ plainto_tsquery('english', 'postgresql performance');
```

## Micro-concepts
- **lexeme**: the normalized form of a word after stemming and stop-word removal. "Running" → "run", "the" → (removed as stop word).
- **GIN pending list**: FTS GIN updates are batched. Under high insert load, the pending list is drained by VACUUM or explicit `VACUUM table` — until then, searches are slightly slower.
- **phraseto_tsquery**: the `<->` operator requires position information in the tsvector. Works only when the column stores full positional tsvector (not with some pre-processing approaches that strip positions).
- **ts_stat**: analyze usage across a tsvector column: most common words, their document frequency. Useful for identifying stop words specific to your corpus.
- **`@@` operator**: FTS match. Can use indexes only when the left side is a GIN-indexed column or expression.
- **Trigram vs FTS**: trigram (pg_trgm) matches substrings without language awareness. FTS matches stems with language awareness. Trigram is better for code/identifier search; FTS is better for natural language.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Use `to_tsvector` and `to_tsquery` with a GIN index. ORDER BY `ts_rank`.

**Intermediate view**: Use `websearch_to_tsquery` for user input. Store tsvector as a generated column. Use `ts_rank_cd` for cover density. Add `pg_trgm` for substring matching.

**Advanced view**: Phrase search requires positional tsvectors — verify your indexing pipeline preserves them. Custom text search configurations with unaccent and synonym dictionaries require filesystem access and superuser privileges — plan them as infrastructure changes. Hybrid search scoring with RRF is more portable than score normalization. Pre-filter with FTS before vector search when the document set is large (FTS reduces the candidate set for expensive vector distance computation).

## Mental model
FTS is a librarian who has read every book and knows which books contain which words (and their stems). They can quickly find all books about "running" (which finds "run," "runs," "ran"). But if you say "I want books about Python programming performance, and something about the feel of the topic," the librarian needs a second expert — the semantic search system (pgvector) — who understands meaning, not just words. Hybrid search combines both experts' ranked lists into one result.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_ts_config`, `pg_ts_dict`, `pg_ts_parser`, `ts_stat()` aggregate function.

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Test a text search configuration
SELECT ts_lexize('english', 'running');        -- 'run'
SELECT ts_lexize('english', 'postgresql');     -- not stemmed: '{postgresql}'

-- Check available configurations
SELECT cfgname FROM pg_ts_config;

-- Word frequency analysis
SELECT word, ndoc, nentry FROM ts_stat('SELECT search_vector FROM documents')
ORDER BY ndoc DESC LIMIT 20;
```

**Non-SQL / hybrid view**: Elasticsearch provides more advanced FTS (BM25, field boosting, faceting). Use PostgreSQL FTS when: data is already in PostgreSQL, latency requirements allow 10-100ms, result set is < 10M documents. Use Elasticsearch when: full-text is the primary use case, sub-millisecond FTS is required, or advanced aggregations (facets, histograms) are needed.

## Design principle
**Store tsvector, not raw text**: Generating `tsvector` at query time is expensive and prevents effective index use. Always store a pre-computed, GIN-indexed `tsvector` column (use `GENERATED ALWAYS AS ... STORED` or a trigger). This collapses the extraction cost to insert time and makes queries fast and simple.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: Hybrid search scoring is not automatically better than FTS alone. The semantic component requires embedding quality and alignment with the query domain. If embeddings are trained on a different domain (generic web text vs. technical documentation), the semantic scores can degrade result quality. Always benchmark FTS-only, semantic-only, and hybrid approaches on your specific document corpus and query set.

**Creative**: Use FTS for candidate pre-filtering, then vector search for re-ranking. This is the "pre-filter" pattern: `WHERE search_vector @@ query` reduces 10M documents to 10K; vector search ranks the 10K. This is much faster than computing vector distance for all 10M documents.

**Systems**: A GIN index on a `tsvector` column is updated synchronously on every insert (or via pending list if `fastupdate=on`). For a high-volume document ingestion pipeline, consider using `fastupdate=off` or explicitly draining the pending list with periodic `VACUUM` to control read performance during heavy writes. In a write-heavy + read-heavy mixed workload, GIN pending list drain can cause read latency spikes.

## MCP and agent perspective
Hybrid search is the core retrieval mechanism for AI agent memory systems. The agent's semantic memory (embeddings) handles concept-level recall; FTS handles exact terminology, variable names, or specific error messages that embeddings may not capture precisely. Implement hybrid search at the database layer (not application layer) using CTEs so the combined result is produced in one query round-trip. Use RRF for score combination — it is less sensitive to embedding model choice than linear interpolation of raw scores.

## Ontology perspective
FTS and semantic search represent two epistemological positions: FTS embodies lexical epistemology (meaning is carried in words and their forms), while semantic search embodies distributional semantics (meaning is derived from co-occurrence patterns across a corpus). Hybrid search is epistemological pluralism: neither approach alone captures the full richness of human meaning, so both are required. RRF is an agnostic combiner that doesn't privilege either model's theory of meaning.

## Practice session

**Exercise 1 — Phrase search**: Match exact phrase "machine learning".
```sql
-- blocked: Docker not accessible
SELECT id, title FROM documents
WHERE search_vector @@ phraseto_tsquery('english', 'machine learning')
ORDER BY ts_rank_cd(search_vector, phraseto_tsquery('english', 'machine learning')) DESC;
```

**Exercise 2 — Weighted search**: Boost title matches over body.
```sql
-- blocked: Docker not accessible
SELECT id, title,
       ts_rank(
           setweight(to_tsvector('english', title), 'A') ||
           setweight(to_tsvector('english', body), 'C'),
           plainto_tsquery('english', 'search query')
       ) AS rank
FROM documents
WHERE (
    setweight(to_tsvector('english', title), 'A') ||
    setweight(to_tsvector('english', body), 'C')
) @@ plainto_tsquery('english', 'search query')
ORDER BY rank DESC LIMIT 10;
```

**Exercise 3 — WebSearch syntax**: User-friendly query interface.
```sql
-- blocked: Docker not accessible
SELECT id, title FROM documents
WHERE search_vector @@ websearch_to_tsquery('english', '"full text" -basic')
ORDER BY ts_rank_cd(search_vector, websearch_to_tsquery('english', '"full text" -basic')) DESC;
```

**Exercise 4 — ts_headline extraction**: Generate excerpts with highlights.
```sql
-- blocked: Docker not accessible
SELECT id,
       ts_headline('english', body,
           plainto_tsquery('english', 'vacuum autovacuum'),
           'MaxWords=30, MinWords=10'
       ) AS excerpt
FROM documents
WHERE search_vector @@ plainto_tsquery('english', 'vacuum autovacuum')
LIMIT 5;
```

**Exercise 5 — Trigram similarity**: Fuzzy name matching without FTS.
```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS pg_trgm;
SELECT name, similarity(name, 'postgresql') AS sim
FROM technologies
WHERE name % 'postgresql'
ORDER BY sim DESC;
```

## References
- PostgreSQL Documentation: [Full Text Search](https://www.postgresql.org/docs/16/textsearch.html)
- PostgreSQL Documentation: [Text Search Functions and Operators](https://www.postgresql.org/docs/16/functions-textsearch.html)
- PostgreSQL Documentation: [Text Search Configuration](https://www.postgresql.org/docs/16/textsearch-configuration.html)
- PostgreSQL Documentation: [pg_trgm](https://www.postgresql.org/docs/16/pgtrgm.html)
- Oleg Bartunov & Teodor Sigaev: [Full Text Search in PostgreSQL](http://www.sai.msu.su/~megera/postgres/fts/)
- Reciprocal Rank Fusion: Cormack, Clarke, Buettcher (2009) — original RRF paper
