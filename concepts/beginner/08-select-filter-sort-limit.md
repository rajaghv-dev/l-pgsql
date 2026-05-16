# SELECT, Filter, Sort, Limit

Level: Beginner

## One-line intuition

A SELECT statement is a question you ask the database: "Give me these columns, from this table, where this is true, in this order, and only this many rows."

## Why this exists

Tables hold thousands or millions of rows. You almost never want all of them. SELECT lets you slice, filter, sort, and cap the result set without touching the stored data.

## First-principles explanation

A query is evaluated in a fixed logical order — not the order you write it:

```
FROM → WHERE → SELECT (columns) → ORDER BY → LIMIT
```

The database first decides which rows qualify (WHERE), then decides which columns to show (SELECT), then sorts (ORDER BY), then cuts off the tail (LIMIT). Understanding this order explains most beginner mistakes (like using an alias in WHERE — the alias doesn't exist yet at that stage).

## Micro-concepts

| Clause | Purpose |
|--------|---------|
| `SELECT col` | Choose columns; `*` = all |
| `FROM table` | Source relation |
| `WHERE condition` | Row-level filter (before aggregation) |
| `ORDER BY col [ASC|DESC]` | Sort result |
| `LIMIT n` | Cap rows returned |
| `OFFSET n` | Skip n rows (pagination) |
| `AS alias` | Rename column in output |
| `DISTINCT` | Remove duplicate result rows |

## Beginner view

Think of a library catalog on paper. You have index cards for every book.

- **SELECT** = choose which fields on the card to read (title, author, ISBN)
- **FROM** = which card catalog drawer to open
- **WHERE** = filter cards: "only cards where genre = 'Science Fiction'"
- **ORDER BY** = sort the cards alphabetically by title
- **LIMIT** = take only the first 10 cards off the top

```sql
SELECT title, author
FROM books
WHERE genre = 'Science Fiction'
ORDER BY title ASC
LIMIT 10;
```

## Intermediate view

- Aliases (`AS`) rename output columns — useful for expressions: `SELECT price * 1.1 AS price_with_tax`.
- `DISTINCT` operates on the full set of selected columns — it is not per-column.
- `LIMIT` without `ORDER BY` returns rows in arbitrary order — the database chooses. Never rely on insertion order.
- `OFFSET` is O(n) — for large datasets, keyset pagination (WHERE id > last_seen_id) is faster.

## Advanced view

- PostgreSQL evaluates WHERE before SELECT, so a column alias defined in SELECT cannot appear in WHERE. Use a subquery or CTE.
- `ORDER BY` can reference column position: `ORDER BY 2 DESC` means "order by the second SELECT column." Fragile but valid.
- `FETCH FIRST n ROWS ONLY` is the SQL-standard equivalent of `LIMIT n`.
- Window functions (later stage) give access to row ordering within SELECT without collapsing rows.

## Mental model

SELECT is a pipeline: rows flow in from FROM, are filtered by WHERE, projected to columns by SELECT, reordered by ORDER BY, then truncated by LIMIT.

## PostgreSQL view

PostgreSQL's query planner converts your SQL into a plan tree. Use `EXPLAIN` (covered in the indexes lesson) to see how it executes. The planner may reorder operations for performance, but the logical result is as if the pipeline ran top-to-bottom.

## SQL view

```sql
-- Full clause demo
SELECT
    b.title          AS book_title,
    b.published_year AS year
FROM books AS b
WHERE b.genre = 'Science Fiction'
  AND b.published_year >= 2000
ORDER BY b.published_year DESC, b.title ASC
LIMIT 5
OFFSET 10;
```

## Non-SQL or hybrid view

In Python pandas: `df[df['genre']=='Science Fiction'][['title','year']].sort_values('year', ascending=False).head(5)` — same pipeline, different syntax.

## Design principle

**Fetch only what you need.** `SELECT *` in production code is a code smell: it pulls columns you may not use, breaks if schema changes, and prevents some optimizations.

## Critical thinking

- What happens with `LIMIT 10` and no `ORDER BY`? Results are non-deterministic — correct today, different tomorrow after a VACUUM or reindex.
- `WHERE name = NULL` returns zero rows. NULL comparisons require `IS NULL` / `IS NOT NULL`. NULL is not equal to anything, including itself.

## Creative thinking

Combine `SELECT` with a `CASE` expression to create computed columns on the fly:

```sql
SELECT title,
       CASE WHEN pages > 500 THEN 'long' ELSE 'short' END AS length_category
FROM books;
```

## Systems thinking

In a microservices system, each service query should be the minimal SELECT needed for that service's responsibility. Over-fetching drives up memory, network, and serialization cost at every layer.

## MCP and agent perspective

An agent using a `search_books` MCP tool internally translates to:

```sql
SELECT title, author, isbn
FROM books
WHERE genre = $1
ORDER BY published_year DESC
LIMIT $2;
```

The tool enforces: parameterized inputs (prevent SQL injection), LIMIT cap (prevent runaway reads), column whitelist (prevent exposing sensitive columns).

## Ontology perspective

- `SELECT` is a **projection** (relational algebra term — choose columns).
- `WHERE` is a **selection** (choose rows — confusingly opposite to the keyword name).
- `ORDER BY` is not a relational operation — relations are unordered sets. It is a display operation.
- `LIMIT` is a **restriction** on cardinality — not part of classical relational algebra.

## Practice session

See `practice/beginner/02-first-queries/` for SELECT / WHERE / ORDER BY exercises.

The joins practice (`practice/beginner/04-joins-and-aggregation/`) extends filtering across multiple tables.

## References

| Resource | URL | Why |
|----------|-----|-----|
| PostgreSQL docs — SELECT | https://www.postgresql.org/docs/current/sql-select.html | Complete syntax reference |
| PostgreSQL docs — Queries | https://www.postgresql.org/docs/current/queries.html | Chapter covering SELECT in depth |
| SQLBolt — Lesson 1–4 | https://sqlbolt.com/lesson/select_queries_introduction | Interactive beginner exercises |
| Use The Index, Luke — Where clause | https://use-the-index-luke.com/sql/where-clause | How WHERE interacts with indexes |
