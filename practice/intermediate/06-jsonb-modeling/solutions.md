# Solutions — JSONB Modeling

**Status: blocked — Docker not accessible in this session**

## Exercise 1 solution
`->` returns a JSONB value (e.g., `"Nexus"` as a JSON string). `->>` returns a TEXT value (`Nexus` without quotes). Use `->>` for text comparisons and display; use `->` for passing to other JSON operators or when you need the JSON type preserved.

## Exercise 2 solution
The EXPLAIN output should show `Bitmap Index Scan using products_attributes_idx` with `Index Cond: (attributes @> '{"color":"black"}'::jsonb)`. A Seq Scan here means the index was not created or the query is not in containment form (`@>`).

## Exercise 3 solution
- `||` (concatenation) merges two JSONB objects; right side wins on duplicate keys
- `jsonb_set(target, path_array, new_value)` — path is a text array e.g. `'{ram_gb}'`
- `-` operator with a text key removes that key from the object

After updates:
- Laptop X1: `ram_gb=32`, `on_sale=true` added
- Tablet Pro: `has_stylus` removed

## Exercise 4 solution
Electronics attribute keys: `brand`, `color`, `has_stylus`, `ram_gb`, `storage_gb`, `weight_kg`.

The most common keys across all products: `brand` (8), `color` (6), `vegan` (2), etc. This aggregation is the basis for deciding which keys to promote to real columns.

## Exercise 5 solution
After adding the generated column and index:
- `EXPLAIN SELECT * FROM products WHERE brand = 'Nexus'` shows `Index Scan using products_brand_idx`
- Much cheaper than `WHERE attributes ->> 'brand' = 'Nexus'` which requires GIN or seq scan + expression eval

Generated columns (STORED) recompute the value on every INSERT/UPDATE and persist it, making reads free.

## Exercise 6 solution
`jsonb_agg` collects rows into a JSONB array. `jsonb_build_object` constructs a JSONB object from key-value pairs. Combined, they produce:
```json
[
  {"id": 7, "name": "Dark Chocolate", "price": 4.99},
  {"id": 8, "name": "Oat Milk", "price": 3.49}
]
```

The brand aggregation shows each brand and its product names as a JSON array — useful for building API responses directly in SQL.

## Reflection answers
1. Promote to a real column when: the key appears in nearly all rows, is used in ORDER BY or JOIN conditions, needs a foreign key or check constraint, or is queried more efficiently with a B-tree than a GIN index.
2. `-> 'key'` returns JSONB (useful for chaining operators); `->> 'key'` returns TEXT (for display and string comparisons). Type matters when casting: `(attributes ->> 'price')::numeric` vs `attributes -> 'price'` which is still JSON.
3. GIN on JSONB indexes every (key, value) pair as a separate entry. A product with 10 keys creates 10+ GIN index entries. For a table with 1M rows and 20 keys each, the GIN index can be 5-10x larger than a B-tree on a single column.
4. Use a CHECK constraint:
```sql
ALTER TABLE products ADD CONSTRAINT electronics_must_have_brand
CHECK (category_id != 1 OR attributes ? 'brand');
```
