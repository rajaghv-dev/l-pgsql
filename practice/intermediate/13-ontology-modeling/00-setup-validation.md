# Setup Validation — Practice 13

**Status: blocked — Docker not accessible in this session**

```sql
-- blocked: Docker not accessible

-- 1. Extensions
SELECT extname FROM pg_extension WHERE extname IN ('ltree','vector','pg_trgm');
-- Expected: 3 rows

-- 2. Tables
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('topics','conferences','speakers','talks','submissions','presentation_roles')
ORDER BY table_name;

-- 3. ltree hierarchy
SELECT name, path FROM topics ORDER BY path;
-- Expected: 7 topics in hierarchy

-- 4. search_vector populated
SELECT title, LEFT(search_vector::text, 60) FROM talks;

-- 5. FK relationship graph
SELECT
    tc.table_name AS child,
    ccu.table_name AS parent
FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu
    USING (constraint_name, table_schema)
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY child;
```
