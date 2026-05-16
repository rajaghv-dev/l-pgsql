# Solutions: Views and Functions Basics

Level: Beginner

Read `exercises.md` and attempt the exercises before opening this file.

---

## Solution: Exercise 1 — Query Through a View

```bash
# All available books
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT * FROM available_books ORDER BY title;
"

# Sci-Fi only
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT * FROM available_books WHERE genre = 'Sci-Fi' ORDER BY title;
"
```

**Why this works:** The view `available_books` is a named SELECT. Adding `WHERE genre = 'Sci-Fi'` appends a filter to the view's definition. PostgreSQL merges the two conditions (view's NOT IN + caller's WHERE) into a single query plan.

**Key learning:** Views are composable — a caller can filter, sort, join, or aggregate on top of a view without knowing the view's internal complexity.

**NOT IN danger (critical thinking answer):** `NOT IN (subquery)` returns no rows if the subquery returns any NULL value. If `book_id` in the subquery could be NULL, all rows would be excluded. The safe alternative: `NOT EXISTS` or `LEFT JOIN + IS NULL`:
```sql
-- Safe alternative to NOT IN
SELECT b.id, b.title, b.author, b.genre
FROM books b
LEFT JOIN checkouts c ON c.book_id = b.id AND c.returned_at IS NULL
WHERE c.id IS NULL;
```

---

## Solution: Exercise 2 — Create a View

```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
DROP VIEW IF EXISTS overdue_checkouts;

CREATE VIEW overdue_checkouts AS
SELECT
    patron_name,
    title,
    due_date,
    days_overdue(due_date) AS days_overdue
FROM active_checkouts
WHERE days_overdue(due_date) > 0;

SELECT * FROM overdue_checkouts ORDER BY days_overdue DESC;
EOF
```

**Why this works:** `overdue_checkouts` is a view on top of another view (`active_checkouts`). PostgreSQL merges both view definitions into a single plan. The `days_overdue()` function is called once per row in WHERE and once per row in SELECT — but since the function simply computes `(CURRENT_DATE - due)::INT`, the cost is negligible.

**To avoid double-call (advanced):**
```sql
CREATE VIEW overdue_checkouts AS
SELECT patron_name, title, due_date, days_owed
FROM (
    SELECT patron_name, title, due_date, days_overdue(due_date) AS days_owed
    FROM active_checkouts
) sub
WHERE days_owed > 0;
```

---

## Solution: Exercise 3 — SQL Function

```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
CREATE OR REPLACE FUNCTION book_summary(p_book_id INT)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT title || ' (' || year::text || ') by ' || author
           || ' — ' || COALESCE(genre, 'Unknown')
    FROM books
    WHERE id = p_book_id;
$$;

SELECT id, book_summary(id) AS summary FROM books ORDER BY id;
EOF
```

**Why this works:** `LANGUAGE sql` means the function body is a single SQL statement. `STABLE` tells the planner that within a single transaction, the same input produces the same output — allowing some optimizations. The function is used in a SELECT list, called once per row of `books`.

**Key learning:** SQL functions are the simplest function type in PostgreSQL. They can reference tables and run any SELECT. The result is inlined into the calling query — the planner may optimize the function body away (the SELECT on `books` is merged into the outer query).

---

## Solution: Exercise 4 — View vs Materialized View

This exercise is conceptual. The materialized view syntax:

```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
DROP MATERIALIZED VIEW IF EXISTS checkout_summary_monthly;

CREATE MATERIALIZED VIEW checkout_summary_monthly AS
SELECT
    DATE_TRUNC('month', checked_out::timestamptz) AS month,
    COUNT(*) AS total_checkouts
FROM checkouts
GROUP BY 1
ORDER BY 1;

SELECT * FROM checkout_summary_monthly;

-- After adding new checkouts:
REFRESH MATERIALIZED VIEW checkout_summary_monthly;
EOF
```

**Key rule:**
- Use a regular view when: data changes frequently, staleness is unacceptable, query is fast enough.
- Use a materialized view when: the query is expensive, the data can be slightly stale, or many concurrent users query the same result.

---

## Solution: Exercise 5 (stretch) — View Dependencies

```bash
# Show what depends on books
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT DISTINCT dependent_view.relname
  FROM pg_depend d
  JOIN pg_rewrite r ON r.oid = d.objid
  JOIN pg_class dependent_view ON dependent_view.oid = r.ev_class
  JOIN pg_class source ON source.oid = d.refobjid
  WHERE source.relname = 'books'
    AND dependent_view.relname != 'books'
    AND d.deptype = 'n';
"
```

Expected: `available_books`, `active_checkouts`, `overdue_checkouts` (if created in exercise 2).

**Drop cascade + restore:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "DROP TABLE books CASCADE;"

docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/08-views-and-functions-basics/setup.sql
```

**Key learning:** `DROP TABLE ... CASCADE` removes the table and all dependent views/functions. In production, always check `pg_depend` before cascading drops. Maintain a view creation script (like setup.sql) so you can recreate after a cascade.
