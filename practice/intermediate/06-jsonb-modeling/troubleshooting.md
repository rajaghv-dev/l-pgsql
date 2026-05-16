# Troubleshooting — JSONB Modeling

## ERROR: invalid input syntax for type json
**Cause:** Malformed JSON literal in SQL.
**Fix:** Validate JSON before inserting. Single quotes wrap the JSON string in SQL; double quotes are for JSON keys/values.
```sql
-- Correct:
INSERT INTO products (..., attributes) VALUES (..., '{"key":"value"}');
-- Wrong (unquoted key):
INSERT INTO products (..., attributes) VALUES (..., '{key:"value"}');
```

## GIN index not being used
**Cause:** Query uses `->>` equality instead of `@>` containment.
```sql
-- Does NOT use GIN:
WHERE attributes ->> 'color' = 'blue'
-- Uses GIN:
WHERE attributes @> '{"color":"blue"}'
```
For `->>` equality queries, create an expression index:
```sql
CREATE INDEX ON products ((attributes ->> 'color'));
```

## jsonb_set returns NULL
**Cause:** Target JSONB column is NULL.
**Fix:** Coalesce to empty object:
```sql
UPDATE products
SET attributes = jsonb_set(COALESCE(attributes, '{}'), '{new_key}', '"value"')
WHERE id = 1;
```

## Generated column expression errors
**Error:** `ERROR: cannot use column reference in default expression`
**Cause:** Generated column syntax requires GENERATED ALWAYS AS (...) STORED.
```sql
-- Correct:
ADD COLUMN brand TEXT GENERATED ALWAYS AS (attributes ->> 'brand') STORED;
```

## Performance: GIN index too large
**Symptom:** `pg_indexes_size('products')` is much larger than `pg_total_relation_size('products')`.
**Fix:** Consider `jsonb_path_ops` opclass for a smaller index (supports only `@>`):
```sql
CREATE INDEX ON products USING gin(attributes jsonb_path_ops);
```
Or promote frequently-queried keys to real columns with smaller B-tree indexes.

## Casting numeric JSONB values
**Problem:** `WHERE (attributes ->> 'ram_gb') > 8` compares as text, not numeric.
**Fix:** Cast explicitly:
```sql
WHERE (attributes ->> 'ram_gb')::numeric > 8
```
Or use jsonb containment if the value is known:
```sql
WHERE attributes @> '{"ram_gb": 16}'
```
