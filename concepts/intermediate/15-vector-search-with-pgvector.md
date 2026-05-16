# Vector Search with pgvector
Level: Intermediate

## One-line intuition
pgvector stores high-dimensional embedding vectors in PostgreSQL and enables nearest-neighbor search with ANN indexes — the foundation for semantic search and RAG pipelines without leaving your database.

## Why this exists
Modern AI applications need to find semantically similar items: documents like a query, images like a reference, products like a description. This requires comparing embedding vectors (dense float arrays from ML models) by distance. pgvector brings this capability into PostgreSQL, eliminating the need for a separate vector database.

## First-principles explanation
An **embedding** is a fixed-length array of floats that encodes semantic meaning. Similar concepts (semantically) have embeddings that are geometrically close in high-dimensional space.

**Distance metrics:**

| Operator | Metric | Use case |
|---|---|---|
| `<->` | L2 (Euclidean) distance | Image similarity, spatial proximity |
| `<=>` | Cosine distance | Text embeddings (normalized) |
| `<#>` | Negative inner product | When vectors are unit-normalized |

**Index types:**

| Index | Algorithm | Build | Query |
|---|---|---|---|
| None (exact) | Exact KNN scan | Instant | Slow (full scan) |
| `ivfflat` | Inverted file with flat quantization | Fast | Good recall, tunable |
| `hnsw` | Hierarchical Navigable Small World | Slower | Best recall and speed |

**ivfflat** divides vectors into `lists` clusters; a query searches the nearest `probes` clusters. Increase `probes` for better recall at cost of speed.

**hnsw** builds a layered proximity graph. Recall is high by default. `m` (connections per node) and `ef_construction` (build-time search depth) control quality vs build time.

## Micro-concepts
- **vector(N)** — pgvector column type for an N-dimensional float array
- **L2 distance** — `sqrt(sum((a_i - b_i)^2))` — raw distance in vector space
- **cosine distance** — `1 - dot(a,b)/(|a|*|b|)` — angle between vectors; preferred for text
- **inner product** — `dot(a,b)` — faster computation when vectors are unit-normalized
- **KNN (K-nearest neighbors)** — find K vectors closest to a query vector
- **ANN (approximate nearest neighbors)** — trade small recall loss for large speed gain
- **ivfflat lists** — number of Voronoi cells; `sqrt(n_rows)` is a common starting point
- **hnsw m** — graph connectivity; 16 is a common default
- **RAG (Retrieval-Augmented Generation)** — pattern: embed query, find top-k similar chunks, pass to LLM
- **Ollama** — local embedding model server; produces embeddings without cloud API

## Beginner view
Embeddings are like coordinates in a semantic space. "King" and "Queen" are neighbors; "King" and "Automobile" are far apart. pgvector is a ruler for measuring those distances and an index for finding the nearest neighbors efficiently.

## Intermediate view
The typical workflow:
1. Generate embeddings for your documents using an embedding model (OpenAI `text-embedding-3-small`, Ollama `nomic-embed-text`, etc.)
2. Store them in a `vector(N)` column (e.g., `vector(1536)` for OpenAI, `vector(768)` for nomic-embed)
3. Create an hnsw or ivfflat index for fast ANN search
4. At query time, embed the user's query and find top-k nearest neighbors

For RAG, the retrieved chunks are added to the LLM's context window as "evidence" for answering the query.

## Advanced view
**ivfflat tuning:**
- `lists` = `sqrt(num_rows)` for index build; increase for larger tables
- `SET ivfflat.probes = 10` at query time for higher recall (default 1)
- Build index after inserting data — ivfflat requires data to cluster centers

**hnsw tuning:**
- `m` controls graph connectivity (default 16); higher = better recall, more memory
- `ef_construction` controls build-time accuracy (default 64)
- `SET hnsw.ef_search = 100` at query time for higher recall (default 40)

**Hybrid search:** combine vector similarity with structured filters:
```sql
SELECT id, content, embedding <=> query_vec AS dist
FROM documents
WHERE category = 'technical'
ORDER BY embedding <=> query_vec
LIMIT 10;
```
Pre-filtering (`WHERE`) reduces candidates; the ANN index searches within the filtered set.

## Mental model
Imagine a library where books are placed on shelves by topic similarity, not by title. To find books on "machine learning", you walk to the "machine learning" section (nearest cluster) and browse nearby shelves. ivfflat is this section + shelf system. hnsw is a network of signposts throughout the library, each pointing to the nearest related shelf — faster navigation at the cost of building the signpost network.

## PostgreSQL view
```sql
-- blocked: Docker not accessible in this session
-- (SQL is correct; run when Docker is available)

CREATE EXTENSION IF NOT EXISTS vector;

-- Documents table with embedding column
CREATE TABLE documents (
    id        SERIAL PRIMARY KEY,
    content   TEXT NOT NULL,
    category  TEXT,
    embedding vector(3)  -- toy dimension for exercises; use 768/1536 in production
);

-- Synthetic embeddings (in production, generate with Ollama or OpenAI)
INSERT INTO documents (content, category, embedding) VALUES
    ('PostgreSQL is a relational database', 'technical', '[0.1, 0.8, 0.3]'),
    ('Python is a programming language',   'technical', '[0.2, 0.7, 0.4]'),
    ('Coffee is a morning beverage',       'food',      '[0.9, 0.1, 0.2]'),
    ('Tea is also a morning drink',        'food',      '[0.85, 0.15, 0.3]'),
    ('SQL joins merge relational tables',  'technical', '[0.15, 0.75, 0.35]');

-- HNSW index for cosine distance
CREATE INDEX ON documents USING hnsw(embedding vector_cosine_ops);

-- KNN search: most similar to query vector
SELECT id, content,
       embedding <=> '[0.1, 0.8, 0.3]'::vector AS cosine_dist
FROM documents
ORDER BY embedding <=> '[0.1, 0.8, 0.3]'::vector
LIMIT 3;

-- Hybrid: filter by category, then rank by similarity
SELECT id, content,
       embedding <=> '[0.1, 0.8, 0.3]'::vector AS dist
FROM documents
WHERE category = 'technical'
ORDER BY embedding <=> '[0.1, 0.8, 0.3]'::vector
LIMIT 5;

-- IVFFlat alternative (better for bulk insert scenarios)
DROP INDEX IF EXISTS documents_embedding_idx;
CREATE INDEX ON documents USING ivfflat(embedding vector_l2_ops) WITH (lists = 10);

-- Check index usage
EXPLAIN SELECT * FROM documents
ORDER BY embedding <-> '[0.1, 0.8, 0.3]'::vector
LIMIT 5;
```

## Embedding generation with Ollama (local)
```python
# blocked: Docker not accessible in this session
# Example code for when Docker is available

import ollama
import psycopg2

def embed(text: str) -> list[float]:
    result = ollama.embeddings(model='nomic-embed-text', prompt=text)
    return result['embedding']  # 768-dimensional vector

def store_document(conn, content: str, category: str):
    vec = embed(content)
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO documents (content, category, embedding) VALUES (%s, %s, %s)",
            (content, category, vec)
        )
    conn.commit()

def semantic_search(conn, query: str, k: int = 5):
    vec = embed(query)
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, content, embedding <=> %s::vector AS dist
            FROM documents
            ORDER BY dist
            LIMIT %s
        """, (vec, k))
        return cur.fetchall()
```

## SQL view
pgvector is PostgreSQL-specific. Alternatives: pgvector-compatible APIs exist in Supabase, Neon, AlloyDB. Purpose-built vector databases: Pinecone, Weaviate, Qdrant, Chroma. These offer more advanced filtering and scaling features but require a separate service.

## Non-SQL or hybrid view
For production RAG at scale, many teams use PostgreSQL (pgvector) for moderate corpora (<10M vectors) and Qdrant/Pinecone for very large corpora. The decision point is typically when ANN recall falls below acceptable levels with ivfflat tuning, or when latency requirements demand sub-10ms KNN at millions of QPS.

## Design principle
**Start with pgvector; migrate to a dedicated vector database only when you have measurable evidence that PostgreSQL's ANN performance is insufficient.** Keeping vectors in PostgreSQL enables transactional consistency (embed + store in one transaction), simplified backup/restore, and SQL joins against relational metadata — advantages that dedicated vector databases sacrifice.

## Critical thinking
- Cosine distance and L2 distance give different rankings. For text embeddings from transformer models, cosine is almost always correct (models produce direction, not magnitude). For image embeddings, L2 may be appropriate.
- ivfflat gives deterministic recall (same results every time) with correct `probes` tuning. hnsw gives probabilistic recall (results may vary slightly between queries) but typically better recall at the same speed.
- Embedding models are not interchangeable — embeddings from different models are not comparable. If you switch models, you must re-embed all documents.

## Creative thinking
Use pgvector for ontology-aware search: embed ontology concept names and store them. When a user searches for "transaction safety", the nearest neighbors in embedding space will include "ACID", "isolation", "concurrency" — semantic neighbors even without keyword overlap. This creates a "semantic index" over the ontology graph.

## Systems thinking
Embedding generation is the latency bottleneck in a RAG pipeline, not the vector search. Pre-compute and store embeddings at write time. Use a queue (job_queue pattern from Practice 05) to handle embedding generation asynchronously. Cache frequently-used query embeddings. Monitor `pg_stat_user_tables` for the documents table — high write throughput will trigger frequent index rebuilds for ivfflat.

## MCP and agent perspective
An MCP agent implementing RAG should:
1. Receive a natural language query
2. Embed it using a consistent model
3. Execute `SELECT ... ORDER BY embedding <=> $1 LIMIT $2` with the query vector
4. Pass retrieved chunks + original query to the LLM
5. Return the LLM's response with source document IDs for attribution

The agent should expose `k` (number of retrieved chunks) as a configurable parameter and experiment with different values — too few chunks miss context; too many exceed the LLM's context window.

## Ontology perspective
In an ontology, embedding-based similarity is a form of **semantic proximity**: concepts with overlapping properties (in the embedding model's learned representation) are spatially close. pgvector enables ontology navigation without explicit edge definitions — the edges are implicit in the embedding geometry. A query is a traversal from a concept to its semantic neighborhood, discovering connections the ontology author may not have explicitly defined.

This is "emergent ontology" — the embedding model has learned a representation of concept space from training data, and the vector index allows queries against that representation.

## Practice session
See `practice/intermediate/09-pgvector-retrieval/` for hands-on exercises with synthetic embeddings and KNN search.

## References
- pgvector GitHub: https://github.com/pgvector/pgvector
- pgvector documentation (operators, index types): https://github.com/pgvector/pgvector/blob/master/README.md
- Ollama embedding models: https://ollama.com/library
- "pgvector vs Pinecone vs Weaviate": https://supabase.com/blog/pgvector-vs-dedicated-vector-database
- "HNSW Algorithm": https://arxiv.org/abs/1603.09320
- "RAG with PostgreSQL and pgvector": https://www.timescale.com/blog/postgresql-as-a-vector-database-creating-storing-and-querying-openai-embeddings-with-pgvector/
