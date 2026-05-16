# Views as Saved Questions

Level: Beginner

## One-line intuition

A view is a named SELECT statement stored in the database — you query it like a table, but it runs the underlying query every time.

## Why this exists

Complex queries get repeated. Views let you give a query a name, hide the complexity, and reuse it without copying SQL everywhere. They also control what callers can see (a form of access control).

## First-principles explanation

A view is not a table. It stores no data of its own (by default). It is a **macro** — the database expands the view definition into the query plan every time you SELECT from it. The result is always fresh (reflects the current state of the underlying tables).

```sql
CREATE VIEW available_books AS
SELECT b.id, b.title, a.name AS author
FROM books b
INNER JOIN authors a ON a.id = b.author_id
LEFT JOIN checkouts c ON c.book_id = b.id AND c.returned_at IS NULL
WHERE c.id IS NULL;

-- Querying the view is identical to querying the underlying SELECT
SELECT * FROM available_books WHERE author = 'Isaac Asimov';
```

## Micro-concepts

| Concept | Meaning |
|---------|---------|
| `CREATE VIEW name AS SELECT ...` | Define a view |
| `CREATE OR REPLACE VIEW` | Update a view definition (same columns must exist) |
| `DROP VIEW name` | Remove a view |
| Updatable view | A simple view that allows INSERT/UPDATE/DELETE through it |
| Materialized view | Stores query results physically — must be refreshed manually |
| `WITH CHECK OPTION` | Prevent inserts/updates that would make the row disappear from the view |

## Beginner view

Think of a view as a saved search on your phone — you saved the filter settings, and every time you open it, it runs the search fresh with current data. The search itself is not stored data; the results are always live.

```sql
-- Create once
CREATE VIEW overdue_checkouts AS
SELECT c.id, b.title, c.patron_id, c.checked_out_at
FROM checkouts c
INNER JOIN books b ON b.id = c.book_id
WHERE c.returned_at IS NULL
  AND c.checked_out_at < now() - INTERVAL '21 days';

-- Use anywhere, as if it were a table
SELECT * FROM overdue_checkouts WHERE patron_id = 42;
SELECT COUNT(*) FROM overdue_checkouts;
```

## Intermediate view

**Updatable views**: a view is automatically updatable if it:
- Selects from a single table (no JOINs)
- Has no DISTINCT, GROUP BY, HAVING, UNION, or aggregate functions
- Has no subqueries in the SELECT list

```sql
-- Simple updatable view
CREATE VIEW active_users AS
SELECT id, email, username FROM users WHERE active = true;

INSERT INTO active_users (email, username) VALUES ('bob@example.com', 'bob');
-- This works — the view is simple enough for PostgreSQL to route the INSERT
```

**WITH CHECK OPTION** ensures inserts/updates through a view stay visible in the view:

```sql
CREATE VIEW active_users AS
SELECT id, email, active FROM users WHERE active = true
WITH CHECK OPTION;

-- This will FAIL — the inserted row would not appear in the view
INSERT INTO active_users (email, active) VALUES ('x@example.com', false);
```

**`CREATE OR REPLACE VIEW`**: you can replace a view definition as long as the column list does not shrink (you can add columns, not remove them).

## Advanced view

- **Materialized views** (see note below) store results — faster for expensive queries but require explicit `REFRESH MATERIALIZED VIEW`.
- **SECURITY DEFINER views**: run with the view owner's permissions, not the caller's. Use to expose limited data to lower-privilege roles.
- The query planner can push predicates into views (predicate pushdown) — `SELECT * FROM view WHERE id = 7` can become efficient if the planner pushes the WHERE into the inner query.
- View dependencies: `DROP TABLE` that a view depends on will fail unless you use `CASCADE`. Check dependencies with `pg_depend`.

**Materialized views (brief)**:

```sql
CREATE MATERIALIZED VIEW monthly_stats AS
SELECT DATE_TRUNC('month', created_at) AS month, COUNT(*) AS signups
FROM users
GROUP BY 1;

-- Refresh when you want fresh data
REFRESH MATERIALIZED VIEW monthly_stats;

-- Refresh without locking reads
REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_stats;
```

Detail is covered in the intermediate stage.

## Mental model

A regular view is a **query alias** — identical to copying the SELECT into every query that uses it, except named and reusable. A materialized view is a **cache** — a snapshot stored on disk, valid until you refresh it.

## PostgreSQL view

```sql
-- Inspect a view's definition
SELECT definition FROM pg_views WHERE viewname = 'available_books';

-- Inspect dependencies
SELECT dependent_view.relname AS view_name
FROM pg_depend
JOIN pg_rewrite ON pg_rewrite.oid = pg_depend.objid
JOIN pg_class dependent_view ON dependent_view.oid = pg_rewrite.ev_class
JOIN pg_class source_table ON source_table.oid = pg_depend.refobjid
WHERE source_table.relname = 'books';
```

## SQL view

```sql
-- View for a reporting dashboard
CREATE VIEW checkout_summary AS
SELECT
    DATE_TRUNC('month', c.checked_out_at) AS month,
    COUNT(*) AS total_checkouts,
    COUNT(DISTINCT c.patron_id) AS unique_patrons,
    AVG(EXTRACT(EPOCH FROM (COALESCE(c.returned_at, now()) - c.checked_out_at)) / 86400) AS avg_days
FROM checkouts c
GROUP BY 1
ORDER BY 1 DESC;

-- Query through the view
SELECT * FROM checkout_summary WHERE month >= '2024-01-01';
```

## Non-SQL or hybrid view

In application code, a view is equivalent to a repository method that encapsulates a complex query. The difference: the view lives in the database (always consistent regardless of which application queries it), while a repository method lives in the application (could differ across services).

## Design principle

**Views enforce a single source of truth for recurring queries.** If three parts of your application compute "available books" differently, introduce a view. One definition, consistent everywhere, changeable in one place.

## Critical thinking

- Views do not cache results — they recompute every time. A view over an expensive aggregation query is still expensive every time you query it. Use a materialized view or an explicit cache if performance is the goal.
- Nesting views (views that query other views) makes the query planner's job harder. Deep view nesting can produce unexpectedly poor plans.

## Creative thinking

Use a view as a schema migration compatibility layer: when renaming a column, keep the old view with the old name while applications migrate:

```sql
ALTER TABLE users RENAME COLUMN name TO full_name;
CREATE VIEW users_compat AS SELECT id, full_name AS name FROM users;
-- Old applications query users_compat; new ones query users directly
```

## Systems thinking

Views are a **contract** between the database schema and its consumers. Changing a view's output columns is a breaking change — treat view interfaces like API contracts. Version them (view_v1, view_v2) during transitions rather than breaking existing callers.

## MCP and agent perspective

Give agents access to views, not base tables:

- Views expose only the columns the agent needs.
- Views hide complex JOINs — agent queries are simpler.
- Views with WHERE clauses enforce data scope (an agent sees only its tenant's data).
- This is "security through views" — a complement to role-based permissions.

## Ontology perspective

- A view is a **derived relation** — its content is derived from base relations.
- A materialized view is a **persistent derived relation** — it is both derived and stored.
- The view definition is **metadata** stored in the system catalog (`pg_views`).
- `WITH CHECK OPTION` implements a **referential integrity constraint** at the view level.

## Practice session

`practice/beginner/08-views-and-functions-basics/` — exercises: create a view for available books, query through it, create a simple SQL function alongside the view.

## References

| Resource | URL | Why |
|----------|-----|-----|
| PostgreSQL docs — CREATE VIEW | https://www.postgresql.org/docs/current/sql-createview.html | Full syntax and options |
| PostgreSQL docs — Materialized Views | https://www.postgresql.org/docs/current/sql-creatematerializedview.html | When to use materialized views |
| PostgreSQL docs — Updatable Views | https://www.postgresql.org/docs/current/sql-createview.html#SQL-CREATEVIEW-UPDATABLE-VIEWS | When views allow writes |
| SQLBolt — Lesson 17 | https://sqlbolt.com/lesson/creating_views | Interactive view exercise |
