# Solutions — pgvector Retrieval

**Status: blocked — Docker not accessible in this session**

## Exercise 1 solution
Expected output (approximate):
```
id | content                                          | category  | cosine_dist
---|--------------------------------------------------|-----------|------------
1  | PostgreSQL is a powerful relational database     | technical | 0.003
4  | MVCC allows concurrent reads and writes         | technical | 0.008
2  | SQL joins merge data from multiple tables       | technical | 0.012
```
Food documents will have cosine_dist near 0.85–0.99 (near-orthogonal vectors).

## Exercise 2 solution
For normalized vectors (all dimensions sum to ~1), L2 and cosine rankings are correlated. The ordering may differ slightly because:
- L2 considers the magnitude difference between vectors
- Cosine only considers the angle (direction)

For text embeddings from transformer models, cosine is preferred because the model encodes meaning in direction, not magnitude.

## Exercise 3 solution
The `WHERE category = 'technical'` filter reduces the candidate set before the ANN index can operate. With small tables, PostgreSQL does: filter rows → then sort by distance. With larger tables and proper indexes, the optimizer may use the ANN index first and filter post-scan. For best hybrid performance, see the pgvector documentation on partial indexes.

## Exercise 4 solution
On a 10-row table, PostgreSQL almost certainly uses a Seq Scan (optimizer determines index is not worth it for tiny tables). On tables with 1000+ rows, the HNSW index scan becomes evident in EXPLAIN.

`hnsw.ef_search = 100` (vs default 40) increases the number of graph nodes explored during search — more recall, more latency. The relationship is roughly linear: 2x ef_search ≈ 2x latency, with diminishing recall gains.

## Exercise 5 solution
Operators summary:
- `<->` L2 distance: `sqrt(sum((a_i - b_i)^2))` — always non-negative
- `<=>` cosine distance: `1 - dot(a,b)/(|a||b|)` — 0=identical direction, 2=opposite direction
- `<#>` negative inner product: `-dot(a,b)` — negative; negate for ranking (higher is better)

For unit-normalized vectors: cosine_dist = L2_dist^2 / 2, so ranking is identical. The operators differ on un-normalized vectors.

## Exercise 6 solution
`CROSS JOIN LATERAL` allows a correlated subquery to reference the outer table. The inner query uses the HNSW index to find the top-3 nearest documents to d1's embedding. This is the "find similar items" pattern — useful for "related articles", "similar products", "recommended next".

## Exercise 7 solution
IVFFlat divides the embedding space into `lists` Voronoi cells. A query searches the nearest `probes` cells. With `lists=5, probes=3`, the query searches 3/5 of the space — 60% recall (approximate). Increase `probes` to approach 100% recall at the cost of speed. The common rule of thumb: `probes = sqrt(lists)`.

IVFFlat must be built after data is inserted (it needs cluster centers from the actual data). HNSW can accept inserts after build (it updates the graph incrementally), making it better for append-heavy workloads.

## Reflection answers
1. Cosine and L2 diverge when vectors have different magnitudes. If one embedding model produces vectors of varying length (un-normalized), L2 penalizes larger-magnitude vectors even if their direction is correct. Cosine is invariant to magnitude — it only compares direction.
2. IVFFlat clusters the embedding space using k-means. Without data, there are no cluster centers to compute. HNSW builds a graph connecting nearby vectors — it can update on insert but build quality is better when more data is present.
3. Increasing `ef_search`: +latency, +recall. The HNSW graph has a configurable search depth — larger ef_search explores more paths before returning LIMIT results, missing fewer true neighbors at the cost of more computation.
4. Store the model name in a separate column (`embedding_model TEXT`) or in a separate table (`embedding_models`). When you change the model, you must re-embed all documents. Having the model name stored allows detecting stale embeddings:
```sql
SELECT COUNT(*) FROM documents WHERE embedding_model != 'nomic-embed-text-v1.5';
```
