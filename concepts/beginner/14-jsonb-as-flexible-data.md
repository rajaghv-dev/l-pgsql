# JSONB as Flexible Data

Level: Beginner

## One-line intuition

JSONB lets you store a JSON object as a column value — useful when the shape of the data varies per row.

## Why this exists

Relational tables have fixed columns — every row has the same structure. Sometimes data is inherently variable: user preferences, product metadata, event payloads, configuration objects. JSONB stores this variable structure inside one column without requiring schema changes.

## First-principles explanation

PostgreSQL has two JSON types:

- `json`: stores the raw JSON text, validates syntax, slower to query.
- `jsonb`: stores parsed binary representation, faster to query, supports indexing, loses key insertion order.

**Always prefer `jsonb` over `json`** unless you need to preserve exact key order or whitespace (rare).

JSONB is not a replacement for proper columns. It is a escape hatch for genuinely variable structure. If you know the fields, use columns.

## Micro-concepts

| Operator | Input | Returns | Example |
|----------|-------|---------|---------|
| `->` | jsonb, key/index | jsonb | `data->'name'` → `"Alice"` (jsonb) |
| `->>` | jsonb, key/index | text | `data->>'name'` → `Alice` (text) |
| `#>` | jsonb, path array | jsonb | `data#>'{address,city}'` |
| `#>>` | jsonb, path array | text | `data#>>'{address,city}'` |
| `@>` | jsonb @> jsonb | boolean | "contains" — useful in WHERE |
| `?` | jsonb ? text | boolean | key exists |
| `jsonb_set()` | function | jsonb | update nested key |
| `||` | jsonb \|\| jsonb | jsonb | merge two jsonb objects |

## Beginner view

Think of JSONB as a labeled bag attached to each row. A user row might have a bag with `{"theme": "dark", "language": "en", "notifications": true}`. Another user's bag might have completely different keys. The database stores whatever is in the bag and lets you reach into it with operators.

```sql
-- Create table with jsonb column
CREATE TABLE user_profiles (
    id       SERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    metadata JSONB
);

-- Insert with JSONB
INSERT INTO user_profiles (username, metadata)
VALUES ('alice', '{"theme": "dark", "lang": "en", "age": 30}');

-- Get a value as jsonb (keeps type)
SELECT metadata->'age' FROM user_profiles WHERE username = 'alice';
-- Returns: 30 (jsonb integer)

-- Get a value as text
SELECT metadata->>'lang' FROM user_profiles WHERE username = 'alice';
-- Returns: en (text)

-- Filter by JSONB content (@> = "contains")
SELECT username FROM user_profiles
WHERE metadata @> '{"theme": "dark"}';
```

## Intermediate view

**Updating a nested key** (jsonb is immutable — you must replace the whole value):

```sql
UPDATE user_profiles
SET metadata = jsonb_set(metadata, '{theme}', '"light"')
WHERE username = 'alice';
```

**Adding a new key**:

```sql
UPDATE user_profiles
SET metadata = metadata || '{"premium": true}'
WHERE username = 'alice';
```

**GIN index** for fast `@>`, `?`, and `?|` queries:

```sql
CREATE INDEX idx_profiles_metadata ON user_profiles USING GIN (metadata);
```

Without the GIN index, `WHERE metadata @> '{"theme": "dark"}'` requires a sequential scan of all rows.

**jsonb_each()** and **jsonb_object_keys()** expand JSONB into rows — useful for dynamic schema exploration.

## Advanced view

- `jsonb_path_query()` and `@@` operator: SQL/JSON path language (PostgreSQL 12+) for complex JSONB traversal.
- GIN index options: `jsonb_ops` (default, full-key search) vs `jsonb_path_ops` (faster for `@>` only, smaller index).
- JSONB columns are not schema-validated by default. Use `CHECK` constraints with `jsonb_typeof()` or custom functions for validation.
- For time-series or append-only JSONB, consider the `jsonb_insert()` function.

## Mental model

JSONB is a hybrid: it is relational (lives in a column, can be indexed, can be queried with SQL) but it is also schemaless (the shape inside the column is not enforced). You get the best of both worlds for variable data, but you lose compile-time schema guarantees.

## PostgreSQL view

```sql
-- Inspect JSONB structure
SELECT jsonb_pretty(metadata) FROM user_profiles WHERE id = 1;

-- Extract all keys
SELECT jsonb_object_keys(metadata) FROM user_profiles;

-- Type of a value
SELECT jsonb_typeof(metadata->'age') FROM user_profiles LIMIT 1;
-- Returns: number

-- Available GIN operator classes
SELECT opcname FROM pg_opclass WHERE opcmethod = (SELECT oid FROM pg_am WHERE amname = 'gin');
```

## SQL view

```sql
-- Find users whose metadata contains a specific nested value
SELECT username
FROM user_profiles
WHERE metadata @> '{"notifications": {"email": true}}';

-- Extract and cast
SELECT
    username,
    (metadata->>'age')::int AS age
FROM user_profiles
WHERE metadata ? 'age'
  AND (metadata->>'age')::int > 25;

-- Update nested value safely
UPDATE user_profiles
SET metadata = jsonb_set(metadata, '{notifications,email}', 'false', true)
WHERE username = 'alice';
-- true = create path if it doesn't exist
```

## Non-SQL or hybrid view

In MongoDB, every document is JSONB-like — the entire row is a flexible document. PostgreSQL's JSONB gives you that flexibility in one column while keeping structured columns for the fields you know. This hybrid approach is often the best choice when migrating from MongoDB.

## Design principle

**If you know the field, use a column. If the field varies per row, use JSONB.** Mixing is fine: a `users` table with fixed columns (`id`, `email`, `created_at`) and one `metadata JSONB` column for variable preferences. Do not put everything in JSONB — you lose type safety, foreign keys, and efficient column-level indexing.

## Critical thinking

- JSONB operators (`->`, `->>`...) require the key to exist. If the key is missing, the result is NULL, not an error. Always use `WHERE metadata ? 'key'` before casting if you need to guarantee the key exists.
- Schema drift: if every row has different JSONB keys, queries become hard to write. Establish a convention for which keys are "standard" and document them, even if they are not enforced by a column constraint.

## Creative thinking

Use JSONB as a versioned schema migration helper: add new fields to JSONB first, migrate gradually to proper columns once the field is stable, then drop the JSONB key. This avoids downtime from ALTER TABLE on large tables.

## Systems thinking

JSONB is PostgreSQL's answer to the "schema evolution" problem in distributed systems. Event-driven architectures produce payloads with variable fields. Storing them in JSONB lets you ingest without upfront schema decisions, then build proper columns as the schema stabilizes.

## MCP and agent perspective

Agents often receive arbitrary payloads (tool call results, webhook data). Storing these in a `payload JSONB` column:

1. Preserves the full payload without a migration.
2. Allows the agent to query specific fields with `->>`
3. A GIN index lets the agent search by payload content efficiently.
4. Wrap payload ingestion in a transaction so partial writes do not corrupt the record.

## Ontology perspective

- JSONB is a **semi-structured** data type — between fully structured (columns with types) and unstructured (text blob).
- The `@>` operator implements **containment** — a set-theoretic relationship.
- GIN index is an **inverted index** — maps values to the rows that contain them (same concept as a search engine index).
- JSONB and relational columns on the same table are a **hybrid data model**.

## Practice session

`practice/beginner/07-jsonb-basics/` — exercises: insert JSONB, query with operators, update nested key, add GIN index, filter with `@>`.

## References

| Resource | URL | Why |
|----------|-----|-----|
| PostgreSQL docs — JSONB | https://www.postgresql.org/docs/current/datatype-json.html | Types, operators, functions |
| PostgreSQL docs — GIN Indexes | https://www.postgresql.org/docs/current/gin.html | Index structure for JSONB |
| PostgreSQL docs — JSON Functions | https://www.postgresql.org/docs/current/functions-json.html | Full function and operator list |
| Crunchy Data — JSONB Guide | https://www.crunchydata.com/blog/unleashing-the-power-of-storing-json-in-postgres | Practical patterns |
