# Troubleshooting — pgvector Retrieval

## Docker not accessible
**Status:** All SQL blocked in this session.
**Resolution:** Enable Docker Desktop WSL2 integration or run:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -f setup.sql
```

## ERROR: type "vector" does not exist
**Cause:** pgvector extension not installed.
**Fix:**
```sql
CREATE EXTENSION IF NOT EXISTS vector;
-- Verify:
SELECT extname FROM pg_extension WHERE extname = 'vector';
```
In cfp_postgres, the `vector` extension IS available (listed in extension-map.md).

## ERROR: expected N dimensions, not M
**Cause:** Inserting a vector with wrong dimensionality.
**Fix:** Ensure all vectors inserted match the column's declared dimension:
```sql
-- Column declared as vector(3), insert must be 3-dimensional:
INSERT INTO documents (embedding) VALUES ('[0.1, 0.2, 0.3]'::vector);  -- OK
INSERT INTO documents (embedding) VALUES ('[0.1, 0.2]'::vector);        -- ERROR
```

## Index not used for KNN query
**Cause:** Table is too small (optimizer prefers seq scan) or index was built before data was inserted (IVFFlat only).
**Diagnosis:**
```sql
EXPLAIN SELECT * FROM documents ORDER BY embedding <=> '[0.1,0.8,0.3]'::vector LIMIT 5;
```
**Fix for small table:** This is correct behavior. The index becomes valuable at ~1000+ rows.
**Fix for IVFFlat stale centers:** Rebuild the index after bulk insert.

## Cosine distance returns unexpected values
**Cause:** Zero vector `[0, 0, 0]` has no direction — cosine distance is undefined.
**Fix:** Validate embeddings before inserting:
```sql
SELECT id FROM documents WHERE embedding = '[0,0,0]'::vector;
-- Remove or re-embed these rows
```

## Poor recall from ANN index
**Cause:** `hnsw.ef_search` or `ivfflat.probes` too low.
**Fix:**
```sql
-- Temporarily increase recall at cost of speed
SET hnsw.ef_search = 200;
SET ivfflat.probes = 10;  -- if using ivfflat
```
For production, set in `postgresql.conf` or per-session based on use case.

## Slow hybrid search (vector + WHERE filter)
**Cause:** The ANN index returns candidates in vector order, but the WHERE filter discards most of them. The optimizer may fall back to a sequential scan.
**Fix:** Ensure the filtered column (e.g., `category`) has a B-tree index. pgvector also supports partial indexes:
```sql
CREATE INDEX ON documents USING hnsw(embedding vector_cosine_ops)
WHERE category = 'technical';
```
This index only covers technical documents — faster hybrid queries for that category.

## Embeddings from different models mixed in one table
**Symptom:** KNN results are nonsensical — unrelated documents appear as "similar".
**Cause:** Embedding spaces from different models are incompatible; distances between them are meaningless.
**Fix:** Always store the model identifier. Filter by model before KNN:
```sql
-- Assuming you've added embedding_model column:
WHERE embedding_model = 'nomic-embed-text-v1.5'
ORDER BY embedding <=> query_vec LIMIT 5;
```
