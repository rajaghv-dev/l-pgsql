# Query Design Principles

Principles for writing SQL queries that are correct, readable, performant, and maintainable.

---

## Principle 1: Filter as early as possible

### One-line rule
Apply WHERE clauses and JOINs on indexed columns first — the planner works better when it can eliminate rows early.

### Rationale
A query that joins two million-row tables and filters afterward processes far more data than one that filters before joining. Even when the planner reorders predicates, writing filter-first signals intent and reduces risk of accidental Cartesian products.

### Example (correct)
```sql
-- Filter before aggregating
SELECT o.user_id, sum(o.total)
FROM orders o
WHERE o.created_at >= now() - interval '30 days'
  AND o.status = 'paid'
GROUP BY o.user_id;
```

### Counter-example (incorrect)
```sql
-- Aggregate everything, then filter — wastes work
SELECT user_id, sum(total)
FROM orders
GROUP BY user_id
HAVING sum(total) > 100
-- No WHERE: scans all rows, including old/cancelled orders
```

### When this principle applies
All queries that touch large tables.

### When to break it (with justification)
HAVING is correct when filtering on aggregate results (e.g., `HAVING count(*) > 5`). This is not a violation — it is not a row-level filter.

### PostgreSQL implementation
Use `EXPLAIN (ANALYZE, BUFFERS)` to verify that filters are being applied at the table scan level, not after a join or sort.

---

## Principle 2: Never use SELECT * in application code

### One-line rule
Always name the columns you need — `SELECT *` is acceptable only in psql exploration sessions.

### Rationale
`SELECT *` returns columns added in future migrations that your application code does not expect. It also returns large columns (JSONB, text, bytea) that may be expensive to transfer and unnecessary for the query's purpose. Named columns make the query self-documenting.

### Example (correct)
```sql
SELECT id, email, created_at
FROM users
WHERE deleted_at IS NULL;
```

### Counter-example (incorrect)
```sql
SELECT * FROM users;  -- Returns all columns including large JSONB blobs, deleted users, etc.
```

### When to break it (with justification)
Exploratory queries in psql, quick one-off lookups, or when building a generic admin interface that intentionally displays all columns.

---

## Principle 3: Use RETURNING instead of re-querying after writes

### One-line rule
Use the `RETURNING` clause to get back the values you need from an INSERT, UPDATE, or DELETE — avoid a separate SELECT.

### Rationale
A SELECT after a write has a time gap where another transaction could modify the row. RETURNING is part of the same statement and returns the actual state of the row at the moment of the write.

### Example (correct)
```sql
-- Get the generated ID and defaults in one statement
INSERT INTO tasks (title, created_by)
VALUES ('Review schema', 42)
RETURNING id, created_at, status;

-- Know exactly which rows were deleted
DELETE FROM sessions WHERE expires_at < now()
RETURNING id, user_id;
```

### Counter-example (incorrect)
```sql
INSERT INTO tasks (title) VALUES ('Review schema');
SELECT id FROM tasks WHERE title = 'Review schema';  -- Race condition, wrong row if duplicates
```

---

## Principle 4: Prefer set-based operations over row-by-row loops

### One-line rule
Write SQL that operates on all matching rows at once — avoid cursor loops and repeated single-row queries.

### Rationale
SQL is a set-based language. A single `UPDATE ... WHERE ...` that modifies 10,000 rows is far more efficient than 10,000 individual `UPDATE ... WHERE id = $i` statements — it has one plan, one transaction (or fewer commits), and lets the executor optimize page access.

### Example (correct)
```sql
-- Set-based: one statement, one plan
UPDATE orders
SET status = 'archived'
WHERE created_at < now() - interval '2 years'
  AND status = 'paid';
```

### Counter-example (incorrect)
```sql
-- Row-by-row: N round trips, N plans, N individual writes
FOR order_id IN (SELECT id FROM orders WHERE created_at < now() - interval '2 years') LOOP
    UPDATE orders SET status = 'archived' WHERE id = order_id;
END LOOP;
```

### When to break it (with justification)
When each row requires different logic that cannot be expressed as a SQL expression. Use a PL/pgSQL function rather than application-level looping, so the logic stays close to the data.

---

## Principle 5: Use CTEs to express multi-step logic

### One-line rule
Break complex multi-step queries into named CTEs — each CTE should have a single responsibility with a descriptive name.

### Rationale
A deeply nested subquery is hard to read, test, and maintain. CTEs make each step explicit and named. In PostgreSQL 12+, CTEs are inlined by default, so readability comes at no performance cost in most cases.

### Example (correct)
```sql
WITH
active_users AS (
    SELECT id FROM users WHERE deleted_at IS NULL
),
recent_orders AS (
    SELECT user_id, sum(total) AS total_spent
    FROM orders
    WHERE created_at >= now() - interval '90 days'
    GROUP BY user_id
),
top_customers AS (
    SELECT u.id, r.total_spent
    FROM active_users u
    JOIN recent_orders r ON r.user_id = u.id
    WHERE r.total_spent > 500
)
SELECT * FROM top_customers ORDER BY total_spent DESC;
```

### Counter-example (incorrect)
```sql
-- Deeply nested, hard to trace which subquery does what
SELECT * FROM (
    SELECT u.id, r.total_spent
    FROM (SELECT id FROM users WHERE deleted_at IS NULL) u
    JOIN (SELECT user_id, sum(total) AS total_spent
          FROM orders WHERE created_at >= now() - interval '90 days'
          GROUP BY user_id) r ON r.user_id = u.id
    WHERE r.total_spent > 500
) t ORDER BY total_spent DESC;
```

---

## Principle 6: Test queries with realistic data volumes before deploying

### One-line rule
Never push a new query to production without testing it against a dataset of similar size and cardinality to production.

### Rationale
A query that takes 2ms on a 1,000-row dev table may take 30 seconds on a 50-million-row production table. Indexes that seem fine on small data may be ignored by the planner when table statistics differ.

### PostgreSQL implementation
```sql
-- On dev: set statistics targets to match production if you can't copy data
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500;
ANALYZE orders;
-- Or: use EXPLAIN with production's row estimates to simulate plan choice
SET enable_seqscan = off;  -- Force index usage to test index plan viability
EXPLAIN SELECT ...;
RESET enable_seqscan;
```

---

## Principle 7: Use LIMIT with ORDER BY — never assume query result order

### One-line rule
If result order matters, always specify ORDER BY; if you want the top N rows, always use LIMIT with ORDER BY.

### Rationale
PostgreSQL does not guarantee row order without ORDER BY. The physical storage order, parallel workers, or planner choices can all change result order between executions or after VACUUMs.

### Example (correct)
```sql
-- Deterministic: get the 10 most recent orders
SELECT id, total, created_at FROM orders
ORDER BY created_at DESC
LIMIT 10;
```

### Counter-example (incorrect)
```sql
SELECT id, total FROM orders LIMIT 10;
-- Which 10? Undefined. Could be different rows each execution.
```
