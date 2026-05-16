# Composite, Partial, and Expression Indexes
Level: Intermediate

## One-line intuition
Composite indexes answer multi-column filters in one lookup; partial indexes shrink the index to only relevant rows; expression indexes let you index computed values so queries don't have to recompute them.

## Why this exists
A simple single-column B-tree index is a starting point, not an endpoint. Real queries filter on multiple columns, apply functions to columns, or operate only on a specific subset of rows. These three index techniques let you match the index precisely to the query.

## First-principles explanation
Every index is a sorted data structure mapping values to row locations. Each technique extends this:

- **Composite**: sort by multiple columns simultaneously. The leading column determines range applicability; each subsequent column narrows within that range.
- **Partial**: add a WHERE clause to the index — only rows satisfying the condition are indexed. Smaller, faster, more targeted.
- **Expression**: index a function of a column instead of the raw column. Queries using that function can use the index; queries using the raw column cannot.

The INCLUDE clause adds a fourth tool: **covering index** — non-key columns stored in the index leaf pages so the planner can answer a query from the index alone without touching the heap.

## Micro-concepts
| Technique | When to use | Key behavior |
|---|---|---|
| Composite | WHERE has 2+ columns; multi-column ORDER BY | Leftmost prefix rule: only queries using the leading column(s) benefit |
| Partial | Many queries always filter by the same condition | Index is smaller; updates outside the condition don't update the index |
| Expression | WHERE applies a function to a column | Query must use the identical expression; raw column queries skip the index |
| INCLUDE (covering) | SELECT retrieves a few additional columns beyond the index key | Enables index-only scan; INCLUDE columns are not searchable |

## Beginner view
```sql
-- Composite: find orders by customer, sorted by date
CREATE INDEX ON orders (customer_id, ordered_at DESC);
-- Supports: WHERE customer_id = 42 ORDER BY ordered_at DESC  ✓
-- Does NOT support: WHERE ordered_at > '2026-01-01' alone    ✗ (not the leading column)

-- Partial: only index active orders (pending/confirmed are "active")
CREATE INDEX ON orders (ordered_at) WHERE status IN ('pending','confirmed');
-- Supports: WHERE status IN ('pending','confirmed') AND ordered_at > '2026-01-01' ✓
-- Index is much smaller than a full index on ordered_at

-- Expression: case-insensitive email lookup
CREATE INDEX ON customers (LOWER(email));
-- Supports: WHERE LOWER(email) = LOWER('Alice@Example.com')  ✓
-- Does NOT support: WHERE email = 'alice@example.com'         ✗
```

## Intermediate view
**Composite index — leftmost prefix rule**: A composite index on `(a, b, c)` supports queries filtering on:
- `a` only ✓
- `a, b` ✓
- `a, b, c` ✓
- `b` only ✗ (a is not constrained)
- `b, c` ✗

Exception: if `a` is bound by an equality condition (`a = 5`), the planner can use `b` range. But a range on `a` (`a > 5`) generally blocks index use for `b`.

```sql
-- Index: (customer_id, ordered_at)
-- Query 1: WHERE customer_id = 42 AND ordered_at > '2026-01-01'  → index used ✓
-- Query 2: WHERE customer_id = 42                                  → index used ✓ (partial prefix)
-- Query 3: WHERE ordered_at > '2026-01-01'                        → index NOT used ✗
```

**Partial index use cases**:
- Active records: `WHERE deleted_at IS NULL` (most queries only need active rows)
- Recent data: `WHERE created_at > '2026-01-01'` (hot data)
- Specific status: `WHERE status = 'pending'` (dashboards showing pending items)

```sql
-- Index only pending orders — far smaller than indexing all orders
CREATE INDEX orders_pending_date_idx
    ON orders (ordered_at DESC)
    WHERE status = 'pending';
```

**Expression index — important rule**: The query must use the **exact same expression**, including function name, argument order, and type casts.
```sql
-- Index on LOWER(email)
CREATE INDEX ON customers (LOWER(email));
-- Matches: WHERE LOWER(email) = 'alice@example.com'     ✓
-- Does NOT match: WHERE email ILIKE 'alice@example.com'  ✗ (different expression)
-- Fix: use the LOWER() expression in the query
```

Common expression index patterns:
```sql
-- Date trunc (group by day)
CREATE INDEX ON events (DATE_TRUNC('day', occurred_at));

-- Computed hash (if you store a hash and query by it)
CREATE INDEX ON sessions (MD5(token));

-- JSONB key extraction
CREATE INDEX ON products ((attrs->>'color'));
-- Query: WHERE attrs->>'color' = 'black'
```

**Covering index (INCLUDE)**:
```sql
-- Query: SELECT status, ordered_at FROM orders WHERE customer_id = 42
-- Without INCLUDE: index scan → heap fetch to get status and ordered_at
-- With INCLUDE: index-only scan — status and ordered_at are in the index leaf
CREATE INDEX ON orders (customer_id)
    INCLUDE (status, ordered_at);
```
INCLUDE columns are stored in the index but not used for ordering or range searches. They reduce heap fetches for frequently accessed columns.

## Advanced view
**Index-only scan**: When all columns needed by a query are in the index (either as key or INCLUDE columns) AND the visibility map shows the page is all-visible, PostgreSQL skips the heap entirely. This can be dramatically faster for large tables.

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, status FROM orders WHERE customer_id = 42;
-- With INCLUDE (status): "Index Only Scan" — no heap reads (Buffers: shared hit=N)
-- Without INCLUDE:       "Index Scan"       — heap reads for each matched row
```

**Partial composite expression index** — combining all three:
```sql
-- Find active customers by lowercase email, index only non-deleted rows
CREATE UNIQUE INDEX active_customers_lower_email
    ON customers (LOWER(email))
    WHERE deleted_at IS NULL;
```
This is the most precise possible index for: `WHERE LOWER(email) = '...' AND deleted_at IS NULL`.

**Function immutability requirement**: Expression indexes require the function to be `IMMUTABLE` (same input → same output always). `now()`, `random()`, `current_user` are not immutable and cannot be indexed.

## Mental model
- **Composite**: A filing cabinet with primary tabs (customer) and secondary tabs (date). You can jump to customer 42's section and then to a date range within it. But if you only know the date, you have to check every customer's section.
- **Partial**: A filing cabinet with only the pending orders — smaller, faster to search, and inserts of non-pending orders don't touch it.
- **Expression**: A filing cabinet where the label is the lowercase version of the original. Queries using LOWER() find the right drawer; queries using the original case do not.
- **INCLUDE**: A filing cabinet where the tab also has a summary card (status, date) stapled to it — you never need to open the full file just to read those fields.

## PostgreSQL view
```sql
-- Check if a query uses a specific index
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM customers WHERE LOWER(email) = 'alice@example.com';

-- List all non-default indexes (expression, partial)
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'customers'
  AND indexdef LIKE '%WHERE%' OR indexdef LIKE '%lower%';

-- Index-only scan check: visibility map must be populated
SELECT relname, n_live_tup, n_dead_tup
FROM pg_stat_user_tables WHERE relname = 'orders';
-- Run VACUUM to update visibility map if n_dead_tup is high
VACUUM orders;
```

## SQL view
```sql
-- Composite
CREATE INDEX ON orders (customer_id, ordered_at DESC);

-- Partial
CREATE INDEX ON orders (ordered_at DESC) WHERE status = 'pending';

-- Expression
CREATE INDEX ON customers (LOWER(email));

-- Combined: partial expression index
CREATE UNIQUE INDEX ON customers (LOWER(email)) WHERE deleted_at IS NULL;

-- Covering
CREATE INDEX ON orders (customer_id) INCLUDE (status, ordered_at);

-- JSONB key expression index
CREATE INDEX ON products ((attrs->>'color'));

-- validation: blocked — Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled
```

## Non-SQL or hybrid view
- **MySQL**: Supports prefix indexes on long strings and expression indexes (since 8.0). No INCLUDE clause (covering indexes are done differently via composite indexes with all needed columns as key columns).
- **MongoDB**: Sparse indexes (equivalent to partial) and expression indexes (computed fields). No INCLUDE equivalent.
- **Elasticsearch**: All fields are inverted-indexed by default. "Covering" is less relevant because the entire document is stored.

## Design principle
**Index what the query sees, not what the table stores.** If your application always queries `LOWER(email)`, index `LOWER(email)`. If it always filters by `status = 'active'`, make that a partial index condition. The index should match the query's view of the data, not the schema's view.

## Critical thinking
- Every composite, partial, or expression index is a maintenance commitment. Document why each index exists; indexes without documented rationale accumulate and become "is this still used?" debt.
- INCLUDE columns increase index size. Large INCLUDE sets on wide tables can make the index larger than useful. Profile with `pg_stat_user_indexes`.
- Expression indexes require function stability: if the indexed expression changes meaning (e.g., a CAST changes behavior after a PostgreSQL upgrade), the index may silently become incorrect. REINDEX after major upgrades.

## Creative thinking
- A partial index on `WHERE status != 'archived'` effectively creates a "live data" index without changing your schema. This is more efficient than a partial index on `WHERE status = 'active'` if there are many non-archived statuses.
- Expression indexes on JSONB keys turn a schemaless column into something that behaves like a typed column for query performance — the best of both worlds.

## Systems thinking
Indexes interact with autovacuum: partial indexes covering only recent data are vacuumed more frequently (more dead tuples from updates to hot rows). Monitor `pg_stat_user_indexes.idx_scan` over time — an index that was useful at 10k rows may be unnecessary at 10M if query patterns shift.

## MCP and agent perspective
Agents generating queries against a partially-indexed table need to include the partial index condition in their WHERE clause to benefit from the index. If an agent generates `WHERE email = '...'` instead of `WHERE LOWER(email) = LOWER('...')`, it misses the expression index. Schema documentation should explicitly record what expression each index expects.

## Ontology perspective
A composite index materializes a joint ordering of multiple dimensions — a multi-dimensional access path. A partial index materializes access paths only within a sub-domain (the rows matching the WHERE clause). An expression index materializes a transformation of the data domain into a derived property domain. These are all forms of pre-computed intensional structure imposed on extensional data.

## Practice session
See `practice/intermediate/02-indexing-strategies/` for hands-on exercises with EXPLAIN ANALYZE comparing query plans with and without each index type.

## References
- PostgreSQL docs — Indexes: https://www.postgresql.org/docs/16/indexes.html
- PostgreSQL docs — Multicolumn indexes: https://www.postgresql.org/docs/16/indexes-multicolumn.html
- PostgreSQL docs — Partial indexes: https://www.postgresql.org/docs/16/indexes-partial.html
- PostgreSQL docs — Expression indexes: https://www.postgresql.org/docs/16/indexes-expressional.html
- PostgreSQL docs — Index-only scans and INCLUDE: https://www.postgresql.org/docs/16/indexes-index-only-scans.html
- Use The Index, Luke — Composite indexes: https://use-the-index-luke.com/sql/where-clause/the-equals-operator/concatenated-keys
- Use The Index, Luke — Partial indexes: https://use-the-index-luke.com/sql/where-clause/partial-and-filtered-indexes
