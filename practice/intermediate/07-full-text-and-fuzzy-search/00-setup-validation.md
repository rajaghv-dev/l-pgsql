# Setup Validation — Practice 07

**Status: blocked — Docker not accessible in this session**

```sql
-- blocked: Docker not accessible

-- 1. Extensions
SELECT extname FROM pg_extension WHERE extname IN ('pg_trgm');

-- 2. Row counts
SELECT COUNT(*) FROM articles;  -- Expected: 8

-- 3. search_vector populated
SELECT id, LEFT(search_vector::text, 80) FROM articles LIMIT 3;
-- Should show lexemes

-- 4. GIN indexes exist
SELECT indexname, indexdef FROM pg_indexes
WHERE tablename = 'articles'
ORDER BY indexname;
-- Expected: index on search_vector (gin) and title (gin_trgm_ops)

-- 5. FTS sanity
SELECT title FROM articles
WHERE search_vector @@ to_tsquery('english', 'postgres');
-- Expected: multiple articles
```
