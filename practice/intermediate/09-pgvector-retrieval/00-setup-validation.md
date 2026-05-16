# Setup Validation — Practice 09

**Status: blocked — Docker not accessible in this session**

## vector extension availability
The `vector` extension IS available in cfp_postgres (listed in extension-map.md). It requires Docker access to run.

```sql
-- blocked: Docker not accessible

-- 1. Extension installed
SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';

-- 2. Table and row counts
SELECT 'documents' AS tbl, COUNT(*) FROM documents;
-- Expected: 10

-- 3. Category distribution
SELECT category, COUNT(*) FROM documents GROUP BY category;
-- Expected: technical=6, food=4

-- 4. Embedding column populated
SELECT id, embedding::text FROM documents LIMIT 3;
-- Should show 3-dimensional vectors

-- 5. HNSW index exists
SELECT indexname, indexdef FROM pg_indexes
WHERE tablename = 'documents'
  AND indexdef ILIKE '%hnsw%';
-- Expected: 1 row

-- 6. Simple KNN sanity check
SELECT id, content,
       embedding <=> '[0.1, 0.8, 0.3]'::vector AS dist
FROM documents
ORDER BY embedding <=> '[0.1, 0.8, 0.3]'::vector
LIMIT 3;
-- Expected: top 3 are all 'technical' documents
```

## When Docker is available
```bash
docker exec cfp_postgres psql -U cfp -d cfp -f \
  practice/intermediate/09-pgvector-retrieval/setup.sql
docker exec cfp_postgres psql -U cfp -d cfp -c \
  "SELECT id, category FROM documents ORDER BY id;"
```
