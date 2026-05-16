# Hybrid Search System Example

Level: Advanced
Domain: Combined full-text search and vector similarity search with weighted ranking
Synthetic data: Yes

## Overview

A hybrid search system for a fictional research article database called "Nexus".
Demonstrates how to combine two complementary retrieval signals in a single
PostgreSQL query:

- **Full-text search (FTS)** — keyword precision via `tsvector` and `ts_rank`.
- **Vector similarity** — semantic proximity via `pgvector` cosine distance.
- **Hybrid ranking** — linearly combine both normalised scores; tune α to weight
  keyword vs. semantic relevance.

Schema note: `vector(3)` is used here for demonstration. Real systems use
`vector(1536)` (OpenAI text-embedding-3-small) or `vector(4096)` (Llama 3).
The schema and queries are identical regardless of dimension.

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE articles (
    id              BIGSERIAL   PRIMARY KEY,
    title           TEXT        NOT NULL,
    body            TEXT        NOT NULL DEFAULT '',
    author          TEXT        NOT NULL,
    published_at    DATE,
    tsvector_body   TSVECTOR,            -- pre-computed; maintained by trigger
    embedding       VECTOR(3)   NOT NULL,-- demo: 3-dim; production: 1536-dim
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- GIN index for fast full-text search
CREATE INDEX idx_articles_fts       ON articles USING GIN (tsvector_body);

-- IVFFlat index for approximate vector nearest-neighbour
-- lists=1 for tiny dataset; production: lists ≈ sqrt(row_count)
CREATE INDEX idx_articles_embedding ON articles
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 1);

-- Trigram index on title for fuzzy matching fallback
CREATE INDEX idx_articles_title_trgm ON articles USING GIN (title gin_trgm_ops);

-- Trigger: keep tsvector_body current on INSERT / UPDATE
CREATE OR REPLACE FUNCTION fn_articles_tsvector()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.tsvector_body :=
        setweight(to_tsvector('english', coalesce(NEW.title,  '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.body,   '')), 'B');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_articles_tsvector
BEFORE INSERT OR UPDATE ON articles
FOR EACH ROW EXECUTE FUNCTION fn_articles_tsvector();
```

## Seed data

Embeddings are hand-crafted 3-dimensional vectors to illustrate semantic
proximity. In a real system these would come from an embedding model.

```sql
-- Dimension interpretation (for demo only):
--   dim 0: database/systems content
--   dim 1: machine learning / AI content
--   dim 2: programming / code content

INSERT INTO articles (title, body, author, published_at, embedding) VALUES

  ('PostgreSQL Full-Text Search Deep Dive',
   'Full-text search in PostgreSQL is powered by tsvector and tsquery types. '
   'GIN indexes make FTS fast on large corpora. ts_rank scores results by term '
   'frequency and position weighting. Use plainto_tsquery for user input.',
   'Alice Moreno', '2024-01-10',
   '[0.9, 0.1, 0.3]'),

  ('Vector Embeddings and Semantic Search',
   'Vector embeddings represent text as dense numeric arrays. Cosine similarity '
   'measures the angle between two vectors. Nearest-neighbour search retrieves '
   'the most semantically similar documents without exact keyword overlap.',
   'Bob Stein', '2024-02-14',
   '[0.4, 0.9, 0.2]'),

  ('Hybrid Retrieval: Combining BM25 and Dense Vectors',
   'Hybrid search fuses lexical BM25 scores with dense vector similarity. '
   'Reciprocal Rank Fusion and linear combination are two common fusion strategies. '
   'PostgreSQL can approximate this with ts_rank and pgvector cosine distance.',
   'Carol Huang', '2024-03-05',
   '[0.7, 0.8, 0.3]'),

  ('pgvector: Practical Guide',
   'pgvector adds VECTOR type support to PostgreSQL. Operators: <-> L2 distance, '
   '<#> negative inner product, <=> cosine distance. IVFFlat provides approximate '
   'search; HNSW provides higher recall. Choose dimensions based on your model.',
   'Alice Moreno', '2024-03-22',
   '[0.8, 0.7, 0.2]'),

  ('EXPLAIN ANALYZE for Query Optimisation',
   'EXPLAIN ANALYZE executes the query and shows actual vs. estimated row counts. '
   'Look for seq scans on large tables, nested loops with bad row estimates, and '
   'sort spills to disk. Use enable_seqscan = off to force index usage for testing.',
   'David Park', '2024-04-01',
   '[0.8, 0.1, 0.6]'),

  ('Building RAG Pipelines with PostgreSQL',
   'Retrieval-Augmented Generation (RAG) combines a vector retrieval step with '
   'an LLM generation step. PostgreSQL with pgvector can serve as the retrieval '
   'layer. Chunk documents, embed chunks, store in a vector table, retrieve top-k.',
   'Bob Stein', '2024-04-18',
   '[0.5, 0.9, 0.4]'),

  ('Understanding MVCC in PostgreSQL',
   'Multi-Version Concurrency Control (MVCC) gives each transaction a snapshot '
   'of the database. Writers do not block readers. Dead tuples accumulate and '
   'must be reclaimed by VACUUM. MVCC enables serializable isolation.',
   'Eve Santos', '2024-05-02',
   '[0.9, 0.1, 0.2]'),

  ('Fine-Tuning Language Models on Synthetic Data',
   'Synthetic data generation using LLMs can bootstrap fine-tuning datasets. '
   'Key concerns: diversity, factual accuracy, and distribution shift. '
   'Evaluate fine-tuned models on held-out human-labelled benchmarks.',
   'Carol Huang', '2024-05-20',
   '[0.1, 0.9, 0.5]');
```

## Example queries

### Pure full-text search

```sql
-- Keyword search for "vector embeddings pgvector"
SELECT id,
       title,
       author,
       ts_rank(tsvector_body, query) AS fts_score
FROM   articles,
       plainto_tsquery('english', 'vector embeddings pgvector') AS query
WHERE  tsvector_body @@ query
ORDER  BY fts_score DESC;
```

### Pure vector similarity search (k-NN)

```sql
-- Query vector: high on dimension 1 (AI/ML), moderate on 0 and 2
-- In production this vector comes from your embedding model
SELECT id,
       title,
       author,
       embedding <=> '[0.5, 0.9, 0.3]' AS cosine_distance
FROM   articles
ORDER  BY cosine_distance
LIMIT  5;
```

### Hybrid search: linear combination of FTS and vector scores

```sql
-- α controls the FTS/vector balance: 1.0 = pure FTS, 0.0 = pure vector
-- Scores are normalised to [0, 1] range before combination.

WITH fts_results AS (
    SELECT id,
           ts_rank(tsvector_body, query)  AS raw_fts
    FROM   articles,
           plainto_tsquery('english', 'semantic retrieval embeddings') AS query
    WHERE  tsvector_body @@ query
),
fts_normalised AS (
    SELECT id,
           raw_fts,
           raw_fts / NULLIF(MAX(raw_fts) OVER (), 0) AS fts_score
    FROM   fts_results
),
vector_results AS (
    SELECT id,
           -- Convert distance to similarity: similarity = 1 - distance
           1 - (embedding <=> '[0.5, 0.85, 0.3]') AS raw_vec
    FROM   articles
    ORDER  BY embedding <=> '[0.5, 0.85, 0.3]'
    LIMIT  20
),
vec_normalised AS (
    SELECT id,
           raw_vec,
           raw_vec / NULLIF(MAX(raw_vec) OVER (), 0) AS vec_score
    FROM   vector_results
),
combined AS (
    SELECT
        COALESCE(f.id, v.id)          AS id,
        COALESCE(f.fts_score, 0)      AS fts_score,
        COALESCE(v.vec_score, 0)      AS vec_score,
        -- α = 0.5: equal weight to both signals
        0.5 * COALESCE(f.fts_score, 0) +
        0.5 * COALESCE(v.vec_score, 0) AS hybrid_score
    FROM   fts_normalised f
    FULL   OUTER JOIN vec_normalised v ON v.id = f.id
)
SELECT c.id,
       a.title,
       a.author,
       ROUND(c.fts_score::NUMERIC,    4) AS fts_score,
       ROUND(c.vec_score::NUMERIC,    4) AS vec_score,
       ROUND(c.hybrid_score::NUMERIC, 4) AS hybrid_score
FROM   combined c
JOIN   articles a ON a.id = c.id
ORDER  BY hybrid_score DESC
LIMIT  10;
```

### Reciprocal Rank Fusion (RRF) alternative

```sql
-- RRF: score = sum(1 / (k + rank)) where k is a smoothing constant (typically 60)
-- RRF is robust to different score scales and does not require normalisation.

WITH fts_ranked AS (
    SELECT id,
           ROW_NUMBER() OVER (ORDER BY ts_rank(tsvector_body, query) DESC) AS fts_rank
    FROM   articles,
           plainto_tsquery('english', 'vector database retrieval') AS query
    WHERE  tsvector_body @@ query
),
vec_ranked AS (
    SELECT id,
           ROW_NUMBER() OVER (ORDER BY embedding <=> '[0.6, 0.8, 0.3]') AS vec_rank
    FROM   articles
    LIMIT  20
)
SELECT a.id,
       a.title,
       ROUND(
         COALESCE(1.0 / (60 + f.fts_rank), 0) +
         COALESCE(1.0 / (60 + v.vec_rank), 0), 6
       ) AS rrf_score
FROM   articles a
LEFT   JOIN fts_ranked f ON f.id = a.id
LEFT   JOIN vec_ranked v ON v.id = a.id
WHERE  f.id IS NOT NULL OR v.id IS NOT NULL
ORDER  BY rrf_score DESC;
```

### Author-filtered vector search

```sql
SELECT id,
       title,
       embedding <=> '[0.8, 0.6, 0.2]' AS distance
FROM   articles
WHERE  author = 'Alice Moreno'
ORDER  BY distance
LIMIT  5;
```

### Date-filtered semantic search

```sql
SELECT id,
       title,
       published_at,
       embedding <=> '[0.4, 0.9, 0.4]' AS distance
FROM   articles
WHERE  published_at >= '2024-04-01'
ORDER  BY distance
LIMIT  5;
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

SELECT COUNT(*) FROM articles;
-- Expected: 8

-- tsvector populated
SELECT COUNT(*) FROM articles WHERE tsvector_body IS NOT NULL;
-- Expected: 8

-- Extensions present
SELECT extname FROM pg_extension WHERE extname IN ('vector','pg_trgm');

-- Vector index exists
SELECT indexname FROM pg_indexes
WHERE tablename = 'articles' AND indexname = 'idx_articles_embedding';

-- FTS works
SELECT COUNT(*) FROM articles
WHERE tsvector_body @@ plainto_tsquery('english', 'vector');
-- Expected: >= 4

-- Vector search returns ordered results
SELECT id, title, embedding <=> '[0.5, 0.9, 0.3]' AS dist
FROM articles ORDER BY dist LIMIT 3;
```

## Practice tasks

1. **Tune α.** Run the hybrid search with α=0.3 (bias toward vector) and α=0.7
   (bias toward FTS). Does the ranking change? Which value gives more intuitive
   results for the query "database performance optimisation"?

2. **Add an article and search for it.** Insert an article about "connection
   pooling with PgBouncer" with an appropriate embedding vector. Run both pure
   FTS and pure vector queries. Does the article appear in both result sets?

3. **RRF vs linear.** Compare the top-5 results of Reciprocal Rank Fusion vs
   the linear combination for the same query. Which approach is more stable when
   one component returns few results?

4. **EXPLAIN ANALYZE on vector search.** Run `EXPLAIN ANALYZE SELECT ... ORDER BY
   embedding <=> '[0.5, 0.9, 0.3]' LIMIT 5`. Does it use the IVFFlat index?
   What happens if you increase `ivfflat.probes`?

5. **Production dimensionality.** The schema uses `vector(3)`. Change it to
   `vector(384)` (sentence-transformers model size). What changes in the index
   definition? Why is the `lists` parameter in `ivfflat` important for larger
   datasets?

## MCP and agent perspective

An AI agent using this schema as a retrieval layer would:

- **Embed the user's query** — call an embedding API (OpenAI, Ollama) to get
  the query vector, then pass it to the hybrid search query.
- **Return ranked context** — the top-k hybrid results become the context
  window for the LLM response generation step (RAG pattern).
- **Favour hybrid over pure vector** — keyword matches handle named entities
  and exact terms that embeddings can miss; vector search handles paraphrasing
  and synonyms that keywords miss.
- **Tune α per use case** — technical documentation search benefits from higher
  FTS weight (exact terms matter); conversational recall benefits from higher
  vector weight.
- **Transparent to callers** — the agent exposes a single `search(query, k)`
  function; the hybrid SQL is an implementation detail.

## Teardown

```sql
DROP TRIGGER  IF EXISTS trg_articles_tsvector ON articles;
DROP FUNCTION IF EXISTS fn_articles_tsvector();
DROP TABLE    IF EXISTS articles;
DROP EXTENSION IF EXISTS pg_trgm;
DROP EXTENSION IF EXISTS vector;
```

## References

- pgvector: https://github.com/pgvector/pgvector
- pgvector HNSW vs IVFFlat: https://github.com/pgvector/pgvector#indexing
- Reciprocal Rank Fusion: https://plg.uwaterloo.ca/~gvcormac/cormacksigir09-rrf.pdf
- ts_rank weights: https://www.postgresql.org/docs/current/textsearch-controls.html
- RAG with PostgreSQL: https://github.com/pgvector/pgvector-python/tree/master/examples
