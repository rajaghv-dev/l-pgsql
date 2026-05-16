# Index Ontology

Level: Intermediate
Domain: PostgreSQL / Performance

## Definition
An index is an auxiliary data structure that allows PostgreSQL to locate rows matching a predicate without scanning the entire table, at the cost of additional storage and write overhead.

## Why this concept matters
Indexes are the single most impactful tool for query performance. The right index turns a seconds-long sequential scan into a sub-millisecond lookup; the wrong index wastes storage, slows writes, and confuses the planner. Understanding index types and their properties is non-negotiable for any production PostgreSQL workload.

## Related concepts
- [[schema-design-ontology]] — parent (indexes are defined on table columns)
- [[query-ontology]] — parent (the planner chooses index access paths)
- [[performance-ontology]] — child (index usage analyzed via statistics)
- [[extension-ontology]] — related (bloom, btree_gin, btree_gist extensions)
- [[vector-search-ontology]] — related (ivfflat, hnsw are specialized index types)
- [[geospatial-ontology]] — related (GiST indexes for spatial data)

---

## Index Types

### B-tree
One-line definition: The default index type; a balanced tree that supports equality, range, prefix, `IS NULL`, and `ORDER BY` queries.

Supports operators: `<`, `<=`, `=`, `>=`, `>`, `BETWEEN`, `IN`, `LIKE 'prefix%'`.

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_orders_created ON orders (created_at);
CREATE UNIQUE INDEX idx_users_email ON users (email);
```

Use when: Most cases — single column equality, range scans, sorts, foreign keys.

---

### GIN (Generalized Inverted Index)
One-line definition: An inverted index where each key maps to a set of matching row TIDs; optimal for multi-valued data types like arrays, JSONB, and tsvector (full-text search).

Supports: `@>`, `<@`, `&&`, `?`, `?|`, `?&` on arrays/JSONB; `@@` on `tsvector`.

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_docs_tokens ON documents USING GIN (to_tsvector('english', body));
CREATE INDEX idx_tags ON articles USING GIN (tags);  -- tags is an array column
```

Use when: Full-text search, JSONB containment, array membership.

Trade-off: Slower writes (complex to update); faster reads for multi-key lookups than multiple B-tree indexes.

---

### GiST (Generalized Search Tree)
One-line definition: A framework for building balanced tree indexes over arbitrary data types with user-defined key strategies; used for geometric, range, and full-text data.

Supports: Geometric operators (PostGIS), range type operators (`&&`, `@>`, `<@`), `tsvector` (less optimal than GIN).

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_events_period ON events USING GIST (period);  -- period is a tsrange
```

Use when: Range types, geometric data (PostGIS), exclusion constraints.

---

### BRIN (Block Range Index)
One-line definition: Stores min/max summaries per block range rather than individual row pointers; extremely compact but only useful when column values correlate with physical storage order.

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_events_ts_brin ON events USING BRIN (event_ts);
```

Use when: Very large append-only tables with naturally ordered columns (timestamps, sequence IDs). A 128-block BRIN index on a 100M-row table is tiny.

Limitations: Useless if data is not physically ordered; cannot enforce uniqueness.

---

### Hash
One-line definition: Stores a hash of the indexed value; supports only equality checks (`=`); faster than B-tree for equality-only workloads.

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_sessions_token ON sessions USING HASH (token);
```

Use when: Equality-only lookups on high-cardinality columns. Rarely the right choice — B-tree is almost as fast and more flexible.

---

### SP-GiST (Space-Partitioned GiST)
One-line definition: A partitioned search tree framework for non-balanced structures (quad-trees, kd-trees, radix trees); best for sparse multi-dimensional data or prefix text searches.

Use when: IP routing tables (inet type), phone numbers, quadtree spatial data.

---

### Bloom
One-line definition: A probabilistic index (via the `bloom` extension) that stores a Bloom filter per row; supports multi-column equality checks with possible false positives.

```sql
-- blocked: Docker not accessible
CREATE EXTENSION bloom;
CREATE INDEX idx_bloom ON t USING BLOOM (col1, col2, col3);
```

Use when: Many columns, each queried individually with equality, and high false-positive tolerance is acceptable. Rare in practice.

---

## Index Properties

### Partial Index
One-line definition: An index built over a subset of rows defined by a WHERE predicate; smaller and faster than a full-column index when queries target the same subset.

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_orders_pending ON orders (created_at)
WHERE status = 'pending';
-- Only pending orders are indexed; completed orders don't consume index space
```

Use when: Queries always filter by a fixed condition (status, is_active flag, date range).

---

### Composite Index
One-line definition: An index over multiple columns; the column order determines which query shapes the index can satisfy.

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_orders_user_created ON orders (user_id, created_at);
-- Supports: WHERE user_id = ? AND created_at > ?
-- Supports: WHERE user_id = ?  (leading column only)
-- Does NOT support: WHERE created_at > ?  (non-leading column alone)
```

Rule: The index supports any prefix of its column list. Put the most selective equality column first, then range columns.

---

### Expression Index (Functional Index)
One-line definition: An index on a computed expression rather than a raw column; the query predicate must use the identical expression to benefit.

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_users_email_lower ON users (lower(email));
-- Query must use: WHERE lower(email) = lower('User@Example.com')
```

Use when: Case-insensitive lookups, date truncation, JSONB field extraction.

---

### Covering Index (INCLUDE)
One-line definition: A B-tree index that stores additional non-key columns in leaf pages; enables index-only scans without visiting the heap.

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_orders_user_status ON orders (user_id) INCLUDE (status, total);
-- Query: SELECT status, total FROM orders WHERE user_id = ?
-- Can be answered without touching the heap
```

---

## Index Access Paths

| Access Path | When Used |
|-------------|-----------|
| Index Scan | Few matching rows; random heap access acceptable |
| Bitmap Index Scan | Medium selectivity; batches heap fetches by physical order |
| Index-Only Scan | All columns in query are in index (key + INCLUDE) |
| Sequential Scan | No usable index, or large fraction of rows match |

---

### Inspect index usage
```sql
-- blocked: Docker not accessible
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Find unused indexes (candidates for removal)
SELECT schemaname, tablename, indexname
FROM pg_stat_user_indexes
WHERE idx_scan = 0;
```

### Inspect index size
```sql
-- blocked: Docker not accessible
SELECT indexname, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE tablename = 'orders'
ORDER BY pg_relation_size(indexrelid) DESC;
```

---

## System catalog reference
- `pg_index` — index metadata (columns, unique, partial predicate)
- `pg_stat_user_indexes` — per-index access statistics
- `pg_am` — index access methods (btree, hash, gin, gist, brin, spgist, bloom)
- `pg_class` — index sizes (via `pg_relation_size`)

---

## Beginner mental model
An index is like the index at the back of a textbook — instead of reading every page, you look up the term, find the page number, and go directly there. Without an index, PostgreSQL reads every row (a full table scan).

## Intermediate mental model
Choose the index type based on the data type and query pattern: B-tree for ordered data and ranges, GIN for arrays/JSONB, GiST for ranges and geometry, BRIN for large sorted tables. Composite index column order matters: equality columns first, range columns last. Unused indexes hurt write performance and should be removed.

## Advanced mental model
The planner uses `pg_statistic` to estimate index selectivity. An index will be bypassed if the planner estimates it's cheaper to seq scan. Bloom and BRIN have specific physical layout requirements. HOT (Heap-Only Tuple) updates are only possible when no indexed column is modified — minimizing indexed columns reduces index bloat. `pg_stat_user_indexes.idx_scan = 0` identifies dead indexes, but wait for steady-state traffic before dropping.

## MCP and agent perspective
An agent can query `pg_stat_user_indexes` to audit index health and report unused indexes. Before executing a query with a filter predicate, agents can run EXPLAIN to verify index usage. Agents creating indexes should use `CREATE INDEX CONCURRENTLY` to avoid table locks in production. Agents must not drop indexes without human confirmation — the impact is immediate and can cause query timeouts.

## Practical implication
| Situation | Implication |
|-----------|-------------|
| Index on low-cardinality column (e.g., boolean) | Planner ignores it; not selective enough |
| Composite index (a, b) — query on b only | Index not used; reorder or create separate index on b |
| Expression index on lower(email) — query uses email directly | Index not used; query must use lower(email) |
| BRIN on randomly-inserted data | Useless; min/max per block is near full range |
| Many indexes on a write-heavy table | Each INSERT/UPDATE/DELETE must update every index |

## Obsidian connections
[[schema-design-ontology]] [[query-ontology]] [[performance-ontology]] [[transaction-ontology]] [[vector-search-ontology]] [[geospatial-ontology]] [[extension-ontology]]

## References
- PostgreSQL Indexes: https://www.postgresql.org/docs/16/indexes.html
- Index Types: https://www.postgresql.org/docs/16/indexes-types.html
- pg_stat_user_indexes: https://www.postgresql.org/docs/16/monitoring-stats.html
