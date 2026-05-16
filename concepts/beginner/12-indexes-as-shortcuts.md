# Indexes as Shortcuts

Level: Beginner

## One-line intuition

An index is like the index at the back of a book — instead of reading every page, you jump directly to the right page.

## Why this exists

Without an index, PostgreSQL reads every row in a table to find matching rows (sequential scan). On a table with 10 million rows, this is slow. An index creates a separate data structure that maps column values to row locations, allowing direct lookup.

## First-principles explanation

The default index type in PostgreSQL is a **B-tree** (balanced tree). A B-tree keeps values sorted and allows binary search: instead of scanning n rows, it scans log₂(n) levels of the tree. For 1,000,000 rows, that is ~20 comparisons instead of 1,000,000.

```
Without index: scan all 1,000,000 rows → O(n)
With B-tree:   navigate ~20 tree levels → O(log n)
```

The trade-off: indexes take disk space and slow down INSERT/UPDATE/DELETE because the index must be updated alongside the table.

## Micro-concepts

| Concept | Meaning |
|---------|---------|
| Sequential scan (Seq Scan) | Read every row — used when no index helps |
| Index scan | Use index to find matching rows |
| Bitmap index scan | Used for low-selectivity queries (many matching rows) |
| B-tree index | Default — good for `=`, `<`, `>`, `BETWEEN`, `ORDER BY` |
| GIN index | Good for arrays, JSONB, full-text search |
| GiST index | Good for geometric data, ranges |
| Cardinality | Number of distinct values — high cardinality = index more useful |

## Beginner view

Book analogy:

- **No index**: to find all mentions of "PostgreSQL" in a 500-page book, read every page.
- **Back-of-book index**: look up "PostgreSQL" → pages 12, 47, 203, 399 → go directly to those pages.

The database index works the same way. The index entry says "value = 'Frank Herbert' → rows at locations 47, 203, 399."

## Intermediate view

**When to create an index:**
- Columns frequently in WHERE: `WHERE author_id = 7`
- Foreign key columns (PostgreSQL does not auto-index FKs — you must do it)
- Columns in ORDER BY on large tables
- Columns in JOIN ON conditions

**When NOT to:**
- Very small tables (< 1,000 rows) — sequential scan is faster (less overhead)
- Low-cardinality columns (e.g., `gender` with 2 values) — index is not selective enough
- Write-heavy tables where the INSERT/UPDATE overhead outweighs read gains
- Columns rarely used in WHERE

**Partial indexes** index only a subset of rows:

```sql
-- Index only active users (common query pattern)
CREATE INDEX idx_users_active ON users (email) WHERE active = true;
```

## Advanced view

- `EXPLAIN (ANALYZE, BUFFERS)` shows whether an index is used and how many buffers were read.
- **Index-only scans**: if all queried columns are in the index, PostgreSQL does not touch the main table at all (heap). Requires the visibility map to be current (VACUUM keeps it current).
- **Covering indexes**: `CREATE INDEX ... INCLUDE (col)` adds non-key columns to the index for index-only scans.
- **Concurrent index builds**: `CREATE INDEX CONCURRENTLY` avoids locking the table — safe for production.
- Bloat: indexes accumulate dead entries from updates/deletes. `REINDEX CONCURRENTLY` rebuilds without downtime.

## Mental model

The index is a sorted lookup table maintained separately from the main table. For every row you insert, the database also inserts an entry into each index. For every lookup, the database checks the index first and uses it if it predicts a win.

## PostgreSQL view

```sql
-- See available index types
SELECT amname FROM pg_am;

-- Create a basic B-tree index
CREATE INDEX idx_books_author_id ON books (author_id);

-- Create a partial index
CREATE INDEX idx_checkouts_active ON checkouts (patron_id)
WHERE returned_at IS NULL;

-- Check query plan
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM books WHERE author_id = 7;

-- List all indexes on a table
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'books';
```

## SQL view

```sql
-- Without index: Seq Scan on products (cost=0.00..2137.00 rows=10 ...)
-- With index:    Index Scan using idx_products_sku on products ...

CREATE INDEX idx_products_sku ON products (sku);
CREATE INDEX idx_products_price ON products (price DESC);

-- Composite index (order matters — leftmost prefix rule)
CREATE INDEX idx_books_author_year ON books (author_id, published_year);
-- Useful for: WHERE author_id = 7 AND published_year > 2000
-- Also useful for: WHERE author_id = 7 (leftmost prefix)
-- NOT useful for: WHERE published_year > 2000 alone
```

## Non-SQL or hybrid view

In a hash map (Python dict), lookup is O(1). A database hash index gives similar O(1) equality lookup but does not support range queries. B-tree supports both range and equality, making it the default choice.

## Design principle

**Index for your queries, not your columns.** Look at the WHERE clauses in your top-10 slowest queries. Those are the columns to index. Do not pre-emptively index every column.

## Critical thinking

- Adding 5 indexes to a write-heavy table (e.g., an event log) can make INSERTs 5x slower. Measure before indexing.
- An index on `(a, b)` does not help a query that only filters on `b`. The leftmost prefix must be used. This is a frequent misconception.

## Creative thinking

Expression indexes let you index computed values:

```sql
-- Index on lowercase email to support case-insensitive lookup
CREATE INDEX idx_users_email_lower ON users (LOWER(email));

-- Query must match the expression exactly
SELECT * FROM users WHERE LOWER(email) = 'test@example.com';
```

## Systems thinking

Indexes are a form of **pre-computation** — you pay the cost at write time to save it at read time. This is the same trade-off as caches, materialized views, and denormalization. In read-heavy systems, indexes are almost always worth it. In write-heavy systems (e.g., IoT time-series), they may be a bottleneck.

## MCP and agent perspective

Agents generating dynamic queries should include a query-plan check: before running user-generated SQL on a production table, call `EXPLAIN` and reject queries with estimated cost > threshold or with Seq Scan on large tables. This prevents runaway reads.

## Ontology perspective

- An index is a **secondary data structure** — it derives from the primary data (the table rows) and is automatically maintained.
- Indexes are **access paths** — they represent possible ways to reach a row.
- The query planner is an **optimizer** that selects among available access paths.
- A table with no indexes has exactly one access path: sequential scan.

## Practice session

`practice/beginner/05-simple-indexes/` — exercises create a large products table, run EXPLAIN before and after adding an index, and compare query plans.

## References

| Resource | URL | Why |
|----------|-----|-----|
| PostgreSQL docs — Indexes | https://www.postgresql.org/docs/current/indexes.html | Index types, creation, EXPLAIN |
| PostgreSQL docs — EXPLAIN | https://www.postgresql.org/docs/current/sql-explain.html | Reading query plans |
| Use The Index, Luke | https://use-the-index-luke.com/ | Entire free book on SQL indexing |
| PostgreSQL docs — CREATE INDEX | https://www.postgresql.org/docs/current/sql-createindex.html | Full syntax reference |
