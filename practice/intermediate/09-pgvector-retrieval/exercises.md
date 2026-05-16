# Exercises — pgvector Retrieval

**Status: blocked — Docker not accessible in this session**
All SQL is correct and ready to run when Docker is available.

---

## Exercise 1: KNN search — cosine distance

Find the 3 documents most semantically similar to a technical query vector.

```sql
-- blocked: Docker not accessible

-- Query vector near the technical cluster
SELECT id, content, category,
       embedding <=> '[0.12, 0.80, 0.35]'::vector AS cosine_dist
FROM documents
ORDER BY embedding <=> '[0.12, 0.80, 0.35]'::vector
LIMIT 3;

-- Expected: top 3 are all 'technical' documents (low cosine distance)
-- Food documents should have distance near 1.0 (opposite direction)
```

## Exercise 2: KNN search — L2 (Euclidean) distance

```sql
-- blocked: Docker not accessible

SELECT id, content, category,
       embedding <-> '[0.12, 0.80, 0.35]'::vector AS l2_dist
FROM documents
ORDER BY embedding <-> '[0.12, 0.80, 0.35]'::vector
LIMIT 3;

-- Compare: does L2 return the same top-3 as cosine?
-- For normalized vectors, ranking is usually the same.
```

## Exercise 3: Hybrid search — filter by category, rank by similarity

```sql
-- blocked: Docker not accessible

-- Only search within 'technical' documents
SELECT id, content,
       embedding <=> '[0.12, 0.80, 0.35]'::vector AS dist
FROM documents
WHERE category = 'technical'
ORDER BY embedding <=> '[0.12, 0.80, 0.35]'::vector
LIMIT 5;

-- Verify: all returned documents should be in the 'technical' category
```

## Exercise 4: Confirm index usage

```sql
-- blocked: Docker not accessible

EXPLAIN SELECT id, content
FROM documents
ORDER BY embedding <=> '[0.12, 0.80, 0.35]'::vector
LIMIT 5;

-- With HNSW index: should show "Index Scan using documents_embedding_idx"
-- Without index (small table): may show "Seq Scan" with Sort

-- Set ef_search for higher recall
SET hnsw.ef_search = 100;
```

## Exercise 5: Distance operator comparison

```sql
-- blocked: Docker not accessible

-- Compare all three distance operators on the same query
SELECT
    content,
    embedding <->  '[0.12, 0.80, 0.35]'::vector AS l2_dist,
    embedding <=>  '[0.12, 0.80, 0.35]'::vector AS cosine_dist,
    (embedding <#> '[0.12, 0.80, 0.35]'::vector) * -1 AS inner_product
FROM documents
ORDER BY cosine_dist
LIMIT 5;

-- Observe: the ordering should be similar for all three on normalized vectors
-- Inner product is negative (operator returns negative; negate for ranking)
```

## Exercise 6: Find nearest neighbor to an existing document

```sql
-- blocked: Docker not accessible

-- Find the 3 documents most similar to document id=1
SELECT d2.id, d2.content, d2.category,
       d1.embedding <=> d2.embedding AS dist
FROM documents d1
CROSS JOIN LATERAL (
    SELECT id, content, category, embedding
    FROM documents
    WHERE id != d1.id
    ORDER BY embedding <=> d1.embedding
    LIMIT 3
) d2
WHERE d1.id = 1;
```

## Exercise 7: IVFFlat vs HNSW comparison

```sql
-- blocked: Docker not accessible

-- Drop HNSW, create IVFFlat, compare recall
DROP INDEX IF EXISTS documents_embedding_idx;

-- IVFFlat requires data to be present at build time
CREATE INDEX ON documents USING ivfflat(embedding vector_cosine_ops) WITH (lists = 5);

-- Tune probes for recall
SET ivfflat.probes = 3;  -- search 3 of the 5 clusters

EXPLAIN SELECT id FROM documents
ORDER BY embedding <=> '[0.12, 0.80, 0.35]'::vector
LIMIT 3;
```

## Reflection questions
1. When would cosine distance give meaningfully different rankings than L2?
2. Why must the HNSW or IVFFlat index be built AFTER data is inserted?
3. What is the effect of increasing `hnsw.ef_search` on query latency and recall?
4. In a production RAG pipeline, where would you store the embedding model name alongside the vectors?
