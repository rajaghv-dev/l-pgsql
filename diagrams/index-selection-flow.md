# Index Selection Flow

Decision flowchart for choosing the right PostgreSQL index type for your query pattern.

```mermaid
flowchart TD
    START["What query pattern\ndo you need to support?"]

    EQ["Equality, range,\nOR ORDER BY?"]
    JSONB_ARR["JSONB containment,\narrays, or FTS\n(tsvector / pg_trgm)?"]
    GEO["Geometric types,\nrange type exclusion,\nor FTS with ranking?"]
    MONO["Append-only table with\nmonotonically increasing\ncolumn (time, ID)?"]
    HASH_Q["Equality-only, no range,\nno ordering needed?"]
    PARTIAL_Q["Most queries filter\non a common condition\n(e.g., status = 'active')?"]

    BTREE["B-tree index\n\nBest for:\n• = < > BETWEEN\n• ORDER BY\n• IS NULL\n• LIKE 'prefix%'\n\nDefault index type."]
    GIN["GIN index\n\nBest for:\n• JSONB @>, ?\n• Array @>, &&\n• tsvector @@ tsquery\n• pg_trgm LIKE / %\n\nFast lookup, slow update."]
    GIST["GiST index\n\nBest for:\n• Geometric types (PostGIS)\n• Range type &&, @>\n• FTS with ranking/distance\n• Exclusion constraints\n\nFaster update than GIN."]
    BRIN["BRIN index\n\nBest for:\n• append-only tables\n• created_at, sensor_time\n• Very large tables\n\nTiny size, coarse granularity.\nWorks when physical order\ncorrelates with query range."]
    HASH["Hash index\n\nBest for:\n• Exact equality only\n• No range, no ORDER BY\n\nRarely better than B-tree.\nNot WAL-logged before PG10."]
    PARTIAL["Partial index\nADD WHERE clause\n\nExample:\nCREATE INDEX ON orders(user_id)\nWHERE status = 'pending';\n\nSmaller, faster when most\nqueries filter on that condition."]

    START --> EQ
    EQ -->|Yes| BTREE
    EQ -->|No| JSONB_ARR
    JSONB_ARR -->|Yes| GIN
    JSONB_ARR -->|No| GEO
    GEO -->|Yes| GIST
    GEO -->|No| MONO
    MONO -->|Yes| BRIN
    MONO -->|No| HASH_Q
    HASH_Q -->|Yes| HASH
    HASH_Q -->|No| PARTIAL_Q
    PARTIAL_Q -->|Yes| PARTIAL
```

## Quick reference table

| Index type | Operators | Size | Update cost | Notes |
|------------|-----------|------|-------------|-------|
| B-tree | `=`, `<`, `>`, `BETWEEN`, `LIKE 'x%'` | Medium | Low | Default; use for almost everything |
| GIN | `@>`, `?`, `@@`, `%` | Large | High | Bulk-load then index; use `fastupdate` |
| GiST | `&&`, `@>`, `<->` (distance) | Medium | Medium | Exclusion constraints require GiST |
| BRIN | `=`, range on correlated data | Tiny | Very low | 128-page block ranges by default |
| Hash | `=` only | Medium | Low | Almost never preferred over B-tree |
| Partial | Any (adds WHERE filter) | Small | Low | Combine with any of the above |

## Diagnosing index usage

```sql
-- See which indexes exist and their sizes
SELECT indexname, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE relname = 'orders';

-- See which indexes are NOT being used (candidates for removal)
SELECT indexrelname, idx_scan
FROM pg_stat_user_indexes
WHERE relname = 'orders'
ORDER BY idx_scan ASC;

-- Confirm the planner uses your index
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE user_id = 42;
```
