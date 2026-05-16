# hstore (hstore)

Level: Intermediate
Available locally: Yes

## One-line purpose

Store a flat set of key-value string pairs in a single column, with operators for key existence, value retrieval, merging, and deletion — all indexable with GIN or GiST.

## Why this exists

Before JSONB, hstore was the standard way to store schemaless key-value metadata in PostgreSQL. It remains useful when:

1. Values are always strings (no nested objects, no arrays, no numbers/booleans)
2. You need simpler, faster operations than JSONB for flat metadata
3. You are maintaining legacy code that predates JSONB (introduced in PG 9.4)

hstore is a single-level flat map: keys and values are both text. It cannot represent nesting.

## Install

```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS hstore;
SELECT extname, extversion FROM pg_extension WHERE extname = 'hstore';
```

## Core operations

### Define and insert hstore data

```sql
-- blocked: Docker not accessible
CREATE TABLE products (
    id       SERIAL PRIMARY KEY,
    name     TEXT,
    attrs    hstore   -- key-value metadata
);

-- Literal syntax: 'key=>value, key=>value'
INSERT INTO products (name, attrs) VALUES
    ('Laptop',  'color=>silver, weight_kg=>1.4, warranty_years=>2'),
    ('Monitor', 'color=>black, resolution=>4K, hz=>144');
```

### Read values

```sql
-- blocked: Docker not accessible
-- Get a single value by key
SELECT attrs -> 'color' FROM products;          -- returns TEXT or NULL

-- Get multiple keys as a record
SELECT attrs -> ARRAY['color', 'weight_kg'] FROM products;  -- returns TEXT[]

-- Check key existence
SELECT * FROM products WHERE attrs ? 'color';           -- has key 'color'
SELECT * FROM products WHERE attrs ?& ARRAY['color','hz'];  -- has ALL keys
SELECT * FROM products WHERE attrs ?| ARRAY['color','hz'];  -- has ANY key
```

### Modify hstore values

```sql
-- blocked: Docker not accessible
-- Add or update a key (returns new hstore — hstore is immutable, update the column)
UPDATE products
SET attrs = attrs || hstore('color', 'white')
WHERE name = 'Laptop';

-- Remove a key
UPDATE products
SET attrs = delete(attrs, 'warranty_years')
WHERE name = 'Laptop';

-- Remove multiple keys
UPDATE products
SET attrs = delete(attrs, ARRAY['color', 'hz']);
```

### Merge (concatenate) two hstores

```sql
-- blocked: Docker not accessible
-- || merges; right side wins on key conflicts
SELECT 'a=>1, b=>2'::hstore || 'b=>99, c=>3'::hstore;
-- Result: "a"=>"1","b"=>"99","c"=>"3"
```

### Convert hstore to/from other types

```sql
-- blocked: Docker not accessible
-- To JSON
SELECT hstore_to_json(attrs) FROM products;
SELECT hstore_to_jsonb(attrs) FROM products;   -- returns jsonb

-- From two arrays (keys, values)
SELECT hstore(ARRAY['k1','k2'], ARRAY['v1','v2']);

-- From a record (row)
SELECT hstore(ROW(1, 'hello'));

-- List all keys
SELECT akeys(attrs) FROM products;   -- TEXT[]
SELECT skeys(attrs) FROM products;   -- setof TEXT

-- List all values
SELECT avals(attrs) FROM products;   -- TEXT[]
SELECT svals(attrs) FROM products;   -- setof TEXT

-- Expand to rows of (key, value)
SELECT (each(attrs)).* FROM products;
```

### Filter by value

```sql
-- blocked: Docker not accessible
-- Find products with color = 'black'
SELECT * FROM products WHERE attrs @> 'color=>black';

-- @> containment: left hstore contains all pairs in right hstore
SELECT * FROM products WHERE attrs @> 'color=>black, hz=>144';
```

## Index types

### GIN with `gin__int_ops` / default

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_products_attrs_gin ON products USING GIN (attrs);
```

- Supports: `?`, `?&`, `?|`, `@>` operators
- Best for: key existence and containment queries
- Recommended for most hstore workloads

### GiST with `gist__int_ops`

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_products_attrs_gist ON products USING GiST (attrs);
```

- Supports same operators as GIN
- Smaller index, faster updates, but slower queries than GIN
- Better for write-heavy columns with occasional lookups

## Performance characteristics

- hstore stores keys and values as a binary encoding — more compact than equivalent JSONB for flat maps
- GIN index lookup for `?` and `@>` is O(log n)
- `->` value retrieval from an hstore column is O(number of keys) — fast for small key sets
- For very large numbers of keys per row (> 100), JSONB GIN indexing may be more efficient
- No type information in values — all comparisons are string comparisons even for numbers

## When to use (hstore vs JSONB)

| Feature | hstore | JSONB |
|---------|--------|-------|
| Flat string key-value | Yes | Yes |
| Nested objects | No | Yes |
| Typed values (int, bool, null) | No | Yes |
| Arrays | No | Yes |
| Index support | GIN / GiST | GIN / partial |
| Performance (flat maps) | Slightly faster | Comparable |
| Legacy compatibility | Wide (pg 8.2+) | PG 9.4+ |
| Ecosystem tooling | Limited | Broad |

**Rule of thumb**: use JSONB for new code unless you have a specific reason to use hstore (existing schema, performance micro-optimization for flat string maps, or code that already uses hstore operators).

## When NOT to use

- When values are not strings (numbers, booleans, null, arrays, nested objects) — use JSONB
- When the key set is known at schema design time — use proper columns instead
- When you need to query deeply nested structures
- New code with no legacy constraints — prefer JSONB for better ecosystem support and tooling

## Alternatives

| Alternative | When to prefer |
|-------------|---------------|
| JSONB | Typed values, nesting, arrays, broader tooling |
| JSON | Human-readable storage, rarely queried |
| EAV table | When values need FK constraints or type diversity |
| Proper columns | When key set is known and stable |

## MCP and agent perspective

- **Simple metadata tags on rows**: agents writing labels, flags, or short string metadata to rows (e.g., `tags=>ai-generated, source=>api-v2, reviewed=>false`) can use hstore to avoid schema migrations for new metadata fields
- **Containment filter**: `WHERE attrs @> hstore('reviewed', 'false')` efficiently finds unreviewed rows via GIN index — useful for agent task queues
- **Safe updates**: use `attrs || hstore($key, $value)` for non-destructive key updates; never reconstruct the whole hstore in the application — it discards keys the agent doesn't know about
- Agents must validate that key and value strings do not contain `=>` or `,` without quoting, or construct hstore using the `hstore(key, value)` function form to avoid parse errors

## Ontology connection

- Lives under `extensions/data-types/` alongside `ltree` — both are specialized column types
- Connects to: JSONB (the modern successor), `ltree` (tree paths as keys), GIN indexes (shared index mechanism)
- Concept map: hstore → flat key-value store → GIN containment index → schemaless metadata pattern

## References

- [PostgreSQL hstore docs](https://www.postgresql.org/docs/16/hstore.html)
- [hstore operator reference](https://www.postgresql.org/docs/16/hstore.html#HSTORE-OPS-FUNCS)
- [hstore vs JSONB comparison](https://www.postgresql.org/docs/16/datatype-json.html)
