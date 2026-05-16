# Exercises: Views and Functions Basics

Level: Beginner

Work through each exercise in order. Do not look at `solutions.md` until you have tried.

---

## Exercise 1: Query Through an Existing View

**Goal:** Understand that a view is queried like a table — you can add WHERE, ORDER BY, and LIMIT on top of it.

**First-principles question:** The `available_books` view has no WHERE clause for genre. If you want available Sci-Fi books only, do you need to modify the view or can you add the WHERE to your query?

**Task:**
1. Query `available_books` to see all available books.
2. Add a WHERE clause to filter for Sci-Fi genre only.
3. Verify the result.

**Commands:**
```bash
# All available books
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT * FROM available_books ORDER BY title;
"

# Available Sci-Fi books only
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT * FROM available_books WHERE genre = 'Sci-Fi' ORDER BY title;
"
```

**Expected result (available books):**
```
 id |          title           |    author    | genre
----+--------------------------+--------------+-------
  3 | Dune                     | Frank Herbert| Sci-Fi
  4 | Thinking, Fast and Slow  | Kahneman     | Psychology
  5 | The Left Hand of Darkness| Le Guin      | Sci-Fi
```

(Books 1 and 2 have active checkouts — they are not available.)

**Critical-thinking question:** The view definition uses `NOT IN (SELECT book_id FROM checkouts WHERE returned_at IS NULL)`. A colleague says "just use LEFT JOIN + IS NULL — NOT IN is dangerous." When is NOT IN dangerous? (Hint: what happens if `book_id` contains NULL values?)

**Agent/MCP angle:**
- Agent scenario: A patron-facing bot checks available books by genre before suggesting a checkout.
- MCP tool name: `find_available_books`
- Tool input: `{ "genre": "Sci-Fi" }`
- PostgreSQL operation: `SELECT * FROM available_books WHERE genre = $1 LIMIT 20`
- Required permission: `SELECT` on `available_books` view only — not on `books` or `checkouts` tables.
- This is "security through views" — the agent cannot see patron checkout history, only book availability.

**What this teaches:** Views are composable — you query them like tables and add your own filters. The view encapsulates the complexity; the caller adds specifics.

---

## Exercise 2: Create Your Own View

**Goal:** Create a new view that shows overdue books with the number of days overdue.

**First-principles question:** A view is a named SELECT. How is creating a view different from creating a table? (A table stores data; a view runs the query fresh each time.)

**Task:** Create a view called `overdue_checkouts` that:
- Joins `active_checkouts` with the `days_overdue()` function
- Shows: patron_name, title, due_date, days_overdue
- Filters for books where `days_overdue(due_date) > 0`

**Your SQL:**
```sql
CREATE VIEW overdue_checkouts AS
SELECT
    patron_name,
    title,
    due_date,
    days_overdue(due_date) AS days_overdue
FROM active_checkouts
WHERE days_overdue(due_date) > 0;
```

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE VIEW overdue_checkouts AS
  SELECT patron_name, title, due_date, days_overdue(due_date) AS days_overdue
  FROM active_checkouts
  WHERE days_overdue(due_date) > 0;

  SELECT * FROM overdue_checkouts ORDER BY days_overdue DESC;
"
```

**Expected result (as of 2026-05-16):**
```
 patron_name |               title                |  due_date  | days_overdue
-------------+------------------------------------+------------+--------------
 Charlie     | Designing Data-Intensive Apps      | 2026-04-24 |           22
 Bob         | The Pragmatic Programmer           | 2026-05-04 |           12
 Eve         | Thinking, Fast and Slow            | 2026-05-15 |            1
```

**Critical-thinking question:** This view calls `days_overdue(due_date)` twice — once in SELECT, once in WHERE. Is the function called twice per row? (Yes — SQL evaluates each expression independently. Use a subquery or CTE to call it once if the function is expensive.)

**Creative-thinking question:** How would you modify `overdue_checkouts` to also show how many total overdue books a patron has? (Hint: add GROUP BY patron_name and COUNT(*) — but then you need to move to a new view or subquery since you cannot mix aggregate and non-aggregate columns without grouping all of them.)

**Systems-thinking question:** `days_overdue()` uses `CURRENT_DATE`. This means the view's results change every day without any data changing. How does this affect caching strategies? (A materialized view refreshed once per day would be stale. A regular view is always current but recomputes every query.)

**What this teaches:** Views can layer on top of other views (view over a view) and can call functions. The result is always computed fresh from current data.

---

## Exercise 3: Write a New SQL Function

**Goal:** Write a SQL function that computes a formatted summary for a book.

**First-principles question:** Why would you write a SQL function instead of computing the value in application code? (Database functions run where the data lives — no network round-trip for the computation.)

**Task:** Create a function `book_summary(book_id INT)` that returns a text string like `"Dune (1965) by Frank Herbert — Sci-Fi"`.

**Your SQL:**
```sql
CREATE OR REPLACE FUNCTION book_summary(p_book_id INT)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT title || ' (' || year::text || ') by ' || author || ' — ' || COALESCE(genre, 'Unknown')
    FROM books
    WHERE id = p_book_id;
$$;
```

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE OR REPLACE FUNCTION book_summary(p_book_id INT)
  RETURNS TEXT
  LANGUAGE sql
  STABLE
  AS \$\$
    SELECT title || ' (' || year::text || ') by ' || author || ' — ' || COALESCE(genre, 'Unknown')
    FROM books
    WHERE id = p_book_id;
  \$\$;

  -- Test it
  SELECT id, book_summary(id) AS summary FROM books ORDER BY id;
"
```

**Expected result:**
```
 id |                         summary
----+----------------------------------------------------------
  1 | The Pragmatic Programmer (1999) by Hunt & Thomas — Technology
  2 | Designing Data-Intensive Apps (2017) by Kleppmann — Technology
  3 | Dune (1965) by Frank Herbert — Sci-Fi
  4 | Thinking, Fast and Slow (2011) by Kahneman — Psychology
  5 | The Left Hand of Darkness (1969) by Le Guin — Sci-Fi
```

**Critical-thinking question:** The function is marked `STABLE` (same inputs in same transaction = same output). Why not `IMMUTABLE`? (Because it queries the `books` table — the table might change between calls. `IMMUTABLE` would be wrong here.)

**Agent/MCP angle:**
- Agent scenario: A recommendation agent formats book results for display without knowing the schema.
- MCP tool name: `describe_book`
- Tool input: `{ "book_id": 3 }`
- PostgreSQL operation: `SELECT book_summary($1)`
- Key advantage: The agent does not need to know how books are stored — it calls the function. The schema can change (e.g., add `subtitle`) and only the function definition needs updating.

**What this teaches:** SQL functions encapsulate query logic behind a named interface. They can be used in SELECT, WHERE, or any expression context.

---

## Exercise 4: View vs Materialized View (Conceptual)

**Goal:** Understand when to use a regular view vs a materialized view.

**First-principles question:** A regular view recomputes every time you query it. A materialized view stores results and requires explicit REFRESH. When is each appropriate?

**Task:** This exercise is conceptual — no new objects to create. Answer the scenario questions.

**Scenario A:** A dashboard shows "how many checkouts happened today." The query takes 50ms. The dashboard refreshes every 5 seconds.
- Regular view or materialized view? **Regular view** — 50ms is fast enough, and you need up-to-the-second accuracy.

**Scenario B:** A monthly report aggregates 5 years of checkout history across 3 tables. The query takes 45 seconds. The report is viewed by 20 people each morning.
- Regular view or materialized view? **Materialized view** — refresh once at midnight, 20 people query instantly instead of waiting 45 seconds each.

**Scenario C:** A public catalog page shows available books. Stock changes in real-time as books are checked out and returned.
- Regular view or materialized view? **Regular view** — stale data would show books as available when they are not. Real-time is essential.

**Command (demonstrate materialized view syntax):**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE MATERIALIZED VIEW checkout_summary_monthly AS
  SELECT
    DATE_TRUNC('month', checked_out::timestamptz) AS month,
    COUNT(*) AS total_checkouts
  FROM checkouts
  GROUP BY 1
  ORDER BY 1;

  SELECT * FROM checkout_summary_monthly;

  -- Refresh after new checkouts
  REFRESH MATERIALIZED VIEW checkout_summary_monthly;
"
```

**What this teaches:** Regular views = always fresh, recomputed each time. Materialized views = fast, stale until refreshed. Choose based on: query cost, update frequency, staleness tolerance.

---

## Exercise 5 (stretch): Drop and Recreate a View

**Goal:** Understand view dependencies — what happens when you try to DROP a base object that a view depends on.

**Difficulty:** Stretch — only attempt after completing exercises 1–4.

**Task:**
1. Try to drop the `books` table while `available_books` depends on it.
2. Observe the error.
3. Use CASCADE to drop the table and all dependent views.
4. Verify the views are gone.
5. Re-run setup.sql to restore everything.

**Commands:**
```bash
# Step 1: Try to drop (will fail)
docker exec cfp_postgres psql -U cfp -d cfp -c "DROP TABLE books;"
# ERROR: cannot drop table books because other objects depend on it

# Step 2: See what depends on books
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT dependent_view.relname AS view_name
  FROM pg_depend
  JOIN pg_rewrite ON pg_rewrite.oid = pg_depend.objid
  JOIN pg_class dependent_view ON dependent_view.oid = pg_rewrite.ev_class
  JOIN pg_class source_table ON source_table.oid = pg_depend.refobjid
  WHERE source_table.relname = 'books'
    AND dependent_view.relname != 'books';
"

# Step 3: Cascade drop (destructive — followed by restore)
docker exec cfp_postgres psql -U cfp -d cfp -c "DROP TABLE books CASCADE;"

# Step 4: Re-run setup to restore
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/08-views-and-functions-basics/setup.sql
```

**What this teaches:** Views create dependencies. `DROP TABLE ... CASCADE` removes all dependent views. Check dependencies with `pg_depend` before dropping any base table or view in production.
