# JOINs — Intuition

Level: Beginner

## One-line intuition

A JOIN connects two tables on a shared value, so you can query columns from both as if they were one table.

## Why this exists

Good relational design splits data into separate tables (authors in one, books in another). JOINs re-combine them at query time — you store data once, assemble it when needed.

## First-principles explanation

A table is a relation. A JOIN creates a new relation by combining rows from two relations where a condition is true. The condition is almost always: "the foreign key in table A matches the primary key in table B."

Two kinds matter at the beginner level:

- **INNER JOIN**: keep only rows where a match exists in both tables.
- **LEFT JOIN**: keep all rows from the left table; fill with NULLs if no match in the right table.

## Micro-concepts

| Join type | Rows kept |
|-----------|-----------|
| INNER JOIN | Only rows with a match in both tables |
| LEFT JOIN (LEFT OUTER JOIN) | All left rows; NULL columns for unmatched right rows |
| RIGHT JOIN | Mirror of LEFT JOIN (rarely used — just swap table order) |

## Beginner view

Library catalog analogy: you have two card drawers — one for books, one for authors.

**INNER JOIN** = pull only the cards where you can find a matching author card. Books with unknown authors are excluded.

**LEFT JOIN** = pull all book cards. For books where no author card exists, leave the author fields blank.

```sql
-- Which books were written by which author?
SELECT books.title, authors.name
FROM books
INNER JOIN authors ON books.author_id = authors.id;

-- All books, even those with no author on file
SELECT books.title, authors.name
FROM books
LEFT JOIN authors ON books.author_id = authors.id;
```

## Intermediate view

- Table aliases shorten queries: `FROM books b INNER JOIN authors a ON b.author_id = a.id`.
- You can join on any condition, not just equality. But equality joins on indexed columns are fast; arbitrary expressions are slow.
- Multiple JOINs: `FROM books b JOIN authors a ON ... JOIN publishers p ON ...` — each JOIN adds a new table to the result set.
- After a LEFT JOIN, unmatched right rows have NULL for every right column. This is useful to find "orphans": `WHERE authors.id IS NULL` after a LEFT JOIN on authors means "books with no author."

## Advanced view

- JOIN order: PostgreSQL's planner reorders JOINs for efficiency. You can hint with `SET join_collapse_limit = 1` if needed, but rarely necessary.
- Hash join vs nested loop vs merge join: the planner chooses based on table sizes and indexes. `EXPLAIN` shows which was chosen.
- CROSS JOIN (Cartesian product): every row from A paired with every row from B. Produces A × B rows. Useful for generating combinations; dangerous if accidental.
- FULL OUTER JOIN: all rows from both sides, NULLs for non-matches. Rarely needed at the beginner level.

## Mental model

Draw two overlapping circles (Venn diagram):

- INNER JOIN = the intersection (both circles overlap).
- LEFT JOIN = the full left circle (left rows always present) plus whatever overlaps with the right.
- The JOIN condition defines where the circles overlap.

## PostgreSQL view

PostgreSQL supports all standard JOIN types. The `JOIN` keyword without qualification means INNER JOIN. Use explicit `INNER` or `LEFT` keywords for readability.

```sql
-- Explicit keywords (preferred for clarity)
SELECT b.title, a.name
FROM books AS b
INNER JOIN authors AS a ON b.author_id = a.id
WHERE b.published_year > 2000
ORDER BY b.title;
```

## SQL view

```sql
-- Find books with no checkout history (LEFT JOIN + NULL check)
SELECT b.title
FROM books b
LEFT JOIN checkouts c ON b.id = c.book_id
WHERE c.id IS NULL;

-- Count checkouts per author (JOIN + GROUP BY)
SELECT a.name, COUNT(c.id) AS total_checkouts
FROM authors a
INNER JOIN books b ON b.author_id = a.id
INNER JOIN checkouts c ON c.book_id = b.id
GROUP BY a.name
ORDER BY total_checkouts DESC;
```

## Non-SQL or hybrid view

In pandas: `pd.merge(books_df, authors_df, left_on='author_id', right_on='id', how='inner')`. The `how` parameter maps to INNER / LEFT / RIGHT / OUTER.

## Design principle

**Normalize data to avoid duplication; JOINs are the cost of normalization.** The cost is acceptable when the join key is indexed. Denormalize (store redundant data) only when query performance demands it and you have a clear update strategy.

## Critical thinking

- What if `author_id` is NULL in some books rows? An INNER JOIN excludes those rows entirely. A LEFT JOIN includes them with NULL author columns. Neither is wrong — depends on the question.
- JOIN on a non-indexed column forces a sequential scan of one table for every row in the other. Always index foreign key columns.

## Creative thinking

A self-join connects a table to itself. Useful for hierarchies:

```sql
-- Employee and their manager (same employees table)
SELECT e.name AS employee, m.name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;
```

## Systems thinking

In a microservices architecture, JOINs across services are impossible at the database level (each service owns its DB). Instead, services are joined in application code or via event streams. This is a major cost of the microservices pattern — what one SQL JOIN does, a microservice mesh requires multiple HTTP calls plus client-side assembly.

## MCP and agent perspective

An agent querying "give me all overdue books and patron contact info" translates to a JOIN across books, checkouts, and patrons. The MCP tool should:

1. Run the JOIN server-side.
2. Return only the columns needed (not `SELECT *`).
3. Use parameterized patron_id to scope the query to a specific user.
4. Not expose patron PII unless the calling role has explicit permission.

## Ontology perspective

- JOIN is a **binary operation** on two relations.
- INNER JOIN implements the relational algebra **natural join** (when joining on a foreign key).
- LEFT JOIN implements **left outer join** in relational algebra.
- The result of a JOIN is itself a relation — it can be joined again, filtered, grouped.

## Practice session

`practice/beginner/04-joins-and-aggregation/` — exercises cover INNER JOIN (books + authors), LEFT JOIN to find uncheckout books, and JOIN + GROUP BY for aggregations.

## References

| Resource | URL | Why |
|----------|-----|-----|
| PostgreSQL docs — Table Expressions | https://www.postgresql.org/docs/current/queries-table-expressions.html | Official JOIN syntax and types |
| SQLBolt — Lesson 6–7 | https://sqlbolt.com/lesson/select_queries_with_joins | Interactive JOIN exercises |
| Visual JOIN explainer | https://www.codeproject.com/Articles/33052/Visual-Representation-of-SQL-Joins | Venn diagram of all JOIN types |
| Use The Index, Luke — Joins | https://use-the-index-luke.com/sql/join | Performance impact of join types |
