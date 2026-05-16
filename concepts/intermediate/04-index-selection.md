# Index Selection
Level: Intermediate

## One-line intuition
Choosing the wrong index type is like using a phone book to find all residents within 5 km — it's sorted by name, not location. Each index type is optimized for a specific class of query.

## Why this exists
PostgreSQL supports multiple index types because no single data structure is optimal for all query shapes. Choosing the right type determines whether a query takes microseconds or seconds.

## First-principles explanation
An index is a separate data structure that maps column values to physical row locations (heap TIDs). The tradeoff is: indexes speed up reads by pre-organizing data, but they add overhead on every write (INSERT, UPDATE, DELETE must update all indexes on that table).

The "right" index type depends on:
1. What operators appear in your WHERE clauses (`=`, `<`, `>`, `@>`, `&&`, `@@`)
2. Whether you need ORDER BY satisfaction without a sort step
3. The data distribution (cardinality, clustering)

## Micro-concepts
| Index type | Optimized for | Key operators |
|---|---|---|
| B-tree | Equality, range, ORDER BY | `=`, `<`, `>`, `<=`, `>=`, `BETWEEN`, `IS NULL` |
| GIN | Multi-value columns, containment | `@>`, `<@`, `&&`, `@@` (full-text) |
| GiST | Geometric/spatial, ranges, full-text | `&&`, `>>`, `@>`, `<->` (distance) |
| BRIN | Large append-only tables with natural ordering | Range-level block summaries |
| Hash | Equality only | `=` |
| SP-GiST | Non-balanced, recursive structures (quad-trees, tries) | Type-specific |

## Beginner view
For 95% of relational queries (equality, range, ORDER BY): use B-tree. It is the default when you write `CREATE INDEX`.

```sql
-- B-tree (default)
CREATE INDEX ON orders (customer_id);       -- equality lookups
CREATE INDEX ON orders (ordered_at);        -- range queries, ORDER BY
CREATE INDEX ON products (price);           -- WHERE price BETWEEN 10 AND 50
```

## Intermediate view
**B-tree**: Default. Use for any column queried with `=`, `<`, `>`, `BETWEEN`, `ORDER BY`, or `IS NULL`. Supports multi-column (composite) indexes where the leading column is the most selective filter.

**GIN (Generalized Inverted Index)**: Use when a column contains multiple values that are queried individually.
```sql
-- JSONB containment queries
CREATE INDEX ON products USING GIN (attrs);
-- Query: WHERE attrs @> '{"color": "black"}'

-- Array containment
CREATE INDEX ON articles USING GIN (tags);
-- Query: WHERE tags @> ARRAY['postgres', 'indexing']

-- Full-text search
CREATE INDEX ON articles USING GIN (to_tsvector('english', body));
-- Query: WHERE to_tsvector('english', body) @@ plainto_tsquery('index tuning')
```

**GiST (Generalized Search Tree)**: Use for geometric/range types and full-text. Required for EXCLUDE constraints. Slower to build than GIN but supports more operators (including distance `<->`).
```sql
-- Required for EXCLUDE constraint on ranges
CREATE INDEX ON reservations USING GIST (room_id, during);

-- PostGIS geometric queries
CREATE INDEX ON locations USING GIST (geom);
```

**BRIN (Block Range INdex)**: Use for very large tables where data is physically sorted by the indexed column (e.g., time-series tables where rows are inserted in time order). BRIN stores min/max per block range, not per row — tiny size but coarse resolution.
```sql
-- Events table with billions of rows, inserted in timestamp order
CREATE INDEX ON events USING BRIN (occurred_at);
-- Tiny index: ideal when data is physically ordered and table is huge
-- WRONG use: unordered data — BRIN would not help
```

**Hash**: Slightly faster than B-tree for pure equality (`=`) lookups, but not useful for range queries and cannot satisfy ORDER BY. Rarely preferred over B-tree in practice.

## Advanced view
**Index overhead on writes**: Every index on a table adds work to INSERT, UPDATE (on indexed columns), and DELETE. A table with 10 indexes pays 10× the index-update cost per write. Monitor with:
```sql
SELECT indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE relname = 'orders';
-- Indexes with idx_scan = 0 are unused — consider dropping them
```

**When NOT to index**: Small tables (< ~1000 rows) — the planner prefers a seq scan because reading the index plus the heap is more work than reading the heap directly. Also: write-heavy tables where the index maintenance cost outweighs the query speedup.

**Index bloat**: Dead rows from UPDATE/DELETE leave dead entries in indexes. `VACUUM` cleans them. Monitor with `pgstatindex` extension:
```sql
SELECT * FROM pgstatindex('orders_customer_id_idx');
```

## Mental model
Think of index types as different kinds of catalog systems:
- **B-tree** = alphabetical index (sorted — great for ranges and ORDER BY)
- **GIN** = keyword index (each word in a document maps to all documents containing it)
- **GiST** = spatial map grid (great for "all points within this bounding box")
- **BRIN** = shelf label (just records "books on this shelf are numbered 1–500")
- **Hash** = dictionary (fast exact lookup, useless for "words near X")

## PostgreSQL view
```sql
-- List indexes with their type and size
SELECT
    i.indexname,
    i.indexdef,
    pg_size_pretty(pg_relation_size(i.indexname::regclass)) AS index_size
FROM pg_indexes i
WHERE tablename = 'products';

-- Check index usage stats
SELECT indexrelname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes
WHERE relname = 'products'
ORDER BY idx_scan DESC;

-- Unused indexes (candidates for removal)
SELECT indexrelname FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND relname NOT LIKE 'pg_%';
```

## SQL view
```sql
-- B-tree (default)
CREATE INDEX orders_customer_idx ON orders (customer_id);
CREATE INDEX orders_date_idx     ON orders (ordered_at DESC);

-- GIN for JSONB
CREATE INDEX products_attrs_gin  ON products USING GIN (attrs);

-- GIN for full-text
CREATE INDEX articles_fts_gin    ON articles
    USING GIN (to_tsvector('english', title || ' ' || body));

-- BRIN for time-series
CREATE INDEX events_time_brin    ON events USING BRIN (occurred_at);

-- Partial index (subset of rows)
CREATE INDEX orders_pending_idx  ON orders (ordered_at)
    WHERE status = 'pending';

-- validation: blocked — Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled
```

## Non-SQL or hybrid view
- **Elasticsearch**: Inverted index (like GIN) by default for all fields. Not suitable for range-heavy analytics.
- **MongoDB**: Supports B-tree equivalent, multikey (GIN equivalent), text, and geospatial indexes. No BRIN equivalent.
- **Redis Sorted Sets**: B-tree equivalent for score-based range queries.

## Design principle
**Index for your queries, not for your data model.** An index on a FK column is common but not automatic in PostgreSQL (unlike MySQL). Always check: which queries are slow? which columns appear in WHERE, JOIN ON, ORDER BY? Index those.

## Critical thinking
- An unused index (idx_scan = 0 in pg_stat_user_indexes) is not free — it adds write overhead. Audit and drop unused indexes periodically.
- GIN indexes are large (can exceed table size for JSONB-heavy tables). Balance query speed against storage cost.
- BRIN only helps when data is physically ordered. After bulk inserts in non-time order, BRIN provides no benefit. Run `CLUSTER` or use a time-partitioned table instead.

## Creative thinking
- What if you indexed the output of a function? Expression indexes (`LOWER(email)`) allow case-insensitive queries without altering stored data. See `05-composite-partial-expression-indexes.md`.
- Covering indexes (with `INCLUDE`) can eliminate heap fetches entirely for specific query patterns, turning an index scan into an index-only scan.

## Systems thinking
Index selection interacts with autovacuum, table bloat, and write throughput at scale. A GIN index on a frequently updated JSONB column will bloat quickly and require more aggressive vacuuming. Index type choice is a systems-level decision, not just a query-level one.

## MCP and agent perspective
Agents that dynamically generate WHERE clauses (e.g., filter by arbitrary JSONB keys) should ensure a GIN index exists. Without it, every dynamic filter is a seq scan — potentially scanning millions of rows. Index selection for agent-generated queries requires understanding the query space upfront, not just the current query.

## Ontology perspective
An index is a materialized access path — a pre-computed structure that answers a specific class of questions efficiently. Different index types correspond to different query algebras: B-tree supports ordered comparisons; GIN supports set-membership queries; GiST supports topological predicates. Index selection is choosing which query algebra to pre-optimize for.

## Practice session
See `practice/intermediate/02-indexing-strategies/` for hands-on comparison of index types with EXPLAIN ANALYZE.

## References
- PostgreSQL docs — Index types: https://www.postgresql.org/docs/16/indexes-types.html
- PostgreSQL docs — GIN indexes: https://www.postgresql.org/docs/16/gin.html
- PostgreSQL docs — GiST indexes: https://www.postgresql.org/docs/16/gist.html
- PostgreSQL docs — BRIN indexes: https://www.postgresql.org/docs/16/brin.html
- PostgreSQL docs — pg_stat_user_indexes: https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ALL-INDEXES-VIEW
- Use The Index, Luke — Index internals: https://use-the-index-luke.com/sql/anatomy
- pgstatindex: https://www.postgresql.org/docs/16/pgstatindex.html
