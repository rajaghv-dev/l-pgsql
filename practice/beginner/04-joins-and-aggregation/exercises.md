# Exercises: JOINs and Aggregation

Level: Beginner

Work through each exercise in order. Do not look at `solutions.md` until you have tried.

---

## Exercise 1: INNER JOIN — Books with their Author Names

**Goal:** Write a query that shows each book's title alongside its author's name.

**First-principles question:** Why do we need a JOIN here? Why not just store the author's name in the books table?

**Task:** Select `title` from `books` and `name` from `authors`. Join them on `books.author_id = authors.id`. Order by author name, then book title. Exclude the one book with no author (that is a LEFT JOIN scenario — exercise 2).

**Hint:** INNER JOIN only returns rows that have a match in both tables. The book with `author_id IS NULL` will be automatically excluded.

**Your SQL:**
```sql
-- Write your solution here
```

**Expected result (first 5 rows):**
```
         title          |     name
------------------------+------------------
 2001: A Space Odyssey  | Arthur C. Clarke
 Rendezvous with Rama   | Arthur C. Clarke
 Kindred                | Octavia Butler
 Parable of the Sower   | Octavia Butler
 Do Androids Dream?     | Philip K. Dick
...
(13 rows total — book 14 excluded)
```

**Validation query:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT COUNT(*) FROM books b INNER JOIN authors a ON b.author_id = a.id;
"
# Expected: 13 (not 14 — the NULL author_id book is excluded)
```

**Critical-thinking question:** If you changed INNER JOIN to LEFT JOIN here, how many rows would you get and what would the author column contain for book 14?

**Creative-thinking question:** How would you write this query to show only books published after 1970 by female authors? (Ursula K. Le Guin and Octavia Butler are in the dataset.)

**Systems-thinking question:** If the `authors` table grew to 1 million rows, what would you add to make this JOIN faster?

**Ontology-thinking question:** A JOIN result is itself a relation. What is the "key" (unique identifier) of the result relation in this query?

**Agent/MCP angle:**
- Agent scenario: A book recommendation agent needs to display "book title + author name" for a reading list.
- MCP tool name: `get_reading_list`
- Tool input: `{ "patron_id": 101 }`
- PostgreSQL operation: The INNER JOIN query above, filtered by patron_id via a checkouts join.
- Required permission: `SELECT` on `books`, `authors`, `checkouts` for role `mcp_agent_reader`
- Validation before execution: Verify patron_id is a positive integer.
- Failure mode: Author deleted but book FK still points to it (prevented by the FK constraint).
- Ontology connection: `[[inner-join]]` → `[[foreign-key]]`

**What this teaches:** INNER JOIN combines related rows from two tables; it excludes rows that have no match.

**Where this applies in real systems:** Every ORM "eager load" (Rails includes, Django select_related) is an INNER or LEFT JOIN under the hood.

**References:**
- PostgreSQL docs — Table Expressions: https://www.postgresql.org/docs/current/queries-table-expressions.html

---

## Exercise 2: LEFT JOIN — All Books, Including Those with No Author on File

**Goal:** List all 14 books, showing the author name if known, or "Unknown" if not.

**First-principles question:** What is the fundamental difference between INNER JOIN and LEFT JOIN in terms of which rows survive?

**Task:** Select all books. For each book, show the author name if `author_id` is not NULL. If `author_id` IS NULL, display the string `'Unknown'` in the author column. Use `COALESCE` or a `CASE` expression.

**Hint:** LEFT JOIN keeps all rows from the left table (books). Use `COALESCE(authors.name, 'Unknown')` to replace NULL.

**Your SQL:**
```sql
-- Write your solution here
```

**Expected result (partial):**
```
         title           |      author_name
-------------------------+-------------------
 Foundation              | Isaac Asimov
 ...
 Anonymous Classic       | Unknown
(14 rows)
```

**Validation query:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT COUNT(*) FROM books b LEFT JOIN authors a ON b.author_id = a.id;
"
# Expected: 14 rows (all books included)
```

**Critical-thinking question:** Why does `COALESCE(authors.name, 'Unknown')` only produce 'Unknown' for one row, not for all rows where author_id is NULL?

**Creative-thinking question:** What if you wanted `'Unknown (pre-1900)'` for old anonymous books? Rewrite using `CASE`.

**Systems-thinking question:** In a production library system, would you allow `author_id` to be NULL, or enforce NOT NULL and create an "Unknown" author row? What are the trade-offs?

**Ontology-thinking question:** LEFT JOIN is asymmetric — the order of tables matters. RIGHT JOIN is its mirror. Why is RIGHT JOIN rarely used in practice?

**Agent/MCP angle:**
- Agent scenario: A catalog display agent needs to show all books, even those with incomplete metadata.
- MCP tool name: `list_all_books`
- PostgreSQL operation: The LEFT JOIN query above.
- Required permission: `SELECT` on `books`, `authors`
- Failure mode: Displaying NULL to the end user instead of "Unknown" — handle in the query, not the application layer.
- Ontology connection: `[[left-join]]` → `[[null-handling]]`

**What this teaches:** LEFT JOIN never loses rows from the left table — it fills right-side columns with NULL when there is no match.

**Where this applies in real systems:** Showing a list of products where some have no category assigned yet; showing all users whether or not they have a profile.

**References:**
- SQLBolt — Lesson 7: https://sqlbolt.com/lesson/select_queries_with_outer_joins

---

## Exercise 3: LEFT JOIN to Find Books Never Checked Out

**Goal:** Find all books that have never been checked out.

**First-principles question:** How does LEFT JOIN + NULL check find "things with no related records"? Why not use a subquery with NOT IN?

**Task:** Use a LEFT JOIN between books and checkouts. Filter for rows where no checkout record exists (hint: the checkout's primary key will be NULL after a LEFT JOIN with no match).

**Hint:** After `LEFT JOIN checkouts c ON c.book_id = b.id`, if a book has no checkouts, `c.id` will be NULL. Filter with `WHERE c.id IS NULL`.

**Your SQL:**
```sql
-- Write your solution here
```

**Expected result:**
```
 id |          title              | author_name
----+-----------------------------+------------------
  9 | Rendezvous with Rama        | Arthur C. Clarke
 11 | The Man in the High Castle  | Philip K. Dick
 14 | Anonymous Classic           | Unknown
(3 rows)
```

**Critical-thinking question:** Would `WHERE c.book_id IS NULL` also work? Why or why not?

**Creative-thinking question:** Rewrite this query using `NOT EXISTS` instead of LEFT JOIN. Which approach do you find more readable?

**Systems-thinking question:** Books never checked out might be candidates for removal from the catalog. How would you schedule a monthly report that identifies these books and notifies a librarian?

**Ontology-thinking question:** "Anti-join" is the relational algebra term for this pattern (find rows in A with no match in B). Is LEFT JOIN + NULL check the same as EXCEPT? Test it.

**Agent/MCP angle:**
- Agent scenario: A collection management agent runs monthly to flag uncirculated books.
- MCP tool name: `find_uncirculated_books`
- PostgreSQL operation: LEFT JOIN + `WHERE c.id IS NULL`
- Required permission: `SELECT` on `books`, `authors`, `checkouts`
- Audit log entry: Log each identified book_id and date to a `catalog_review_log` table.
- Ontology connection: `[[anti-join]]` → `[[left-join]]` → `[[null-check]]`

**What this teaches:** LEFT JOIN + NULL check is the idiomatic pattern for "find rows with no related record" (anti-join).

**Where this applies in real systems:** Finding users who have not logged in for 90 days, orders with no fulfillment records, customers with no purchases.

---

## Exercise 4: GROUP BY + COUNT — Checkouts per Author

**Goal:** Count total checkouts per author, sorted by most checkouts first.

**First-principles question:** In what order does PostgreSQL process FROM, JOIN, WHERE, GROUP BY, and SELECT? Why does this order matter for aggregate functions?

**Task:** Join all three tables (authors → books → checkouts). Group by author name. Count the number of checkouts per author. Order by count descending.

**Hint:** You need two JOINs: books JOIN authors (for the author name) and books JOIN checkouts (for the count). Both should be INNER JOINs here — you only want authors who have books, and books that have checkouts.

**Your SQL:**
```sql
-- Write your solution here
```

**Expected result:**
```
      name           | checkout_count
---------------------+----------------
 Isaac Asimov        |              4
 Frank Herbert       |              3
 Octavia Butler      |              2
 Philip K. Dick      |              1
 Ursula K. Le Guin   |              2
 Arthur C. Clarke    |              1
```
(Note: order may differ for tied values depending on tie-breaking; use `ORDER BY checkout_count DESC, name ASC` for deterministic output)

**Validation query:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT SUM(checkout_count) FROM (
    SELECT COUNT(*) AS checkout_count FROM checkouts GROUP BY (SELECT book_id)
  ) sub;
"
# Expected: 14 (total checkouts)
```

**Critical-thinking question:** What if you used `COUNT(c.id)` vs `COUNT(*)` in this query? Is there a difference given the INNER JOIN?

**Creative-thinking question:** How would you add a column showing the author's most recently checked out book title alongside the count?

**Systems-thinking question:** This query crosses three tables. Which index would most improve its performance? (Hint: look at the JOIN columns.)

**Ontology-thinking question:** `GROUP BY a.name` groups by author name (text). What would happen if two different authors had the same name? How should you fix this?

**Agent/MCP angle:**
- Agent scenario: A dashboard agent generates a "top authors by circulation" widget.
- MCP tool name: `get_author_circulation`
- Tool input: `{ "limit": 10 }`
- PostgreSQL operation: The GROUP BY + COUNT query above with LIMIT applied.
- Required permission: `SELECT` on `authors`, `books`, `checkouts`
- Ontology connection: `[[group-by]]` → `[[aggregate-function]]` → `[[join]]`

**What this teaches:** GROUP BY creates groups; COUNT(*) counts rows per group; ORDER BY rank makes the result useful.

**Where this applies in real systems:** Analytics dashboards, reports, leaderboards, and any "top N by metric" query.

---

## Exercise 5: HAVING — Authors with More Than One Book

**Goal:** List authors who have published more than one book in the catalog.

**First-principles question:** What is the difference between WHERE and HAVING? Why can't you use WHERE to filter on a COUNT result?

**Task:** Join books and authors. Group by author. Use HAVING to keep only authors with more than one book. Show name + book count.

**Hint:** `HAVING COUNT(b.id) > 1` — HAVING filters after GROUP BY.

**Your SQL:**
```sql
-- Write your solution here
```

**Expected result:**
```
      name           | book_count
---------------------+-----------
 Isaac Asimov        |          3
 Frank Herbert       |          2
 Ursula K. Le Guin   |          2
 Arthur C. Clarke    |          2
 Philip K. Dick      |          2
 Octavia Butler      |          2
(6 rows — all authors in seed data have 2+ books)
```

**Critical-thinking question:** If WHERE and HAVING cannot both filter on COUNT, write a query that uses WHERE to pre-filter by published_year AND HAVING to post-filter by book count. What is the logical order of these filters?

**Creative-thinking question:** Rewrite this query using a subquery in WHERE instead of HAVING. Which version does PostgreSQL execute more efficiently?

**Systems-thinking question:** If you add a new author with only one book to the database, does this query need to be updated? Why is this an example of a self-maintaining query?

**Ontology-thinking question:** HAVING is to groups what WHERE is to rows. Is there an equivalent filter for columns? (Hint: think about which relational algebra operation filters columns.)

**What this teaches:** HAVING filters groups after aggregation — it is the WHERE for GROUP BY results.

**References:**
- SQLBolt — Lesson 11: https://sqlbolt.com/lesson/select_queries_with_aggregates_pt_2
- PostgreSQL docs — Aggregate: https://www.postgresql.org/docs/current/tutorial-agg.html

---

## Exercise 6 (stretch): Average Checkout Duration per Book

**Goal:** Compute the average number of days each book was checked out, for books that have been returned at least once.

**Difficulty:** Stretch — only attempt after completing exercises 1–5.

**Task:** Join books and checkouts. Filter for returned checkouts only (`returned_at IS NOT NULL`). Compute `AVG` of `(returned_at - checked_out_at)` in days. Round to one decimal. Show book title and average days. Order by average days descending.

**Hint:** `EXTRACT(EPOCH FROM (returned_at - checked_out_at)) / 86400` gives duration in days. Wrap in `ROUND(..., 1)`.

**Your SQL:**
```sql
-- Write your solution here
```

**Expected result (example — exact values depend on when setup.sql was run):**
```
         title                | avg_days
------------------------------+----------
 Foundation                   |     21.0
 Foundation and Empire        |     21.0
 ...
```

**Critical-thinking question:** Why do currently-checked-out books (returned_at IS NULL) not appear? Would they appear if you changed the AVG to include them using `COALESCE(returned_at, now())`? What would the interpretation be?

**What this teaches:** Combining INNER JOIN, WHERE, GROUP BY, and ROUND with a computed column expression.
