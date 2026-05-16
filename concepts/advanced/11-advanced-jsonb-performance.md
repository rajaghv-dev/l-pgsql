# Advanced JSONB Performance

Level: Advanced

## One-line intuition
JSONB is a flexible semi-structured column type with binary storage and GIN indexing — but treating it as a schema escape hatch without understanding containment queries, path operators, and the EAV trade-off leads to indexes that don't fire and queries that scan full tables.

## Why this exists
JSONB enables storing structured data without schema rigidity — useful for metadata, configuration, extensible attributes, and event payloads. But JSONB queries follow different rules than typed column queries: operator choice determines whether GIN indexes fire, path expressions determine planner behavior, and containment semantics differ from equality. Advanced JSONB work requires understanding these internals.

## First-principles explanation

### JSONB storage
JSONB stores JSON in a binary format: keys are sorted, duplicates are removed, and the structure is represented as a tree of typed nodes (string, number, boolean, null, object, array). This binary form enables:
- Key existence checks without full deserialization
- Containment checks with efficient subtree comparison
- GIN indexing of individual keys and values

Contrast with `JSON` type: stores raw text, parsed on every access. JSONB is almost always preferred.

### GIN operator classes for JSONB
Two operator classes, with very different behaviors:

**`jsonb_ops`** (default): indexes every key and value at all nesting levels.
- Supports: `?` (key exists), `?|`, `?&`, `@>` (containment), `<@`
- Larger index (all keys and values)

**`jsonb_path_ops`**: indexes only values reachable via object paths.
- Supports: `@>` only
- Smaller index, faster for containment queries

```sql
-- blocked: Docker not accessible
-- Default operator class
CREATE INDEX idx_meta_gin ON events USING GIN (metadata);

-- Path-optimized (smaller, faster for @>)
CREATE INDEX idx_meta_path ON events USING GIN (metadata jsonb_path_ops);
```

**Rule**: if your queries are primarily `@>` containment checks, use `jsonb_path_ops`. If you need `?` key existence or `?|`/`?&`, use `jsonb_ops`.

### When GIN indexes fire (and when they don't)
GIN index is used for these operators:
- `metadata @> '{"status": "active"}'::jsonb` — containment: YES
- `metadata ? 'status'` — key exists: YES (jsonb_ops only)
- `metadata->>'status' = 'active'` — text extraction + equality: NO (needs expression index)
- `metadata->'config'->>'timeout' = '30'` — chained extraction: NO

For `->>`-based queries, create an expression index:
```sql
-- blocked: Docker not accessible
CREATE INDEX idx_meta_status ON events ((metadata->>'status'));
CREATE INDEX idx_meta_timeout ON events ((metadata->'config'->>'timeout'));
ANALYZE events;
-- Now: WHERE metadata->>'status' = 'active' uses idx_meta_status
```

### jsonb_path_query (PostgreSQL 12+)
SQL/JSON path language for navigating JSONB:
```sql
-- blocked: Docker not accessible
-- Extract all prices from an array of items
SELECT jsonb_path_query(order_data, '$.items[*].price')
FROM orders;

-- Filter: items where price > 100
SELECT jsonb_path_query(order_data, '$.items[*] ? (@.price > 100)')
FROM orders;

-- Existence check
SELECT * FROM orders
WHERE jsonb_path_exists(order_data, '$.items[*] ? (@.quantity > 10)');

-- First match
SELECT jsonb_path_query_first(order_data, '$.shipping.address.city')
FROM orders;
```

`jsonb_path_query` does not use GIN indexes (it's a function-based expression). Use it for extraction, not filtering predicates.

### Aggregation with JSONB
```sql
-- blocked: Docker not accessible
-- Aggregate rows into a JSONB array
SELECT customer_id,
       jsonb_agg(jsonb_build_object('id', id, 'status', status, 'amount', total_amount)
                 ORDER BY created_at DESC) AS orders
FROM orders
GROUP BY customer_id;

-- Aggregate into a JSONB object (key → value)
SELECT jsonb_object_agg(status, count) AS status_counts
FROM (SELECT status, count(*) FROM orders GROUP BY status) t;

-- Build a JSONB object from columns
SELECT jsonb_build_object(
    'id', id,
    'customer', jsonb_build_object('id', customer_id, 'name', customer_name),
    'total', total_amount
) FROM orders;
```

### jsonb_to_record and jsonb_to_recordset
Convert JSONB to typed rows:
```sql
-- blocked: Docker not accessible
-- Single object to typed record
SELECT *
FROM jsonb_to_record('{"id":1,"name":"Alice","score":9.5}'::jsonb)
AS t(id int, name text, score numeric);

-- Array of objects to rows
SELECT *
FROM jsonb_to_recordset('[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]'::jsonb)
AS t(id int, name text);
```

### Performance comparison: JSONB vs EAV vs typed columns

| Approach | Insert cost | Query speed | Indexing | Schema evolution |
|---|---|---|---|---|
| Typed columns | Low | Fastest | Any index type | DDL required |
| JSONB | Medium | Fast with GIN | GIN (containment) | Zero DDL |
| EAV (entity-attribute-value) | High | Slow (pivots) | Limited | Zero DDL |

JSONB is the middle ground: better than EAV for queries, worse than typed columns for heavy analytical aggregation. Use JSONB for:
- Heterogeneous attributes (different entities have different keys)
- Configuration and metadata
- Payload storage where content is opaque to the database

Use typed columns for:
- Frequently queried, filtered, or sorted attributes
- Attributes used in joins
- Attributes needing range indexes or statistical optimization

### Update patterns (JSONB mutation)
```sql
-- blocked: Docker not accessible
-- Merge (update one key, preserve others)
UPDATE events
SET metadata = metadata || '{"status": "processed"}'::jsonb
WHERE id = 1;

-- Delete a key
UPDATE events
SET metadata = metadata - 'temp_field'
WHERE id = 1;

-- Set nested key (PostgreSQL 9.5+ jsonb_set)
UPDATE events
SET metadata = jsonb_set(metadata, '{config, timeout}', '60'::jsonb)
WHERE id = 1;

-- Prepend to array
UPDATE events
SET metadata = jsonb_set(metadata, '{tags}',
    (metadata->'tags') || '["new_tag"]'::jsonb)
WHERE id = 1;
```

**Performance note**: JSONB updates always write the full column value (PostgreSQL cannot partially update a JSONB value in-place). Frequent small updates to JSONB columns cause high dead-tuple rates. Consider separate columns for frequently-updated attributes.

## Micro-concepts
- **`@>`**: containment operator. `'{"a":1,"b":2}'::jsonb @> '{"a":1}'::jsonb` = true. The index-eligible operator for GIN.
- **`?`**: key existence. `'{"a":1}'::jsonb ? 'a'` = true. Only indexable with `jsonb_ops`.
- **`->>`**: extract as text. Not GIN-indexed; requires expression index for predicate use.
- **`#>>`**: extract nested as text using array path. `metadata #>> '{config,timeout}'`.
- **jsonb_strip_nulls**: removes null-valued keys. Useful for compacting sparse documents.
- **GIN pending list**: JSONB GIN indexes use the pending list for batched updates. Under heavy insert load, pending list drain can cause temporary scan slowdown.
- **`jsonb_each`**: expands a JSONB object into a set of (key, value) pairs. Used for dynamic key enumeration.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Store JSON with JSONB, use `->` and `->>` to access fields, GIN index for full-document search.

**Intermediate view**: GIN indexes fire for `@>` and `?`. Use `jsonb_path_ops` for pure containment queries. Create expression indexes for `->>` predicates. Avoid EAV.

**Advanced view**: JSONB query optimization requires matching the operator class to the query pattern. `jsonb_path_query` is for extraction, not filtering (no GIN benefit). JSONB updates write the full value — high update rate on JSONB columns requires aggressive autovacuum tuning. The `||` merge operator rewrites the entire column; for N keys updated per transaction, write amplification is proportional to document size, not key count. At scale, a hybrid model (frequently-queried attributes as typed columns + JSONB for the rest) outperforms pure JSONB while maintaining schema flexibility.

## Mental model
JSONB is a flexible envelope that the database can see inside (unlike a text blob). GIN creates an index to every item in the envelope — but only if you ask the right question (containment `@>`, key existence `?`). Asking "what's in the 'status' field?" using `->>` is like asking the post office to read the letter (no index). Asking "does this envelope contain a stamp?" using `@>` is what the GIN index was built for. Expression indexes on `->>'field'` teach the post office to recognize specific letter types.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_indexes` (to see GIN indexes on JSONB columns), `pg_stats` (for indexed expression columns).

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Check which JSONB operators are used in queries (pg_stat_statements)
SELECT query, calls, total_exec_time
FROM pg_stat_statements
WHERE query ILIKE '%@>%' OR query ILIKE '%->>%'
ORDER BY total_exec_time DESC LIMIT 10;

-- Compare index sizes
SELECT indexrelname, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE relname = 'events';
```

**Non-SQL / hybrid view**: `jq` for command-line JSONB manipulation. `pg_trgm` GIN index on JSONB text values enables similarity search. If JSONB columns grow beyond 1MB regularly, consider `pg_lz` compression behavior (TOAST) — large JSONB values are TOASTed and cannot be GIN-indexed effectively.

## Design principle
**JSONB should be for structure uncertainty, not query avoidance**: If you know you will filter on a field, that field should be a typed column with a proper index. JSONB's value is in handling unknown future fields, optional attributes, and heterogeneous entity shapes — not in avoiding schema design.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: The `||` merge operator on large JSONB documents is expensive — it deserializes both sides, merges, and serializes the result. For documents with hundreds of keys, this is non-trivial CPU work. Benchmark before using JSONB as a general-purpose in-database object store for large documents.

**Creative**: Use JSONB as a versioned changelog column. Store the diff as JSONB in a changes table: `{op: "update", before: {...}, after: {...}, changed_at: "..."}`. This is lighter than audit triggers and more queryable than a raw text log.

**Systems**: JSONB GIN indexes are particularly sensitive to data cardinality. If a JSONB column has keys with very high cardinality (e.g., UUIDs as values), the GIN posting lists become large, and the index may grow larger than the table itself. Monitor with `pg_relation_size()` and consider whether GIN provides enough query benefit to justify the overhead.

## MCP and agent perspective
AI agents often store unstructured metadata about tasks, tools, or context as JSONB. For agent observability, structure the JSONB schema enough to create expression indexes on the fields you actually filter on (`agent_id`, `session_id`, `status`). Use `jsonb_agg` to build conversation history objects for LLM context windows efficiently. Reserve pure JSONB for truly variable, opaque payloads (tool arguments, LLM responses, error details).

## Ontology perspective
JSONB represents a compromise between structured (relational) and unstructured (document) data models. The GIN index creates a partial relational view of the document — an inverted mapping from values to rows — without requiring a fully declared schema. This is ontological pluralism: the database simultaneously models both the structured relationships it knows about (typed columns, indexes) and the unknown future structure (JSONB). The choice of operator class (`jsonb_ops` vs `jsonb_path_ops`) is a commitment to a specific query ontology: membership-focused or containment-focused.

## Practice session

**Exercise 1 — GIN index effectiveness**: Compare `@>` vs `->>` with EXPLAIN.
```sql
-- blocked: Docker not accessible
CREATE TABLE test_json (id serial, data jsonb);
CREATE INDEX idx_data_gin ON test_json USING GIN (data jsonb_path_ops);
-- GIN used:
EXPLAIN SELECT * FROM test_json WHERE data @> '{"status":"active"}';
-- GIN NOT used (need expression index):
EXPLAIN SELECT * FROM test_json WHERE data->>'status' = 'active';
```

**Exercise 2 — Expression index for text extraction**:
```sql
-- blocked: Docker not accessible
CREATE INDEX idx_data_status ON test_json ((data->>'status'));
EXPLAIN SELECT * FROM test_json WHERE data->>'status' = 'active';
-- Now uses idx_data_status
```

**Exercise 3 — jsonb_agg for history**: Aggregate rows into JSONB array.
```sql
-- blocked: Docker not accessible
SELECT customer_id,
       jsonb_agg(jsonb_build_object('order_id', id, 'status', status)
                 ORDER BY created_at DESC) AS order_history
FROM orders
GROUP BY customer_id
LIMIT 5;
```

**Exercise 4 — jsonb_path_query extraction**: Navigate nested structures.
```sql
-- blocked: Docker not accessible
SELECT id, jsonb_path_query(data, '$.tags[*]') AS tag
FROM test_json
WHERE jsonb_path_exists(data, '$.tags[*] ? (@ == "urgent")');
```

**Exercise 5 — Update JSONB key safely**:
```sql
-- blocked: Docker not accessible
UPDATE test_json
SET data = jsonb_set(data, '{priority}', '99'::jsonb, true)
WHERE id = 1;
-- jsonb_set(target, path, new_value, create_if_missing)
```

## References
- PostgreSQL Documentation: [JSON Functions and Operators](https://www.postgresql.org/docs/16/functions-json.html)
- PostgreSQL Documentation: [JSON Types](https://www.postgresql.org/docs/16/datatype-json.html)
- PostgreSQL Documentation: [SQL/JSON Path Language](https://www.postgresql.org/docs/16/functions-json.html#FUNCTIONS-SQLJSON-PATH)
- Oleg Bartunov & Alexander Korotkov: [JSONB in PostgreSQL](https://www.pgconf.eu/2014/pgconfeu2014-jsonb.pdf)
- Laurenz Albe: [JSONB Indexing](https://www.cybertec-postgresql.com/en/jsonb-indexing/)
- Hubert Lubaczewski: [JSONB vs EAV comparison](https://www.depesz.com/)
