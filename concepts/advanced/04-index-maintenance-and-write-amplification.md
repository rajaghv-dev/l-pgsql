# Index Maintenance and Write Amplification

Level: Advanced

## One-line intuition
Every index you add makes reads faster and writes slower — and the cost of maintaining indexes is invisible until your write throughput collapses or your table is drowning in bloat.

## Why this exists
Indexes are not free. Every `INSERT`, `UPDATE`, and `DELETE` must update every index on the table. Deleted tuples leave dead index entries. Index pages fragment over time. Understanding write amplification and index bloat — and knowing how to measure and repair both — is essential for sustainable production schemas.

## First-principles explanation

### Write amplification defined
Write amplification ratio = (bytes written to storage) / (bytes of logical data changed).

For a table with N indexes:
- 1 heap page write (the data)
- N index page writes (one per index, potentially more for page splits)
- 1 WAL record per modified page

A table with 10 indexes on a write-heavy column experiences 10x+ write amplification. This becomes visible as:
- High `wal_bytes` in `pg_stat_wal`
- High I/O wait in `pg_stat_activity`
- Slow INSERT throughput under load

### Index bloat from dead tuples
PostgreSQL's MVCC model means `UPDATE` and `DELETE` do not immediately remove old index entries. The old heap tuple is marked dead, but the index still has a pointer to it. The index entry is only removed when:
1. VACUUM runs on the table
2. The index entry is found to point to a dead heap tuple
3. The index page is updated to remove the dead entry

In high-churn tables, dead index entries accumulate between VACUUM runs, causing:
- Index pages that are mostly dead entries (fragmented)
- Larger index than necessary
- Slower index scans (more pages to traverse)

### Measuring index bloat
The canonical bloat query uses `pgstattuple` extension (or a statistical approximation via `pg_stats`):

```sql
-- blocked: Docker not accessible
-- Requires pgstattuple extension (must be superuser or pg_stat_scan_tables member)
CREATE EXTENSION IF NOT EXISTS pgstattuple;

SELECT * FROM pgstattuple('idx_orders_customer_id');
-- Returns: table_len, tuple_count, tuple_len, dead_tuple_count, dead_tuple_len, free_space

SELECT pgstatindex('idx_orders_customer_id');
-- Returns: version, tree_level, index_size, root_block_no, internal_pages, leaf_pages,
--          empty_pages, deleted_pages, avg_leaf_density, leaf_fragmentation
```

A healthy B-tree has `avg_leaf_density` above 70% and `leaf_fragmentation` below 30%.

### Index-to-row-count ratio as a health signal
```sql
-- blocked: Docker not accessible
SELECT
    t.relname AS table_name,
    ix.relname AS index_name,
    pg_size_pretty(pg_relation_size(ix.oid)) AS index_size,
    pg_size_pretty(pg_relation_size(t.oid)) AS table_size,
    round(pg_relation_size(ix.oid)::numeric / nullif(pg_relation_size(t.oid), 0) * 100, 1) AS index_pct
FROM pg_class t
JOIN pg_index i ON i.indrelid = t.oid
JOIN pg_class ix ON ix.oid = i.indexrelid
WHERE t.relkind = 'r'
ORDER BY pg_relation_size(ix.oid) DESC;
```

An index larger than its table (index_pct > 100%) is a warning sign for bloat or over-indexing.

### REINDEX CONCURRENTLY
Rebuilds an index without taking a table-level lock. Safe for production:
```sql
-- blocked: Docker not accessible
REINDEX INDEX CONCURRENTLY idx_orders_customer_id;
REINDEX TABLE CONCURRENTLY orders;  -- rebuilds all indexes on the table
```

Limitations:
- Cannot be run inside a transaction block
- Takes an exclusive lock at the start and end (brief), not during the build
- Requires extra disk space during build (old + new index coexist)
- If it fails, leaves an `INVALID` index behind (clean up with `DROP INDEX`)

### Identifying unused indexes
```sql
-- blocked: Docker not accessible
SELECT schemaname, relname, indexrelname, idx_scan,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan < 50
ORDER BY pg_relation_size(indexrelid) DESC;
```

Indexes with `idx_scan = 0` and large size are candidates for removal. Always check:
- Is this a UNIQUE constraint (enforced structurally, not by scans)?
- Is this table queried rarely by design?
- Has the server been restarted recently (stats reset on restart)?

### Index maintenance strategies

| Problem | Solution |
|---|---|
| Index bloat | `REINDEX CONCURRENTLY` |
| Unused index | `DROP INDEX CONCURRENTLY` |
| Fragmented GIN pending list | `VACUUM` the table (triggers GIN cleanup) |
| All indexes on write-heavy table slow | Reconsider schema: fewer partial indexes, partial indexes |
| Index build blocks production | `CREATE INDEX CONCURRENTLY` |

### Covering indexes to reduce write amplification
A covering index (`INCLUDE`) allows index-only scans without fetching the heap, reducing read I/O. But it also increases the index size and write amplification (the included columns must be maintained).

```sql
-- blocked: Docker not accessible
-- Covering index: avoids heap fetch for common query pattern
CREATE INDEX idx_orders_covering ON orders (customer_id) INCLUDE (status, total_amount);
```

Use sparingly: add `INCLUDE` only when the columns are frequently projected in index-eligible queries.

### Partial indexes
The single best tool for reducing write amplification on selective data:
```sql
-- blocked: Docker not accessible
-- Only index pending orders — 1% of rows, 100% of the query load
CREATE INDEX idx_orders_pending ON orders (created_at)
WHERE status = 'pending';
```

Write amplification applies only to INSERTs/UPDATEs that match the WHERE clause. The index is smaller, faster, and maintained less often.

## Micro-concepts
- **index split**: when a B-tree leaf page is full, it splits into two pages. Creates overhead and can cascade up the tree.
- **fillfactor**: the target fullness for leaf pages (default 70% for indexes, 100% for tables). Lower fillfactor leaves room for updates in-place, reducing splits. `CREATE INDEX ... WITH (fillfactor=80)`.
- **INVALID index**: left by a failed `CREATE INDEX CONCURRENTLY` or `REINDEX CONCURRENTLY`. Drop it before retrying.
- **pg_stat_user_indexes**: key fields: `idx_scan` (total scans using this index), `idx_tup_read` (tuples read from index), `idx_tup_fetch` (tuples fetched from heap via this index).
- **HOT update**: Heap Only Tuple update — when an update changes only non-indexed columns, PostgreSQL creates a HOT chain in the same heap page, avoiding index update entirely. HOT requires `fillfactor < 100` on the table to leave room.
- **index-only scan**: the executor satisfies the query entirely from index data, without touching the heap (provided the visibility map shows the heap page is all-visible). GIN/GiST do not support index-only scans.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Indexes speed up SELECT. They have a cost on writes. Don't add too many.

**Intermediate view**: Unused indexes waste space and slow writes. Bloated indexes waste space and slow reads. Run REINDEX to rebuild. Check pg_stat_user_indexes for usage.

**Advanced view**: Write amplification is multiplicative: N indexes × write frequency × WAL overhead. HOT updates are the mechanism that breaks the multiplication — they eliminate index writes for non-indexed column changes, but only when fillfactor allows in-place updates. GIN pending lists batch index updates but create read-time penalty. BRIN has near-zero write amplification but minimal selectivity. The optimal index set for a write-heavy table is a small number of carefully chosen partial indexes, with HOT-friendly fillfactor settings.

## Mental model
Each index is a carbon copy of part of your table that must be updated in lockstep with every change. Adding 10 indexes is like having 10 scribes who must each update their ledger every time a record changes. The table itself is the master ledger — scribes are the indexes. Dead tuple cleanup is erasing outdated entries from all scribes' ledgers. REINDEX CONCURRENTLY is replacing one scribe's ledger with a fresh copy while they keep working.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_stat_user_indexes`, `pg_indexes`, `pg_class` (for sizes), `pgstattuple` extension.

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Top 10 largest indexes with usage
SELECT
    i.relname AS index_name,
    t.relname AS table_name,
    pg_size_pretty(pg_relation_size(i.oid)) AS size,
    s.idx_scan,
    s.idx_tup_read
FROM pg_class i
JOIN pg_index ix ON ix.indexrelid = i.oid
JOIN pg_class t ON t.oid = ix.indrelid
LEFT JOIN pg_stat_user_indexes s ON s.indexrelid = i.oid
WHERE i.relkind = 'i'
ORDER BY pg_relation_size(i.oid) DESC
LIMIT 10;

-- HOT update rate (high = good, index not involved in updates)
SELECT relname, n_tup_upd, n_tup_hot_upd,
       round(n_tup_hot_upd::numeric / nullif(n_tup_upd, 0) * 100, 1) AS hot_pct
FROM pg_stat_user_tables
ORDER BY n_tup_upd DESC;
```

**Non-SQL / hybrid view**: `pg_dump --schema-only | grep CREATE INDEX` gives a full index inventory. Monitoring systems (Prometheus + postgres_exporter) can track `idx_scan` rates over time to detect index usage drift as query patterns change.

## Design principle
**Indexes are a write-time tax paid for read-time benefit**: the tax is invisible during development (low write volume) and catastrophic in production (high write volume). Audit indexes before going live. Remove any index that cannot be justified by a specific query. Use partial indexes to limit the taxed rows. Use covering indexes sparingly. Monitor HOT update rate as a health signal.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: `pg_stat_user_indexes.idx_scan = 0` does not mean the index is unused — it means it has not been used *since the last statistics reset* (which happens on server restart). Always check uptime and consider whether the index covers a rare but critical query (e.g., a monthly billing report).

**Creative**: You can use `pg_stat_user_indexes` as a feedback loop in CI. Run the full test suite, then assert that all production-critical indexes have `idx_scan > 0`. This catches index-query mismatches in the test environment before production.

**Systems**: Write amplification compounds with replication. Every write generates WAL. WAL replicates to standbys. Each standby re-applies every index update from WAL. A primary with 10 indexes and 5 standbys has effective write amplification of 10 × 5 = 50x at the storage layer. Index hygiene is a cluster-level concern, not just a primary-node concern.

## MCP and agent perspective
Agents that insert embeddings or metadata at high rates (e.g., bulk document ingestion) are subject to write amplification from GIN and vector indexes. Best practice: drop indexes before bulk inserts, insert, then rebuild with `CREATE INDEX CONCURRENTLY`. For incremental agent inserts, use GIN `fastupdate = on` to buffer writes into the pending list. Monitor `pg_stat_user_indexes.idx_tup_read` to confirm indexes are being used for retrieval.

## Ontology perspective
Index bloat is a form of information entropy accumulation — the index's representation of reality drifts from the actual data state as dead tuples pile up. VACUUM is a reconciliation process that aligns the index's representation back to reality. In information-theoretic terms, dead index entries are noise: they do not represent valid rows but consume space and lookup time. Write amplification is the systemic cost of maintaining consistency across multiple representations of the same data.

## Practice session

**Exercise 1 — Write amplification audit**: Count indexes per table and estimate amplification.
```sql
-- blocked: Docker not accessible
SELECT t.relname, count(i.indexrelid) AS index_count
FROM pg_class t
JOIN pg_index i ON i.indrelid = t.oid
WHERE t.relkind = 'r'
GROUP BY t.relname
ORDER BY index_count DESC;
```

**Exercise 2 — HOT update rate**: Find tables where updates are mostly HOT.
```sql
-- blocked: Docker not accessible
SELECT relname, n_tup_upd, n_tup_hot_upd,
       round(n_tup_hot_upd::numeric / nullif(n_tup_upd, 0) * 100, 1) AS hot_pct
FROM pg_stat_user_tables
WHERE n_tup_upd > 0
ORDER BY hot_pct;
```

**Exercise 3 — Index bloat estimate**: Use pgstattuple for a specific index.
```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS pgstattuple;
SELECT indexname, pgstatindex(indexname)
FROM pg_indexes
WHERE tablename = 'orders'
LIMIT 1;
```

**Exercise 4 — Find unused indexes**: Safe candidates for removal.
```sql
-- blocked: Docker not accessible
SELECT schemaname, relname, indexrelname, idx_scan,
       pg_size_pretty(pg_relation_size(indexrelid)) AS wasted_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND NOT EXISTS (
    SELECT 1 FROM pg_constraint c WHERE c.conindid = indexrelid
  )
ORDER BY pg_relation_size(indexrelid) DESC;
```

**Exercise 5 — Partial index benefit**: Compare index sizes for full vs partial.
```sql
-- blocked: Docker not accessible
CREATE INDEX idx_full ON orders (customer_id);
CREATE INDEX idx_partial ON orders (customer_id) WHERE status = 'pending';
SELECT pg_size_pretty(pg_relation_size('idx_full')),
       pg_size_pretty(pg_relation_size('idx_partial'));
```

## References
- PostgreSQL Documentation: [REINDEX](https://www.postgresql.org/docs/16/sql-reindex.html)
- PostgreSQL Documentation: [pg_stat_user_indexes](https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ALL-INDEXES-VIEW)
- PostgreSQL Documentation: [HOT Updates](https://www.postgresql.org/docs/16/storage-hot.html)
- PostgreSQL Documentation: [Index Fillfactor](https://www.postgresql.org/docs/16/sql-createindex.html#SQL-CREATEINDEX-STORAGE-PARAMETERS)
- Alvaro Herrera: [Heap-Only Tuples](https://git.postgresql.org/gitweb/?p=postgresql.git;a=blob;f=src/backend/access/heap/README.HOT)
- pgstattuple: [Documentation](https://www.postgresql.org/docs/16/pgstattuple.html)
