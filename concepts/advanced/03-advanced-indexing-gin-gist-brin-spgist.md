# Advanced Indexing: GIN, GiST, BRIN, SP-GiST

Level: Advanced

## One-line intuition
B-tree handles ordered scalars beautifully — but for documents, arrays, ranges, spatial data, and monotonically-appended time-series, PostgreSQL provides four specialized index types that trade different resources and query shapes.

## Why this exists
B-tree assumes you are looking up a value in a total order. Many modern data types — full-text documents, JSONB, geometric shapes, IP ranges, vectors — have no natural total order or require containment/overlap queries that B-tree cannot express. GIN, GiST, BRIN, and SP-GiST exist because the access method API in PostgreSQL is open: any extension can provide an index type for any data type by implementing a standard operator class interface.

## First-principles explanation

### GIN — Generalized Inverted Index

**Concept**: An inverted index maps from *element* to *list of heap locations*. Identical structure to a full-text search index in Lucene. Each unique element (word, array value, JSONB key) has a posting list: the sorted list of heap tuple identifiers (TIDs) that contain it.

**Internal structure**:
- B-tree of unique keys (one per distinct element)
- Each key has a posting list (sorted array of TIDs) stored inline (small) or in overflow pages (large)
- A **pending list**: new entries go into a temporary unsorted list first, merged into the main structure by a background vacuum or when list exceeds `gin_pending_list_limit` (default 4MB)

**Fast-update trade-off**: `fastupdate = on` (default) batches inserts into the pending list → low write latency, slower reads until pending list is merged. `fastupdate = off` → every insert immediately updates the main structure → slower writes, no read degradation from pending list.

**Supported operators**: `@>` (contains), `<@` (contained by), `&&` (overlap), `=` (equality for arrays), `@@` (full-text match), `?` (JSONB key exists), `?|`, `?&`.

**Use cases**:
- Full-text search (`tsvector` columns)
- JSONB containment and key queries
- Array overlap and containment
- `pg_trgm` trigram similarity search
- `intarray` extension for integer set operations

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_docs_fts ON documents USING GIN (to_tsvector('english', body));
CREATE INDEX idx_tags ON posts USING GIN (tags);  -- tags is text[]
CREATE INDEX idx_metadata ON events USING GIN (metadata jsonb_path_ops);
```

**jsonb_ops vs jsonb_path_ops**: `jsonb_ops` (default) indexes every key and value; supports `?`, `?|`, `?&`, `@>`. `jsonb_path_ops` only indexes values for containment; smaller index, faster `@>` queries.

### GiST — Generalized Search Tree

**Concept**: A balanced tree where each node stores a *bounding predicate* — a lossy summary of everything in its subtree. At search time, the tree is traversed by testing predicates at each level. False positives require recheck against the heap.

**GiST is a framework**: the actual index behavior is defined by an operator class implementing 7 methods: `consistent`, `union`, `compress`, `decompress`, `penalty`, `picksplit`, `same`. This makes GiST extensible to any data type with a "bounding" semantic.

**Supported data types**:
- `geometry` (PostGIS) — bounding boxes
- `tsrange`, `int4range`, `daterange` — range overlap
- `tsvector` — partial match in text search
- `inet` / `cidr` — network address containment
- `point`, `box`, `circle`, `polygon` — geometric types

**Operators**: `&&` (overlap), `@>`, `<@`, `~=` (same), `<->` (distance for KNN), `<<` `>>` (left/right of), etc.

**KNN support**: GiST supports `ORDER BY expr <-> point` for nearest-neighbor queries (used by pgvector's IVFFlat, spatial KNN).

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_events_period ON events USING GIST (event_period);  -- tsrange
CREATE INDEX idx_locations ON places USING GIST (location);  -- point
```

**GiST vs GIN**: GiST is better for range/spatial/KNN; GIN is better for membership/containment in sets (tsvector, arrays, JSONB). GiST can update in-place; GIN uses a pending list for batch efficiency.

### BRIN — Block Range Index

**Concept**: Stores a *min/max summary per block range* (default: 128 blocks = 1MB). The entire index is tiny (one entry per range) but only useful when the physical order of heap blocks correlates with the indexed column (monotonically increasing).

**Structure**: For each block range: `allnulls`, `hasnulls`, `min_value`, `max_value`. Size ≈ table_size / 128 / page_size. A 100GB table has a ~800KB BRIN index.

**Query path**: Scan all block ranges; for each range, test if the query predicate could match (e.g., `WHERE ts > X` → skip ranges where max < X). Remaining blocks are heap-scanned.

**When to use**:
- Append-only tables (IoT timestamps, event logs, WAL archive tables)
- Columns that naturally increase with insertion order (created_at, sequence IDs)
- Very large tables where a B-tree index would itself be large

**When NOT to use**:
- Columns with low correlation to heap order (random UUIDs, shuffled inserts)
- High-cardinality lookups (BRIN cannot find a single row efficiently)

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_events_ts_brin ON events USING BRIN (created_at) WITH (pages_per_range = 64);
```

**BRIN vs B-tree for time-series**: BRIN is 1000x smaller; B-tree is 1000x more selective. For queries scanning large time ranges, BRIN is competitive. For point lookups, B-tree wins.

### SP-GiST — Space-Partitioned GiST

**Concept**: A family of space-partitioned trees — quadtrees, k-d trees, radix trees, prefix trees. Each node partitions the space into non-overlapping regions (unlike GiST which allows overlap). This gives better performance for highly clustered data or data with natural spatial partitioning.

**Supported types**:
- `point` — quadtree partition
- `box` — quadtree for 2D
- `polygon`, `circle` — some support
- `text` — prefix/radix tree (good for prefix queries like `LIKE 'foo%'`)
- `inet` / `cidr` — radix tree (good for IP range containment)

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_ip_spgist ON connections USING SPGIST (client_ip inet_ops);
CREATE INDEX idx_text_prefix ON docs USING SPGIST (title text_ops);
```

**SP-GiST vs GiST**: SP-GiST avoids key overlap between nodes → more efficient for well-partitioned data. GiST is more general. For spatial queries with PostGIS, GiST is standard; SP-GiST is used for point data in some cases.

## Micro-concepts
- **posting list**: the list of heap TIDs in a GIN index entry. Stored compressed.
- **gin_pending_list_limit**: max size of GIN pending list before forced cleanup (default 4MB). Tune up for write-heavy workloads, down for read-heavy.
- **pages_per_range** (BRIN): number of heap blocks per BRIN summary. Default 128. Smaller = more granular = better selectivity but larger index.
- **lossy recheck**: GiST returns candidates that pass the bounding predicate but may not satisfy the exact predicate. A recheck on the heap tuple is needed.
- **operator class**: the binding between a data type, an index type, and the operators the index can satisfy. `CREATE INDEX USING GIN (col jsonb_path_ops)` uses the `jsonb_path_ops` operator class.
- **index-only scan**: GIN and GiST do not support index-only scans (they cannot reconstruct column values from index entries alone). B-tree and BRIN do support limited forms.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Use B-tree for most things; GIN for full-text and JSONB; GiST for ranges and geometry.

**Intermediate view**: GIN has a pending list that batches writes — good for bulk insert workloads. BRIN is tiny but only works for sorted data. Choose the operator class that matches your query operators.

**Advanced view**: GIN's posting list compression and pending list merge semantics determine write amplification. GiST's penalty/picksplit functions determine tree quality — poor operator class implementations cause tree imbalance and slow queries. BRIN's effectiveness is entirely determined by physical heap correlation: measure with `pg_stats.correlation` before deciding. SP-GiST's non-overlapping partitions give asymptotically better performance for specific data distributions, but only operator classes for standard types are included in core PostgreSQL.

## Mental model
- **B-tree**: an alphabetically sorted filing cabinet. Great for finding a specific file or a range.
- **GIN**: a back-of-the-book index (word → page numbers). Perfect for "which pages mention word X?"
- **GiST**: a city map with bounding boxes for neighborhoods. "Does any neighborhood overlap this area?" — check each box, visit matching ones.
- **BRIN**: a ledger with min/max per page range. "Is the value in this decade?" — skip entire chapters.
- **SP-GiST**: a tree that partitions the map into non-overlapping quadrants. Faster to locate a point because quadrants never overlap.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_indexes`, `pg_stat_user_indexes`, `pg_opclass`, `pg_am` (access methods).

**SQL view**:
```sql
-- blocked: Docker not accessible
-- List all non-btree indexes
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE indexdef ILIKE '%USING gin%'
   OR indexdef ILIKE '%USING gist%'
   OR indexdef ILIKE '%USING brin%'
   OR indexdef ILIKE '%USING spgist%';

-- Index usage stats
SELECT schemaname, relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Check GIN pending list size (requires pg_buffercache or vacuum)
SELECT relname, n_dead_tup FROM pg_stat_user_tables WHERE relname LIKE '%gin%';
```

**Non-SQL / hybrid view**: GIN index size vs B-tree on the same column can be compared with `pg_relation_size()`. For BRIN correlation validation: `SELECT correlation FROM pg_stats WHERE tablename = 'events' AND attname = 'created_at'`.

## Design principle
**Match the index type to the query shape**: The wrong index type is often worse than no index (storage cost with zero benefit). GIN for containment, GiST for range/spatial/KNN, BRIN for appended time-series, SP-GiST for prefix and spatial partitions. The right index type for the wrong operator class = zero index benefit.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: GIN `fastupdate = on` means queries against a pending-list-heavy GIN index can be slow (the pending list must be searched linearly). Under write bursts, the pending list can grow faster than autovacuum drains it. Monitor: `SELECT * FROM pg_stat_user_tables WHERE relname = '<gin_table>'` and track `n_dead_tup` as a proxy for pending list pressure.

**Creative**: Combine BRIN + partial B-tree for hybrid time-series: BRIN for the full historical data, a partial B-tree for the last 30 days (`WHERE created_at > now() - interval '30 days'`). This gives fast point lookups for recent data (which is queried most) while keeping historical index overhead near zero.

**Systems**: Index type selection is a system-level decision, not a per-query decision. Changing from B-tree to GIN on a large JSONB column requires a reindex (potentially hours), causes write amplification changes, and affects vacuum behavior. Index type migrations should be planned during low-traffic windows with REINDEX CONCURRENTLY.

## MCP and agent perspective
Agents using pgvector for semantic search are using an extension that registers a custom operator class on top of GiST (IVFFlat) or a custom AM (HNSW). Understanding GiST internals explains why pgvector IVFFlat has a "probes" parameter (how many GiST branches to search) and why HNSW is not GiST-based. Agents performing JSONB metadata filtering alongside vector search need GIN on the JSONB column and vector index on the embedding column — two separate indexes, with the planner combining them via BitmapAnd.

## Ontology perspective
Each index type embodies a different theory of similarity and retrieval:
- B-tree: total order (linear similarity)
- GIN: set membership (boolean similarity)
- GiST: geometric containment and overlap (spatial similarity)
- BRIN: range proximity (temporal locality)
- SP-GiST: hierarchical space partition (recursive similarity)

Choosing an index type is choosing a retrieval ontology — the implicit definition of "closeness" used to find relevant data.

## Practice session

**Exercise 1 — GIN full-text search**: Create and use a GIN index for FTS.
```sql
-- blocked: Docker not accessible
CREATE TABLE docs (id serial, body text);
CREATE INDEX idx_docs_gin ON docs USING GIN (to_tsvector('english', body));
EXPLAIN SELECT * FROM docs WHERE to_tsvector('english', body) @@ plainto_tsquery('postgres indexing');
```

**Exercise 2 — GIN JSONB**: Compare jsonb_ops vs jsonb_path_ops index size.
```sql
-- blocked: Docker not accessible
CREATE INDEX idx_meta_ops ON events USING GIN (metadata);
CREATE INDEX idx_meta_path ON events USING GIN (metadata jsonb_path_ops);
SELECT pg_size_pretty(pg_relation_size('idx_meta_ops')),
       pg_size_pretty(pg_relation_size('idx_meta_path'));
```

**Exercise 3 — BRIN correlation check**: Verify correlation before creating BRIN.
```sql
-- blocked: Docker not accessible
SELECT attname, correlation FROM pg_stats WHERE tablename = 'events' AND attname = 'created_at';
-- If correlation > 0.9, BRIN is effective
CREATE INDEX IF NOT EXISTS idx_events_brin ON events USING BRIN (created_at);
```

**Exercise 4 — GiST range overlap**: Index and query tsrange columns.
```sql
-- blocked: Docker not accessible
CREATE TABLE reservations (id serial, room_id int, period tsrange);
CREATE INDEX idx_res_period ON reservations USING GIST (period);
EXPLAIN SELECT * FROM reservations WHERE period && '[2024-01-01, 2024-01-07)';
```

**Exercise 5 — Index usage audit**: Identify unused non-btree indexes.
```sql
-- blocked: Docker not accessible
SELECT schemaname, relname, indexrelname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY relname;
```

## References
- PostgreSQL Documentation: [Index Types](https://www.postgresql.org/docs/16/indexes-types.html)
- PostgreSQL Documentation: [GIN](https://www.postgresql.org/docs/16/gin.html)
- PostgreSQL Documentation: [GiST](https://www.postgresql.org/docs/16/gist.html)
- PostgreSQL Documentation: [BRIN](https://www.postgresql.org/docs/16/brin.html)
- PostgreSQL Documentation: [SP-GiST](https://www.postgresql.org/docs/16/spgist.html)
- Oleg Bartunov & Teodor Sigaev: [GIN and GiST Overview](https://www.sai.msu.su/~megera/postgres/gist/)
- Hironobu Suzuki: [The Internals of PostgreSQL, Chapter 9 — WAL and MVCC](https://www.interdb.jp/pg/)
