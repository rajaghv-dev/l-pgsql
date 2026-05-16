# JSONB Modeling Tradeoffs
Level: Intermediate

## One-line intuition
JSONB lets you store variable-structure data inside PostgreSQL with full indexing support — use it when schema flexibility outweighs the cost of losing strict column types.

## Why this exists
Real-world data is messy. Product catalogs with varying attributes per category, EAV (Entity-Attribute-Value) tables, API payloads with evolving schemas — all are painful to model in purely relational columns. JSONB gives a middle path: structured storage, queryable and indexable, within a relational table.

## First-principles explanation
PostgreSQL stores JSONB as a binary decomposed representation (not raw text), which allows:
- Efficient key lookup without parsing the full document
- GIN indexes on all keys and values simultaneously
- Operators for containment, path access, and structural modification

Key differences from JSON: JSONB removes duplicate keys (last value wins), normalizes whitespace, and stores numbers in a binary numeric format. JSON is stored as text, parsed on every read.

**Core operators:**

| Operator | Meaning | Example |
|---|---|---|
| `->` | Get JSON field as JSON | `data -> 'name'` |
| `->>` | Get JSON field as text | `data ->> 'name'` |
| `#>` | Get by path as JSON | `data #> '{addr,city}'` |
| `#>>` | Get by path as text | `data #>> '{addr,city}'` |
| `@>` | Contains | `data @> '{"color":"red"}'` |
| `<@` | Is contained by | `'{"a":1}' <@ data` |
| `?` | Key exists | `data ? 'color'` |
| `?|` | Any key exists | `data ?| array['a','b']` |
| `?&` | All keys exist | `data ?& array['a','b']` |

**Modification:**

| Function | Purpose |
|---|---|
| `jsonb_set(target, path, value)` | Replace value at path |
| `jsonb_insert(target, path, value)` | Insert value at path |
| `target || patch` | Merge two JSONB objects |
| `target - 'key'` | Remove key |

## Micro-concepts
- **GIN index** — default JSONB index; indexes every key and value; supports `@>`, `?`, `?|`, `?&`
- **jsonb_path_ops** — alternative GIN opclass; smaller index, only supports `@>`
- **jsonb_each()** / `jsonb_each_text()` — expand a JSONB object into rows of (key, value)
- **jsonb_agg()** — aggregate rows into a JSONB array
- **jsonb_build_object()** — construct JSONB from key-value pairs
- **jsonb_strip_nulls()** — remove null-valued keys
- **JSONB path language** — `jsonb_path_query()` with SQL/JSON path expressions (PostgreSQL 12+)

## Beginner view
Think of JSONB as a filing cabinet drawer for one row: you can put whatever papers you want in it, and PostgreSQL will let you search for specific papers by name. Regular columns are labeled folders with exactly one paper each.

## Intermediate view
JSONB wins when: (a) attributes vary significantly by row, (b) the set of attributes is not known at schema design time, (c) you are storing third-party API responses. It loses when: (a) you need per-column foreign keys or constraints, (b) you need efficient range queries on specific fields (use generated columns + index), (c) the attribute set is fixed and known.

## Advanced view
For high-cardinality key lookups, use a GIN index with `jsonb_path_ops` to reduce index size. For queries that filter on a specific JSONB key frequently, use a generated column: `ALTER TABLE products ADD COLUMN color TEXT GENERATED ALWAYS AS (attributes ->> 'color') STORED;` and index the generated column. This gives relational-style index efficiency for specific JSONB fields.

## Mental model
JSONB is a "flex column" — one column that acts like many. When the number and names of virtual columns are unpredictable, JSONB is the escape hatch. When they become predictable and frequently queried, migrate them out into real columns.

## PostgreSQL view
```sql
-- Table with JSONB attributes
CREATE TABLE products (
    id         SERIAL PRIMARY KEY,
    name       TEXT NOT NULL,
    category   TEXT NOT NULL,
    price      NUMERIC(10, 2),
    attributes JSONB
);

-- GIN index for containment and key queries
CREATE INDEX ON products USING gin(attributes);

-- Insert with varied attributes per category
INSERT INTO products VALUES
  (1, 'Laptop X1', 'electronics', 999.00,
   '{"brand":"Nexus","ram_gb":16,"storage_gb":512,"color":"silver"}'),
  (2, 'Running Shoe', 'footwear', 79.99,
   '{"brand":"StridePro","size":10,"color":"blue","waterproof":true}');

-- Query by JSONB containment (uses GIN index)
SELECT name, attributes ->> 'brand' AS brand
FROM products
WHERE attributes @> '{"color":"blue"}';

-- Update a specific key
UPDATE products
SET attributes = jsonb_set(attributes, '{ram_gb}', '32')
WHERE id = 1;

-- Expand attributes to rows
SELECT id, kv.key, kv.value
FROM products, jsonb_each_text(attributes) AS kv
WHERE category = 'electronics';
```

## SQL view
JSONB is PostgreSQL-specific. MySQL has JSON type with similar operators. SQL Server has JSON functions (OPENJSON). The SQL/JSON standard (ISO/IEC 9075-2:2016) defines some path operators, and PostgreSQL 16 supports the `IS JSON` predicate and SQL/JSON path language.

## Non-SQL or hybrid view
MongoDB documents are roughly equivalent to JSONB rows. The key difference: in PostgreSQL, JSONB coexists with typed columns and relational joins; in MongoDB, the entire document is the unit. Hybrid approaches are common: relational columns for identifiers and foreign keys, JSONB for variable payload. This avoids EAV hell while retaining relational integrity.

## Design principle
**JSONB is not a replacement for schema design — it is a bounded escape hatch.** Use it for genuinely variable data. Set a team convention: if a JSONB key is queried in more than X% of queries or becomes required in all rows, promote it to a real column. Regularly review your JSONB attributes for column promotion candidates using `jsonb_each()` aggregation.

## Critical thinking
- JSONB data has no column-level constraints. A `price` inside JSONB can be a string in one row and a number in another. Use CHECK constraints or application-layer validation to enforce type consistency.
- GIN indexes on JSONB are large. A table with 100 JSONB keys indexed via GIN can have an index several times larger than the table. Monitor with `pg_indexes_size()`.
- Aggregating over JSONB fields requires `CAST` or `(attributes ->> 'price')::numeric`. Type inference is absent.

## Creative thinking
Use JSONB to store audit delta diffs: `{"before": {"status":"pending"}, "after": {"status":"done"}}`. This avoids having to snapshot entire rows in an audit log — only the changed keys are stored. Combined with `jsonb_set` and `jsonb_strip_nulls`, diffs can be extremely compact.

## Systems thinking
JSONB creates a schema-in-schema problem: the formal schema is in `pg_attribute`; the informal schema is in the JSONB documents. Keep both in sync by maintaining a data dictionary (e.g., a `jsonb_field_registry` table with `table_name`, `field_path`, `type`, `description`). This registry becomes the ontology layer for JSONB fields.

## MCP and agent perspective
An MCP agent querying a JSONB-heavy schema should use `jsonb_path_query()` for complex path navigation. When constructing dynamic queries over JSONB keys, use parameterized path arrays to avoid SQL injection: `WHERE attributes @> jsonb_build_object($1::text, $2::text)`. An agent building analytical pipelines should check GIN index existence before running containment queries on large tables.

## Ontology perspective
JSONB relaxes the closed-world assumption of relational tables: a row can "know" about attributes that other rows do not. This mirrors the Open World Assumption (OWA) of ontologies — the absence of a key does not mean the attribute is false, only that it is unrecorded. JSONB schemas benefit from an explicit ontology layer that declares which keys are "core" (always present, queryable, constrained) vs "extensional" (optional, domain-specific, unvalidated).

## Practice session
See `practice/intermediate/06-jsonb-modeling/` for hands-on exercises with a product catalog JSONB schema.

## References
- PostgreSQL docs — JSON Types: https://www.postgresql.org/docs/16/datatype-json.html
- PostgreSQL docs — JSON Functions: https://www.postgresql.org/docs/16/functions-json.html
- PostgreSQL docs — GIN Indexes: https://www.postgresql.org/docs/16/gin.html
- PostgreSQL docs — jsonb_path_query: https://www.postgresql.org/docs/16/functions-json.html#FUNCTIONS-SQLJSON-PATH
- Laurenz Albe, "JSONB in PostgreSQL": https://www.cybertec-postgresql.com/en/json-vs-jsonb-in-postgresql/
