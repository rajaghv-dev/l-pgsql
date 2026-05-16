# Advanced pgvector Indexing and Hybrid Retrieval

Level: Advanced

## One-line intuition
pgvector's two index types — IVFFlat and HNSW — trade build time, memory, and recall differently; understanding their parameters and the pre-filter vs post-filter problem is what separates a vector search that scales from one that silently degrades.

## Why this exists
Naive vector search (`ORDER BY embedding <=> query_vec LIMIT 10`) performs an exact nearest-neighbor search — scanning all rows every time. This is O(n) and unacceptable beyond 100K rows. Approximate Nearest Neighbor (ANN) indexes (IVFFlat, HNSW) enable sub-linear search with tunable accuracy/speed trade-offs. Understanding these indexes — their internal structure, their parameters, and when they fail — is essential for production semantic search.

## First-principles explanation

### Distance metrics
pgvector supports three distance operators:
| Operator | Metric | Use when |
|---|---|---|
| `<=>` | Cosine distance | Embeddings from models like OpenAI, sentence-transformers (normalized) |
| `<->` | L2 (Euclidean) distance | Embeddings where magnitude matters; raw feature vectors |
| `<#>` | Negative inner product | Pre-normalized embeddings (equivalent to cosine, faster) |

For most LLM-produced embeddings: use `<=>` (cosine) or `<#>` (inner product if normalized). The index type must match the operator: `CREATE INDEX ... USING ivfflat (embedding vector_cosine_ops)`.

### IVFFlat — Inverted File with Flat Quantization

**Structure**: k-means clustering of all vectors into `lists` centroids. At search time:
1. Find the `probes` nearest centroids to the query vector
2. Exhaustively search all vectors in those `probes` clusters
3. Return the top-k from the searched subset

**Key parameters**:
- `lists`: number of clusters. Rule: `sqrt(n_rows)` for < 1M rows; `n_rows / 1000` for > 1M rows.
- `probes` (query-time): number of clusters to search. Higher = better recall, slower. Default 1. Production: 10-50.

```sql
-- blocked: Docker not accessible
-- Build IVFFlat index (requires existing data for clustering)
CREATE INDEX idx_embeddings_ivfflat ON documents
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- Set probes at query time (session or transaction)
SET ivfflat.probes = 20;
SELECT id, embedding <=> '[...]'::vector AS distance
FROM documents
ORDER BY embedding <=> '[...]'::vector
LIMIT 10;
```

**IVFFlat limitations**:
- Must have data before building (clusters based on existing vectors)
- After many inserts, cluster quality degrades — periodic REINDEX needed
- Build time: O(n × lists) for k-means
- Cannot be built on an empty table

### HNSW — Hierarchical Navigable Small World (pgvector 0.5+)

**Structure**: A multi-layer graph. Each vector is a node. Nodes have edges to their approximate nearest neighbors. Higher layers have fewer nodes and longer-range connections; the bottom layer contains all vectors.

**Search**: Enters at the top layer, greedily descends toward the query vector, uses the dense bottom layer for precise neighborhood search.

**Key parameters**:
- `m`: max connections per node per layer. Higher = better recall, larger index, slower build. Default 16.
- `ef_construction`: candidate list size during index build. Higher = better graph quality, slower build. Default 64.
- `ef_search` (query-time): candidate list size during search. Higher = better recall, slower query. Default 40.

```sql
-- blocked: Docker not accessible
-- HNSW index
CREATE INDEX idx_embeddings_hnsw ON documents
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- Tune at query time
SET hnsw.ef_search = 100;
SELECT id, embedding <=> '[...]'::vector AS distance
FROM documents
ORDER BY embedding <=> '[...]'::vector
LIMIT 10;
```

**HNSW advantages over IVFFlat**:
- Can be built incrementally (on empty table; inserts maintain graph structure)
- Better recall/speed trade-off at equal parameters
- No re-clustering needed after inserts (graph self-organizes)

**HNSW disadvantages**:
- Larger memory footprint: `m × 8 bytes × n_rows` for graph edges
- Slower build time
- `ef_construction` must be ≥ `m` (will error otherwise)

### IVFFlat vs HNSW comparison

| Aspect | IVFFlat | HNSW |
|---|---|---|
| Build time | Faster | Slower |
| Build memory | Lower | Higher (graph edges) |
| Query time | Tunable via probes | Tunable via ef_search |
| Recall at equal speed | Lower | Higher |
| Incremental inserts | Degrades clusters | Graph self-maintains |
| Index size | Smaller | Larger |
| Empty table build | No | Yes |

**Rule of thumb**: Use HNSW for most production deployments. Use IVFFlat when memory is constrained or build time is critical (bulk reindexing).

### The pre-filter vs post-filter problem

**Problem**: Vector search + metadata filter.
```sql
-- blocked: Docker not accessible
-- Intent: find similar documents that belong to tenant 42
SELECT id FROM documents
WHERE tenant_id = 42  -- filter
ORDER BY embedding <=> '[...]'::vector  -- vector search
LIMIT 10;
```

PostgreSQL may execute this as:
- **Sequential scan** (if tenant filter is selective enough): iterate filtered rows, compute distance for each — exact but slow for large tables
- **HNSW/IVFFlat index scan** followed by filter: search the full vector index, then apply tenant filter on results — fast but may return < LIMIT results if many results fail the filter

**The issue**: ANN indexes search the whole index, returning `k` results, then apply filters. If 90% fail the filter, you get 1 result instead of 10. This is post-filter failure.

**Solutions**:

1. **Pre-filter with index, then vector search**: Use a covering expression or partial index.
```sql
-- blocked: Docker not accessible
-- Partial index per tenant (works if tenants are enumerable)
CREATE INDEX idx_tenant42_emb ON documents
    USING hnsw (embedding vector_cosine_ops)
    WHERE tenant_id = 42;
-- Query must include WHERE tenant_id = 42 to use partial index
```

2. **Over-fetch then filter**: Request more results than needed, filter application-side.
```sql
-- blocked: Docker not accessible
-- Fetch 100, expect 10 to survive tenant filter (if ~10% match)
SELECT id FROM documents
WHERE tenant_id = 42
ORDER BY embedding <=> '[...]'::vector
LIMIT 10;
-- PostgreSQL may still use sequential scan for small tenant subsets
```

3. **Tenant-partitioned tables**: Each tenant has their own partition, so vector search is naturally scoped.

4. **Use `ef_search` aggressively**: Higher `ef_search` searches more candidates, increasing the chance of finding enough matching results — at the cost of speed.

### Quantization direction
As of pgvector 0.7.x, binary quantization and scalar quantization are being added. The direction:
- **Binary quantization**: each float32 → 1 bit (32x compression). Very fast distance with `hamming` or `jaccard`. 10-20% recall degradation. Good for first-pass retrieval with exact re-ranking.
- **Scalar quantization (int8)**: 4x compression, < 2% recall loss. Better accuracy/compression trade-off than binary.

These features reduce memory requirements for very large vector indexes.

### Hybrid retrieval (FTS + vector)
See lesson 12 for implementation details. Key point specific to pgvector:
- FTS pre-filter → vector re-rank: efficient when FTS candidate set is reasonable (< 10K)
- Vector pre-filter → FTS re-rank: less useful (vector doesn't reduce semantic mismatch on keywords)
- Parallel: both independently → RRF combine: most robust, highest recall, more compute

## Micro-concepts
- **recall@k**: fraction of true top-k nearest neighbors found by ANN search. Acceptable production threshold: > 95% at k=10.
- **dimensions**: pgvector supports up to 16,000 dimensions (as of 0.7.x). Index support up to 2,000 for IVFFlat, 2,000 for HNSW.
- **`vector_dims(embedding)`**: returns the dimension count.
- **norm**: `l2_norm(embedding)` — normalized vectors have norm=1. Use for cosine/inner product equivalence.
- **`<#>`**: negative inner product — lower = more similar (since it's negative). Use `ORDER BY embedding <#> query_vec` (NOT DESC).
- **index-only scan**: not supported for vector indexes. The heap is always accessed for result rows.
- **maintenance_work_mem**: HNSW build uses `maintenance_work_mem` for graph construction. Set higher for large indexes: `SET maintenance_work_mem = '4GB'`.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Create an HNSW index, set `ef_search = 100`, query with `<=>`.

**Intermediate view**: Choose IVFFlat for memory constraints, HNSW for recall. Tune `lists`/`probes` or `m`/`ef_construction`/`ef_search`. Watch for post-filter degradation.

**Advanced view**: Post-filter degradation is the central unsolved challenge of vector search with metadata filters. Partial indexes per tenant work for small tenant counts; for thousands of tenants, they are impractical. The correct solution depends on filter selectivity: if filter is highly selective (< 1% of rows), sequential scan over filtered rows may beat ANN index. Measure with `EXPLAIN (ANALYZE, BUFFERS)` and `SET enable_indexscan = off/on`. HNSW graph quality degrades with bulk inserts beyond the initial build — monitor recall with a benchmark query set run periodically. `maintenance_work_mem` during HNSW build directly affects graph quality: insufficient memory causes graph shortcuts, lowering recall.

## Mental model
IVFFlat is like a library divided into neighborhoods (clusters). You pick the most relevant neighborhoods (probes) and search within them. HNSW is like a city with a metro system: higher layers are express trains (skip across the city quickly), lower layers are local trains (precise local navigation). Both get you to the right neighborhood, but HNSW's navigation system stays coherent as the city grows.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_indexes` (index type), `pg_stat_user_indexes` (index scan counts). No dedicated pgvector system views.

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Check index type for vector column
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'documents' AND indexdef ILIKE '%vector%';

-- Measure actual query recall (benchmark pattern)
-- Run exact search (no index) vs ANN search and compare overlap
SET enable_indexscan = off;  -- force sequential scan for exact results
-- ... (collect exact top-10 ids)
SET enable_indexscan = on;   -- use HNSW
-- ... (collect ANN top-10 ids)
-- Compute intersection size / 10 = recall@10
```

**Non-SQL / hybrid view**: pgvector GitHub: https://github.com/pgvector/pgvector. ANN benchmark comparisons: http://ann-benchmarks.com/. Weaviate, Pinecone, and Qdrant are dedicated vector databases for comparison benchmarking.

## Design principle
**ANN indexes trade accuracy for speed — measure the trade-off for your workload**: Don't assume `ef_search = 40` gives acceptable recall for your queries. Build a benchmark query set (representative queries with known ground truth), measure recall@k for your ANN configuration, and tune until recall > 95%. Re-run the benchmark after major data changes.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: pgvector is still young. The HNSW implementation was added in 0.5.0 (2023). It is production-quality for most workloads, but lacks some advanced features (binary quantization in production, concurrent HNSW graph construction) that are available in dedicated vector databases. For mission-critical retrieval at very large scale (> 10M vectors), benchmark pgvector against Qdrant or Weaviate before committing.

**Creative**: Use pgvector for staging/prototyping even if you plan to move to a dedicated vector database in production. The SQL interface lets you develop hybrid retrieval logic with JOINs and CTEs that would require multiple API calls in a dedicated system. Once the retrieval pipeline is validated, export embeddings to a dedicated system if needed.

**Systems**: Vector index build with HNSW is compute and memory intensive. For large tables (1M+ rows), build indexes during maintenance windows with elevated `maintenance_work_mem` and `max_parallel_maintenance_workers`. Consider building on a replica first, then promoting or copying the index. Monitor `pg_stat_progress_create_index` during build.

## MCP and agent perspective
AI agents using PostgreSQL as semantic memory need vector search that is fast (< 50ms for memory recall) and accurate (> 95% recall to avoid missing relevant memories). HNSW with `ef_search = 100` typically achieves this for < 1M documents. For multi-agent environments, each agent's memory partition should either use a partial index (if few agents) or a separate table (if many agents) to avoid cross-agent contamination in vector search results. The hybrid retrieval pattern (FTS + vector) is particularly valuable for agent memory because agents often remember both semantic concepts and specific terms (variable names, IDs, command strings).

## Ontology perspective
Vector indexes are approximations of the metric space defined by the embedding model. They represent a commitment to one model's theory of semantic similarity. HNSW's navigable small world graph mirrors how human associative memory works — closely related concepts are many connected paths apart, while distant concepts require traversing higher-level abstractions. The choice of distance metric (cosine vs L2) is an ontological stance on what "similarity" means: cosine measures directional alignment (useful for normalized, high-dimensional representations); L2 measures absolute geometric distance (useful when magnitude encodes information).

## Practice session

**Exercise 1 — Create HNSW index**: Build on an existing embeddings table.
```sql
-- blocked: Docker not accessible
CREATE INDEX idx_doc_hnsw ON documents
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);
```

**Exercise 2 — Compare exact vs ANN**: Measure recall difference.
```sql
-- blocked: Docker not accessible
-- Exact (sequential scan)
SET enable_indexscan = off;
SELECT id FROM documents ORDER BY embedding <=> '[0.1,0.2,...]'::vector LIMIT 10;
-- ANN (HNSW)
SET enable_indexscan = on;
SET hnsw.ef_search = 100;
SELECT id FROM documents ORDER BY embedding <=> '[0.1,0.2,...]'::vector LIMIT 10;
```

**Exercise 3 — Pre-filter with partial index**: Scoped vector search.
```sql
-- blocked: Docker not accessible
CREATE INDEX idx_active_docs_hnsw ON documents
    USING hnsw (embedding vector_cosine_ops)
    WHERE status = 'active';

SET hnsw.ef_search = 80;
SELECT id, title FROM documents
WHERE status = 'active'
ORDER BY embedding <=> '[...]'::vector
LIMIT 10;
```

**Exercise 4 — IVFFlat with probes**: Tune recall/speed.
```sql
-- blocked: Docker not accessible
CREATE INDEX idx_doc_ivfflat ON documents
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 50);

SET ivfflat.probes = 5;    -- fast, lower recall
SELECT id FROM documents ORDER BY embedding <=> '[...]'::vector LIMIT 10;

SET ivfflat.probes = 20;   -- slower, higher recall
SELECT id FROM documents ORDER BY embedding <=> '[...]'::vector LIMIT 10;
```

**Exercise 5 — Distance metric choice**: Compare cosine vs L2.
```sql
-- blocked: Docker not accessible
-- Cosine distance (normalized embeddings)
SELECT id, embedding <=> '[...]'::vector AS cosine_dist FROM documents ORDER BY 2 LIMIT 5;
-- L2 distance
SELECT id, embedding <-> '[...]'::vector AS l2_dist FROM documents ORDER BY 2 LIMIT 5;
```

## References
- pgvector GitHub: https://github.com/pgvector/pgvector
- pgvector Documentation: https://github.com/pgvector/pgvector#readme
- HNSW Paper: Malkov & Yashunin (2018) — "Efficient and Robust Approximate Nearest Neighbor Search Using Hierarchical Navigable Small World Graphs"
- ANN Benchmarks: http://ann-benchmarks.com/
- Jonathan Katz: [pgvector 0.5.0 — HNSW](https://jkatz05.com/post/postgres/pgvector-hnsw-performance/)
- PostgreSQL Documentation: [CREATE INDEX](https://www.postgresql.org/docs/16/sql-createindex.html)
