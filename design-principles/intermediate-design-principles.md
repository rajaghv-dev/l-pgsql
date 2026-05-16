# Intermediate Design Principles

Ten principles for developers comfortable with SQL who are building production schemas and writing queries that need to be correct and fast.

---

## Principle 1: Normalize until it hurts, then denormalize with intention

### One-line rule
Start with a fully normalized schema; only denormalize specific columns when you have a measured performance problem.

### Rationale
Normalization eliminates data duplication and prevents update anomalies. Premature denormalization creates data synchronization bugs that are hard to find and expensive to fix. Denormalization is a trade-off, not a shortcut.

### Example (correct)
```sql
-- Normalized
CREATE TABLE orders (
    id      bigserial PRIMARY KEY,
    user_id bigint REFERENCES users(id)
);

-- Later: query shows expensive join on 10M rows
-- Intentional denormalization with a trigger to keep it fresh:
ALTER TABLE orders ADD COLUMN user_email text;
CREATE TRIGGER sync_user_email
    AFTER UPDATE OF email ON users
    FOR EACH ROW EXECUTE FUNCTION update_order_user_email();
```

### Counter-example (incorrect)
```sql
-- Premature denormalization without measuring
CREATE TABLE orders (
    id         bigserial PRIMARY KEY,
    user_id    bigint,
    user_email text,   -- duplicated; gets stale when user changes email
    user_name  text    -- duplicated; which name? at order time or current?
);
```

### When this principle applies
All new schema design work.

### When to break it (with justification)
Read-heavy analytics tables, materialized views, and reporting denormalization are valid. Document what the denormalized field represents (value at time of event vs current value).

### PostgreSQL implementation
Use materialized views, generated columns, or triggers to keep denormalized columns consistent.

### Related principles
[[schema-design-principles]]

---

## Principle 2: Prefer CHECK constraints to application-layer validation

### One-line rule
Encode business invariants as CHECK constraints in the schema — do not rely only on application code to enforce them.

### Rationale
Application validation can be bypassed: direct psql access, migrations, batch scripts, other services. A CHECK constraint is enforced by the database engine for every write path without exception.

### Example (correct)
```sql
CREATE TABLE orders (
    total  numeric(12,2) NOT NULL CHECK (total > 0),
    status text NOT NULL CHECK (status IN ('pending', 'paid', 'cancelled', 'refunded'))
);
```

### Counter-example (incorrect)
```sql
CREATE TABLE orders (
    total  numeric(12,2),  -- Application validates total > 0, but db does not
    status text            -- Application validates status, but db does not
);
```

### When to break it (with justification)
Complex cross-table invariants (e.g., "total must equal sum of line items") cannot be expressed as a single CHECK constraint. Use triggers or enforce in a transaction with explicit verification.

### PostgreSQL implementation
Named CHECK constraints are easier to maintain:
```sql
CONSTRAINT positive_total CHECK (total > 0),
CONSTRAINT valid_status CHECK (status IN ('pending', 'paid', 'cancelled'))
```

### Agent/MCP implications
Agents that generate SQL for inserts should not assume application validation will run. The constraint is the last line of defense.

---

## Principle 3: Create indexes for every foreign key column

### One-line rule
After every `REFERENCES` clause, create an index on the referencing column.

### Rationale
PostgreSQL does NOT automatically create indexes on foreign key columns. When you delete a parent row, PostgreSQL must scan the child table to check for referencing rows — without an index, this is a sequential scan on every delete. Joins on FK columns are also unindexed by default.

### Example (correct)
```sql
CREATE TABLE orders (
    id      bigserial PRIMARY KEY,
    user_id bigint NOT NULL REFERENCES users(id)
);
CREATE INDEX ON orders (user_id);  -- Essential, not optional
```

### Counter-example (incorrect)
```sql
CREATE TABLE orders (
    user_id bigint REFERENCES users(id)
    -- No index: DELETE FROM users WHERE id=42 does a seq scan on orders
);
```

### When to break it (with justification)
A partial index covering a subset of FK values is acceptable if the FK column has low cardinality or most rows share the same FK value.

### PostgreSQL implementation
```sql
-- Find FK columns without indexes
SELECT conrelid::regclass AS table, a.attname AS column
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
WHERE c.contype = 'f'
AND NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = c.conrelid AND a.attnum = ANY(i.indkey)
);
```

---

## Principle 4: Use partial indexes for common query filters

### One-line rule
When most queries filter by a constant condition, add `WHERE` to the index rather than indexing all rows.

### Rationale
A partial index on `WHERE status = 'pending'` indexes only pending orders. If 1% of orders are pending, the index is 100x smaller, fits in memory better, and is faster to scan than a full index.

### Example (correct)
```sql
-- 99% of queries only look at active users
CREATE INDEX ON users (email) WHERE deleted_at IS NULL;

-- Queue: only pending jobs need fast lookup
CREATE INDEX ON jobs (created_at) WHERE status = 'pending';
```

### Counter-example (incorrect)
```sql
-- Full index on status=pending when 99% of rows have other statuses
CREATE INDEX ON orders (status);  -- Low selectivity, planner may skip it
```

### When to break it (with justification)
When the filter condition changes frequently, or when you need to support multiple filter values with one index.

---

## Principle 5: Use RETURNING instead of a separate SELECT after writes

### One-line rule
Use `RETURNING` to get values from inserted/updated rows — do not round-trip to the database.

### Rationale
A round-trip `INSERT ... then SELECT ... WHERE id = ?` has a race condition if another session modifies the row between the two statements. `RETURNING` is atomic.

### Example (correct)
```sql
INSERT INTO users (email, created_at)
VALUES ('alice@example.com', now())
RETURNING id, created_at;

UPDATE orders SET status = 'paid', paid_at = now()
WHERE id = 42
RETURNING id, status, paid_at;
```

### Counter-example (incorrect)
```sql
INSERT INTO users (email) VALUES ('alice@example.com');
SELECT id FROM users WHERE email = 'alice@example.com';  -- Race condition possible
```

---

## Principle 6: Use CTEs for readability, not assumed performance

### One-line rule
Write CTEs to make complex queries readable; verify with EXPLAIN that they do not prevent optimization.

### Rationale
In PostgreSQL 12+, CTEs are "inlined" by the planner by default — they are not optimization fences anymore. Writing a CTE does not guarantee a separate execution step. But in older versions (pre-12), CTEs were always materialized. Always verify with EXPLAIN.

### Example (correct)
```sql
-- Readable, and planner can optimize through the CTE
WITH active_users AS (
    SELECT id FROM users WHERE deleted_at IS NULL
)
SELECT o.* FROM orders o
JOIN active_users u ON u.id = o.user_id;
```

### When to break it (with justification)
Use `WITH ... AS MATERIALIZED (...)` when you explicitly want to force a CTE to execute once (e.g., when the subquery has side effects or you're tuning a specific plan).

---

## Principle 7: Use window functions instead of correlated subqueries for ranking

### One-line rule
Replace correlated subqueries that rank or number rows with window functions — they are faster and clearer.

### Rationale
Correlated subqueries execute once per row. Window functions execute once over a partition. For N rows, a correlated subquery is O(N²); a window function is O(N log N).

### Example (correct)
```sql
SELECT
    user_id,
    order_id,
    total,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rn
FROM orders;
```

### Counter-example (incorrect)
```sql
SELECT user_id, order_id, total,
    (SELECT count(*) FROM orders o2
     WHERE o2.user_id = o1.user_id AND o2.created_at >= o1.created_at) AS rn
FROM orders o1;  -- O(N²) — executes subquery for every row
```

---

## Principle 8: Understand which aggregate functions ignore NULL

### One-line rule
Before using COUNT, AVG, SUM on nullable columns, verify whether NULL exclusion is the intended behavior.

### Rationale
`AVG(score)` ignores NULL values — if 3 of 10 rows have NULL scores, the average is computed over 7 rows, not 10. This is correct in some contexts (e.g., "average of recorded scores") and wrong in others (e.g., "average participation rate").

### Example (correct)
```sql
-- Explicit about intent: count all rows vs count non-null values
SELECT
    count(*)          AS total_rows,
    count(score)      AS rows_with_score,
    avg(score)        AS avg_of_recorded_scores,
    avg(COALESCE(score, 0)) AS avg_treating_null_as_zero
FROM responses;
```

---

## Principle 9: Run ANALYZE after large data loads

### One-line rule
Run `ANALYZE table_name` after any bulk load that adds or changes more than ~10% of a table's rows.

### Rationale
The query planner uses statistics from `pg_statistic` to estimate row counts and choose plans. After a large load, stale statistics cause bad plan choices — the planner may underestimate rows and choose a nested-loop join over a hash join, causing 10x slowdowns.

### Example (correct)
```sql
COPY orders FROM '/tmp/orders.csv' CSV HEADER;
ANALYZE orders;  -- Refresh statistics immediately after load
```

### When to break it (with justification)
Autovacuum will eventually run ANALYZE automatically. If the load is small relative to table size, it is not urgent.

---

## Principle 10: Use domain types or CHECK constraints for format-validated strings

### One-line rule
When a text column has a specific format (email, phone, UUID, slug), enforce it with a CHECK constraint or a domain type.

### Rationale
`text` accepts anything. An email column that accepts `"not-an-email"` will cause application bugs that are hard to trace. Encoding format validation in the schema means every write path is covered.

### Example (correct)
```sql
-- Domain type (reusable across tables)
CREATE DOMAIN email_address AS text
    CHECK (VALUE ~ '^[^@]+@[^@]+\.[^@]+$');

CREATE TABLE users (
    email email_address NOT NULL UNIQUE
);

-- Or inline CHECK:
CREATE TABLE users (
    email text NOT NULL UNIQUE CHECK (email ~ '^[^@]+@[^@]+\.[^@]+$')
);
```

### Counter-example (incorrect)
```sql
CREATE TABLE users (
    email text  -- Accepts 'not-valid', 'noemail', '', NULL
);
```

### PostgreSQL implementation
Domain types promote reuse and make ALTER easier — change the domain once and it applies to all columns of that domain type.
