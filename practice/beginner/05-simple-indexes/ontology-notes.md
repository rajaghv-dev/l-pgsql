# Ontology Notes: Simple Indexes

These notes map the concepts in this practice session to the broader PostgreSQL concept graph.

---

## Concept map

```
index (secondary data structure)
  ├── IS A: access path (alternative to sequential scan)
  ├── HAS: index type (access method)
  │     ├── B-tree (default) — sorted tree → binary search
  │     ├── GIN — inverted index → JSONB, arrays, FTS
  │     ├── GiST — generalized search tree → geometry, ranges
  │     └── Hash — equality only
  ├── HAS: scope
  │     ├── full index — all rows
  │     └── partial index — subset of rows (WHERE clause in definition)
  ├── HAS: column coverage
  │     ├── single-column
  │     └── composite (multi-column) — leftmost prefix rule applies
  └── REQUIRES: table (cannot exist without a base table)

query planner
  ├── IS A: cost-based optimizer
  ├── EVALUATES: access paths (Seq Scan, Index Scan, Bitmap Index Scan)
  ├── USES: statistics (pg_stats, pg_class.relpages)
  └── CHOOSES: lowest estimated cost plan

EXPLAIN
  ├── IS A: query plan display tool
  ├── SHOWS: plan tree, estimated cost, estimated rows
  └── ANALYZE variant: adds actual timing, actual rows
```

---

## Concept definitions

| Concept | Definition | Parent concept | Child concepts |
|---------|-----------|----------------|----------------|
| index | Secondary data structure mapping values to row locations | access path | B-tree, GIN, GiST, partial, composite |
| B-tree index | Balanced tree keeping values sorted; supports range + equality | index | — |
| partial index | Index covering only rows matching a WHERE condition | index | — |
| composite index | Index on multiple columns; leftmost prefix rule applies | index | — |
| sequential scan | Read every row in table order — O(n) | access path | — |
| index scan | Navigate index to find matching rows — O(log n) | access path | — |
| EXPLAIN | Display query plan without executing | query tool | EXPLAIN ANALYZE |
| selectivity | Fraction of rows a condition matches; high = index useful | statistics | — |
| cardinality | Number of distinct values in a column | statistics | — |

---

## Key relationships

- **Index REQUIRES** a table — dropping the table drops the index.
- **Index IS MAINTAINED BY** PostgreSQL automatically on INSERT/UPDATE/DELETE.
- **B-tree CONTRASTS WITH** Hash index: B-tree supports ranges; Hash supports only equality.
- **Partial index CONTRASTS WITH** full index: partial is smaller and faster for targeted queries.
- **Composite index REQUIRES** leftmost prefix in WHERE for efficient use.
- **Query planner CHOOSES BETWEEN** access paths based on estimated cost (selectivity × table size).
- **High cardinality ENABLES** effective index use (many distinct values = selective queries).
- **Low cardinality CONTRASTS WITH** high cardinality: few distinct values = low selectivity = index often skipped.

---

## Obsidian graph links

- `[[index]]`
- `[[b-tree-index]]`
- `[[partial-index]]`
- `[[composite-index]]`
- `[[sequential-scan]]`
- `[[index-scan]]`
- `[[explain]]`
- `[[query-planner]]`
- `[[selectivity]]`
- `[[cardinality]]`
- `[[access-path]]`

---

## Questions for deeper concept mapping

1. Is an index a relation? (No — it is a secondary structure. But it IS a database object tracked in pg_class.)
2. What concept is logically upstream of an index? (The column(s) being indexed and the queries that would use it.)
3. What concepts does an index make possible downstream? (Efficient JOINs, fast ORDER BY, covering scans, unique constraints.)
