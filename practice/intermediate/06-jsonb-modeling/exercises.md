# Exercises — JSONB Modeling

**Status: blocked — Docker not accessible in this session**

## Exercise 1: Basic JSONB operators

```sql
-- blocked: Docker not accessible

-- Field access
SELECT name,
    attributes -> 'brand'    AS brand_json,   -- returns JSON
    attributes ->> 'brand'   AS brand_text,   -- returns text
    attributes -> 'ram_gb'   AS ram_json
FROM products WHERE category_id = 1;

-- Nested path
SELECT name, attributes #>> '{brand}' AS brand
FROM products;

-- Key existence
SELECT name FROM products WHERE attributes ? 'waterproof';

-- Containment: all blue products
SELECT name, attributes ->> 'color' AS color
FROM products
WHERE attributes @> '{"color":"blue"}';

-- Multiple containment conditions
SELECT name FROM products
WHERE attributes @> '{"brand":"Nexus","color":"silver"}';
```

## Exercise 2: GIN index — confirm usage

```sql
-- blocked: Docker not accessible

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM products WHERE attributes @> '{"color":"black"}';
-- Should show: Bitmap Index Scan on the GIN index
-- NOT: Seq Scan
```

## Exercise 3: JSONB update operations

```sql
-- blocked: Docker not accessible

-- Add a new key to an existing product
UPDATE products
SET attributes = attributes || '{"on_sale": true}'
WHERE name = 'Laptop X1';

-- Update a specific nested key
UPDATE products
SET attributes = jsonb_set(attributes, '{ram_gb}', '32')
WHERE name = 'Laptop X1';

-- Remove a key
UPDATE products
SET attributes = attributes - 'has_stylus'
WHERE name = 'Tablet Pro';

-- Verify
SELECT name, attributes FROM products WHERE name IN ('Laptop X1', 'Tablet Pro');
```

## Exercise 4: Expand JSONB to rows

```sql
-- blocked: Docker not accessible

-- See all attribute keys present in electronics
SELECT DISTINCT kv.key
FROM products p, jsonb_each(p.attributes) AS kv
WHERE p.category_id = 1
ORDER BY kv.key;

-- Count how many products have each attribute key
SELECT kv.key, COUNT(*) AS product_count
FROM products p, jsonb_each(p.attributes) AS kv
GROUP BY kv.key
ORDER BY product_count DESC;
```

## Exercise 5: Generated column for a promoted field

```sql
-- blocked: Docker not accessible

-- Promote 'brand' from JSONB to a generated column for efficient querying
ALTER TABLE products
ADD COLUMN brand TEXT GENERATED ALWAYS AS (attributes ->> 'brand') STORED;

CREATE INDEX ON products (brand);

-- Now brand-based queries use an index, not GIN
EXPLAIN SELECT * FROM products WHERE brand = 'Nexus';
```

## Exercise 6: JSONB aggregation

```sql
-- blocked: Docker not accessible

-- Build a JSON summary of all vegan products
SELECT jsonb_agg(jsonb_build_object('id', id, 'name', name, 'price', price))
FROM products
WHERE attributes @> '{"vegan":true}';

-- Group by brand, aggregate product names as JSON array
SELECT attributes ->> 'brand' AS brand,
       jsonb_agg(name ORDER BY name) AS products
FROM products
WHERE attributes ? 'brand'
GROUP BY brand
ORDER BY brand;
```

## Reflection questions
1. When should a frequently-queried JSONB key be promoted to a real column?
2. What is the difference between `-> 'key'` and `->> 'key'`? When does the type matter?
3. Why does GIN index the entire JSONB document (all keys + values)? What are the size implications?
4. What constraint could you add to ensure every product in category 'electronics' has a 'brand' key?
