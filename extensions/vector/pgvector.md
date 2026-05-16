# pgvector (vector)

Level: Intermediate
Available locally: Yes

## One-line purpose

Store and search high-dimensional vector embeddings using L2, cosine, or inner product distance directly in PostgreSQL.

## Why this exists

LLMs and embedding models produce dense vectors (e.g., 1536-dimensional floats from OpenAI `text-embedding-3-small`). Storing those vectors in the same database as your relational data and querying them with SQL eliminates a separate vector store (Pinecone, Qdrant, Weaviate) for most workloads. pgvector makes PostgreSQL a first-class vector database.

## Install

```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS vector;
SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';
```

## Core operations

### Define a table with a vector column

```sql
-- blocked: Docker not accessible
CREATE TABLE documents (
    id        SERIAL PRIMARY KEY,
    content   TEXT,
    embedding vector(1536)   -- dimension must match your model output
);
```

### Insert a vector

```sql
-- blocked: Docker not accessible
INSERT INTO documents (content, embedding)
VALUES ('The sky is blue', '[0.1, 0.04, ...]');  -- 1536 floats
```

### Distance operators

| Operator | Distance type | Notes |
|----------|--------------|-------|
| `<->`    | L2 (Euclidean) | Default; good for absolute position |
| `<=>`    | Cosine | Best for normalized semantic similarity |
| `<#>`    | Negative inner product | Fastest; requires normalized vectors |

```sql
-- blocked: Docker not accessible
-- Find 5 nearest neighbors by cosine distance
SELECT id, content, embedding <=> '[0.1, 0.04, ...]'::vector AS distance
FROM documents
ORDER BY embedding <=> '[0.1, 0.04, ...]'::vector
LIMIT 5;
```

### Exact distance functions (no index needed)

```sql
-- blocked: Docker not accessible
SELECT l2_distance(embedding, '[0.1, ...]'::vector)       AS l2,
       cosine_distance(embedding, '[0.1, ...]'::vector)   AS cosine,
       inner_product(embedding, '[0.1, ...]'::vector)     AS ip
FROM documents
LIMIT 10;
```

## Index types

### ivfflat — Inverted File with Flat quantization

Partitions vectors into `lists` Voronoi cells; query probes `probes` of them.

```sql
-- blocked: Docker not accessible
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- At query time: trade recall for speed
SET ivfflat.probes = 10;
```

- Build time: fast (minutes on millions of rows)
- Recall: ~95–99% with tuned probes
- Best for: stable datasets where approximate results are acceptable
- Rule of thumb: `lists` ≈ `rows / 1000` (min 100)

### hnsw — Hierarchical Navigable Small World

Builds a multi-layer proximity graph.

```sql
-- blocked: Docker not accessible
CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- At query time
SET hnsw.ef_search = 40;
```

- Build time: slower, uses more memory during build
- Recall: higher than ivfflat at equivalent speed
- Best for: read-heavy workloads needing high recall; datasets that change frequently
- Parameters: `m` = connections per node (8–64), `ef_construction` = build quality (64–200)

### Operator class mapping

| Distance | ivfflat op class | hnsw op class |
|----------|-----------------|---------------|
| L2 | `vector_l2_ops` | `vector_l2_ops` |
| Cosine | `vector_cosine_ops` | `vector_cosine_ops` |
| Inner product | `vector_ip_ops` | `vector_ip_ops` |

## Performance characteristics

- Sequential scan (no index): exact results; ~O(n) per query; fine for < 100k rows
- ivfflat: sub-linear lookup; lower memory footprint than hnsw
- hnsw: best query-time recall/speed tradeoff; index size is larger (~2–4× raw vector bytes)
- Both indexes support parallel builds (set `max_parallel_maintenance_workers`)
- `vector_dims(embedding)` and `vector_norm(embedding)` are utility functions

## When to use

- Semantic search over text, images, or audio
- RAG (Retrieval-Augmented Generation): find relevant context chunks before calling an LLM
- Recommendation systems: find items similar to a user's history
- Duplicate/near-duplicate detection at scale
- Combining vector similarity with relational filters in a single query

## When NOT to use

- Exact keyword search — use `pg_trgm` or full-text search (`tsvector`) instead
- Very high dimensions (> 2000) with large datasets — performance degrades; dedicated vector stores may be better
- Real-time pipelines needing sub-millisecond p99 — purpose-built ANN stores (Qdrant, Weaviate) have lower latency at extreme scale
- If you need multi-modal or sparse + dense hybrid search natively

## Alternatives

| Alternative | When to prefer |
|-------------|---------------|
| Qdrant | Sub-ms latency, payload filtering, no SQL needed |
| Pinecone | Fully managed, minimal ops burden |
| Weaviate | Built-in embedding models, multi-modal |
| pg_embedding (Neon) | Drop-in pgvector alternative using HNSW only |
| milvus | Billion-scale vector workloads |

## MCP and agent perspective

Agents using pgvector as a memory store can:

- **Retrieve relevant memory**: `SELECT content FROM memory ORDER BY embedding <=> $1 LIMIT 5` — pass current turn embedding as `$1`
- **Semantic deduplication**: before inserting a new memory, check `cosine_distance < 0.05` to avoid near-duplicate storage
- **Hybrid retrieval**: combine vector similarity with a `WHERE session_id = $session` clause so memory is scoped per user/session
- **Tool call result caching**: embed tool descriptions; find semantically similar past calls before re-executing
- Critical: never log raw embedding arrays — they are large and leak content implicitly; log only IDs and distances

## Ontology connection

- Lives under `extensions/vector/` because it introduces a new column type, not just a function
- Connects to: `pg_trgm` (text similarity), `hstore` / JSONB (metadata filtering alongside vector search), `pg_stat_statements` (monitor embedding query cost)
- Concept map: vector similarity search → approximate nearest neighbor → HNSW / IVFFlat

## References

- [pgvector GitHub](https://github.com/pgvector/pgvector)
- [pgvector HNSW docs](https://github.com/pgvector/pgvector#hnsw)
- [PostgreSQL indexing overview](https://www.postgresql.org/docs/16/indexes.html)
