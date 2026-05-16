# Vector Search Ontology

Level: Advanced
Domain: PostgreSQL / AI / Extensions

## Definition
Vector search in PostgreSQL is the capability to store high-dimensional numerical vectors (embeddings) as a native column type and retrieve the most similar vectors using approximate or exact nearest-neighbor algorithms, enabling semantic search and AI memory patterns.

## Why this concept matters
Language models produce embeddings that encode meaning as vectors. Storing these in PostgreSQL via pgvector allows semantic search, RAG (Retrieval-Augmented Generation), and AI agent memory to live in the same transactional database as structured business data — eliminating a separate vector store dependency.

## Related concepts
- [[ai-agent-memory-ontology]] — parent (vector search powers semantic agent memory)
- [[index-ontology]] — parent (ivfflat and hnsw are index types)
- [[extension-ontology]] — parent (pgvector is an extension)
- [[performance-ontology]] — related (ANN index tuning, recall vs speed)
- [[schema-design-ontology]] — related (embedding column design)

---

## Embedding

One-line definition: A dense vector of floating-point numbers (typically 128–4096 dimensions) produced by a machine learning model that encodes the semantic meaning of text, images, or other data.

Properties:
- Similar inputs produce vectors that are geometrically close.
- Distance in vector space approximates semantic similarity.
- The same input always produces the same embedding (for a given model).

Common embedding models:
| Model | Dimensions | Use case |
|-------|-----------|---------|
| `text-embedding-ada-002` (OpenAI) | 1536 | General text |
| `text-embedding-3-small` (OpenAI) | 1536 | General text (smaller cost) |
| `text-embedding-3-large` (OpenAI) | 3072 | High-accuracy text |
| `nomic-embed-text` | 768 | Local/open source |
| `all-MiniLM-L6-v2` | 384 | Fast, lightweight |

---

## Vector Space

One-line definition: A mathematical space where each embedding occupies a point; similarity between embeddings is measured by geometric distance or angular relationship.

---

## Distance Metrics

### Cosine Similarity / Distance
One-line definition: Measures the angle between two vectors; 1.0 = identical direction, 0.0 = orthogonal; range [0, 2] for distance (0 = same, 2 = opposite); best for text embeddings normalized by magnitude.

Operator: `<=>` (cosine distance)

### L2 (Euclidean) Distance
One-line definition: The straight-line distance between two points in vector space; lower = more similar; sensitive to magnitude differences.

Operator: `<->` (L2 distance)

### Inner Product
One-line definition: The dot product of two vectors; for normalized vectors, equivalent to cosine similarity; used when vectors are pre-normalized.

Operator: `<#>` (negative inner product, since PostgreSQL minimizes)

---

## pgvector

One-line definition: A PostgreSQL extension that adds the `vector` data type, distance operators, and approximate nearest-neighbor index types (ivfflat, hnsw) for semantic search.

```sql
-- blocked: Docker not accessible
CREATE EXTENSION vector;

-- Create a table with an embedding column
CREATE TABLE documents (
    id          BIGSERIAL PRIMARY KEY,
    content     TEXT NOT NULL,
    embedding   vector(1536)  -- OpenAI ada-002 dimension
);

-- Insert with embedding (normally populated by application)
INSERT INTO documents (content, embedding)
VALUES ('PostgreSQL is a relational database', '[0.1, 0.2, ...]');

-- Exact nearest-neighbor search (no index; full scan)
SELECT id, content, embedding <=> '[0.1, 0.2, ...]' AS distance
FROM documents
ORDER BY embedding <=> '[0.1, 0.2, ...]'
LIMIT 10;
```

---

## Nearest-Neighbor Search

One-line definition: Given a query vector, find the K vectors in the database that are most geometrically similar; can be exact (KNN) or approximate (ANN).

**Exact KNN**: Scans every vector — O(n × d) where d = dimensions. Correct but slow for large datasets.
**Approximate ANN**: Uses an index to skip most comparisons; faster but may miss a small fraction of true nearest neighbors (controlled by `recall` parameter).

---

## ivfflat (Inverted File Flat)

One-line definition: An ANN index that divides vectors into `lists` clusters (cells) using k-means; at query time, searches the `probes` closest clusters.

```sql
-- blocked: Docker not accessible
-- Build ivfflat index (requires data already loaded)
CREATE INDEX idx_docs_embedding_ivfflat
    ON documents
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);  -- typically sqrt(n_rows)

-- At query time, probe more lists for higher recall
SET ivfflat.probes = 10;  -- default: 1; higher = more accurate, slower

SELECT id, content
FROM documents
ORDER BY embedding <=> '[...]'
LIMIT 10;
```

Tuning:
- `lists`: sqrt(n_rows) for up to 1M rows; higher for larger datasets.
- `probes`: 1/10 of `lists` as a starting point; increase for recall at cost of speed.
- Must rebuild index when data changes significantly (k-means centroids become stale).

---

## hnsw (Hierarchical Navigable Small World)

One-line definition: An ANN index that builds a multi-layer proximity graph; offers better recall and query speed than ivfflat but uses more memory and has longer build time.

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_docs_embedding_hnsw
    ON documents
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- At query time, control search width
SET hnsw.ef_search = 100;  -- default: 40; higher = better recall

SELECT id, content
FROM documents
ORDER BY embedding <=> '[...]'
LIMIT 10;
```

Parameters:
- `m`: Number of connections per layer (16 is a common default; higher = better recall, more memory).
- `ef_construction`: Search width during build (64–256); higher = better index quality, slower build.
- `ef_search`: Search width at query time; increase for better recall.

hnsw vs ivfflat:
| Property | hnsw | ivfflat |
|----------|------|---------|
| Build time | Slower | Faster |
| Memory | Higher | Lower |
| Query recall | Better | Tunable |
| Incremental insert | Good | Poor (centroid drift) |

---

## RAG (Retrieval-Augmented Generation)

One-line definition: A pattern where a language model's responses are grounded in content retrieved from a vector store: embed the query, find the K most similar documents, inject them into the LLM prompt as context.

PostgreSQL-based RAG pipeline:
1. Chunk documents into paragraphs.
2. Embed each chunk via an embedding model.
3. Store `(chunk_text, embedding)` in a `vector` column.
4. At query time: embed the user's question, run `ORDER BY embedding <=> $1 LIMIT K`, inject results into the prompt.

Related: [[ai-agent-memory-ontology]]

---

## Semantic Memory

One-line definition: An agent memory type where past interactions or knowledge are stored as embeddings and retrieved by semantic similarity rather than exact key lookup.

Related: [[ai-agent-memory-ontology]]

---

## System catalog reference
- `pg_extension` — verify pgvector is installed
- `pg_am` — index access methods (`ivfflat`, `hnsw` appear here after pgvector install)
- `pg_index` — index metadata including index type
- `pg_opclass` — operator classes (`vector_cosine_ops`, `vector_l2_ops`, `vector_ip_ops`)

---

## Beginner mental model
An embedding is a list of 1536 numbers that represents the "meaning" of a piece of text. pgvector lets PostgreSQL store these lists and find which ones are most similar to a query list. This is how you do "find semantically similar documents" in SQL.

## Intermediate mental model
Exact nearest-neighbor search scans every row — fine for thousands of records, impractical for millions. ivfflat and hnsw indexes trade a small amount of accuracy (recall) for large speed gains. Use hnsw for most new deployments — it handles incremental inserts better and has higher recall at the same speed. Use ivfflat when memory is constrained.

## Advanced mental model
Index quality degrades as data changes: ivfflat centroids become stale, hnsw graph connectivity weakens. For high-throughput insert workloads, prefer hnsw with periodic `REINDEX CONCURRENTLY`. Cosine distance is the correct metric for most LLM embeddings (they are normalized by the model). For pgvector 0.7+, enable `halfvec` storage to halve memory usage for high-dimensional embeddings. Combine vector search with structured filters using `WHERE` before the ORDER BY — the planner may not push filters inside the ANN search, so pre-filtering with a CTE or subquery can be more efficient.

## MCP and agent perspective
An agent using semantic memory queries the `vector` column with its query embedding and retrieves the K most similar past interactions. This retrieval happens transparently via SQL — the agent does not need a separate API. RLS policies on the embeddings table enforce tenant isolation for multi-tenant agents. Agents must handle the case where recall is imperfect — the nearest vectors may not be truly relevant, so retrieved context should be validated before being trusted.

## Practical implication
| Situation | Implication |
|-----------|-------------|
| `vector` column without index | Exact KNN; correct but O(n) scan — unacceptable above ~100k rows |
| ivfflat with `probes = 1` | Very fast but low recall; probe at least lists/10 |
| hnsw with large `m` (e.g., 64) | Better recall but 4× memory vs m=16 |
| Inserting into ivfflat index after build | New vectors assigned to nearest existing centroid; quality degrades over time |
| Mixed dimension embeddings in same column | pgvector requires uniform dimensions; use separate tables |
| Using L2 distance for LLM embeddings | Cosine is generally better for text embeddings; L2 is sensitive to magnitude |

## Obsidian connections
[[ai-agent-memory-ontology]] [[index-ontology]] [[extension-ontology]] [[performance-ontology]] [[schema-design-ontology]] [[security-ontology]]

## References
- pgvector: https://github.com/pgvector/pgvector
- pgvector indexing: https://github.com/pgvector/pgvector#indexing
- RAG pattern: https://www.postgresql.org/about/news/pgvector-070-released-2712/
