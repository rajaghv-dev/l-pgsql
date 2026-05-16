# Setup Validation — Practice 06

**Status: blocked — Docker not accessible in this session**

```sql
-- blocked: Docker not accessible

-- 1. Row counts
SELECT 'products' AS tbl, COUNT(*) FROM products
UNION ALL
SELECT 'categories', COUNT(*) FROM categories;
-- Expected: products=8, categories=4

-- 2. GIN index exists
SELECT indexname FROM pg_indexes WHERE tablename = 'products' AND indexdef ILIKE '%gin%';
-- Expected: 1 row

-- 3. JSONB structure sampling
SELECT name, attributes FROM products LIMIT 3;

-- 4. Containment query sanity check
SELECT COUNT(*) FROM products WHERE attributes @> '{"vegan":true}';
-- Expected: 2
```
