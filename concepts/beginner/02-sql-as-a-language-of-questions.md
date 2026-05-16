# SQL as a Language of Questions

Level: Beginner

---

## One-line intuition

SQL lets you say **what you want** from data, not **how to get it** — the database figures out the how.

---

## Why this exists

Before SQL, querying a database meant writing low-level navigation code: "open file, read record 1, check field, advance pointer..." SQL (Structured Query Language, 1974, IBM) flipped this. You describe the result you want; the query planner decides the most efficient path to produce it.

This separation — what vs how — is the defining property of a **declarative language**.

---

## First-principles explanation

Imperative code (Python, Go) says: "Do step 1, then step 2, then step 3."
Declarative code (SQL) says: "Here is what the answer looks like. Find it."

```python
# Imperative (Python) — you control the loop
available_books = []
for book in all_books:
    if book['available'] and book['year'] > 2010:
        available_books.append(book)
available_books.sort(key=lambda b: b['title'])
```

```sql
-- Declarative (SQL) — you describe the result
SELECT title, author
FROM   books
WHERE  available = true
  AND  year > 2010
ORDER  BY title;
```

Both produce the same result. SQL does not specify a loop, a comparison order, or a sort algorithm. The database chooses.

---

## Micro-concepts

| Clause | Question it answers |
|--------|---------------------|
| `SELECT` | Which columns (attributes) do I want? |
| `FROM` | Which table(s) contain the data? |
| `WHERE` | Which rows match my conditions? |
| `ORDER BY` | In what sequence should results appear? |
| `LIMIT` | How many rows do I need? |
| `GROUP BY` | How should I aggregate rows into groups? |
| `HAVING` | Which groups match my conditions after aggregation? |
| `JOIN` | How do I combine rows from two tables? |

---

## Beginner view

A SQL SELECT is a question with four optional parts:

```
SELECT <what I want>
FROM   <where it lives>
WHERE  <conditions it must meet>
ORDER BY <how I want it sorted>
```

Example questions:
- "Give me all book titles." → `SELECT title FROM books;`
- "Give me books that are available." → `SELECT title FROM books WHERE available = true;`
- "Give me available books, newest first." → `SELECT title FROM books WHERE available = true ORDER BY year DESC;`

---

## Intermediate view

SQL has four families of statements:

| Family | Acronym | Statements | Purpose |
|--------|---------|-----------|---------|
| Data Query | DQL | SELECT | Read data |
| Data Manipulation | DML | INSERT, UPDATE, DELETE | Change data |
| Data Definition | DDL | CREATE, ALTER, DROP | Change structure |
| Data Control | DCL | GRANT, REVOKE | Change permissions |

Beginners start with DQL (SELECT) and simple DML.

---

## Advanced view

SQL is relationally complete (Codd's theorem): any answer expressible in relational algebra is expressible in SQL. This includes:
- Correlated subqueries
- Window functions (RANK, LAG, LEAD)
- Common Table Expressions (WITH)
- Recursive queries (WITH RECURSIVE)

The query planner transforms your SQL into a **query plan** — a tree of physical operations. `EXPLAIN` shows this tree. Understanding plans is the key to optimizing slow queries.

---

## Mental model

Imagine SQL as a conversation with a librarian:

- `SELECT title` — "I want the title"
- `FROM books` — "from the books catalog"
- `WHERE available = true` — "only ones currently on the shelf"
- `ORDER BY title` — "sorted alphabetically"

The librarian (query planner) goes and finds them. You did not specify which shelf to check first or how to walk the catalog. That is the librarian's job.

---

## PostgreSQL view

PostgreSQL is ANSI SQL compliant and adds extensions:

| Standard SQL | PostgreSQL addition |
|-------------|---------------------|
| `VARCHAR(n)` | `TEXT` (no length limit, same performance) |
| `BOOLEAN` | `TRUE` / `FALSE` / `NULL` |
| `TIMESTAMP` | `TIMESTAMPTZ` (timezone-aware) |
| Window functions | `FILTER`, custom aggregates |
| `JSON` | `JSONB` (binary JSON with indexing) |

---

## SQL view

```sql
-- Basic SELECT
SELECT title, author, year
FROM   books
WHERE  available = true
ORDER  BY year DESC
LIMIT  5;

-- Aggregate: count books per author
SELECT author, COUNT(*) AS book_count
FROM   books
GROUP  BY author
ORDER  BY book_count DESC;

-- Update
UPDATE books
SET    available = false
WHERE  id = 3;

-- Delete
DELETE FROM books
WHERE  year < 1900;
```

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Non-SQL or hybrid view

NoSQL databases (MongoDB, DynamoDB) use imperative-style APIs: `collection.find({available: true}).sort({year: -1})`. You call methods; the driver handles iteration. SQL is more abstract — the database handles iteration entirely.

GraphQL is another declarative query language, but for APIs rather than databases. It has similar "describe what you want" semantics.

---

## Design principle

**Express intent, not procedure.** A well-written SQL query reads like a business requirement: "Find available books published after 2010, sorted by title." If your SQL is hard to read, restructure it with CTEs (WITH clauses) or views — the database will still plan it efficiently.

---

## Critical thinking

- If SQL is declarative, why do query planners sometimes make bad choices? (Stale statistics, unusual data distributions, complex joins with no matching index.)
- Why can the same SQL query run in 1ms or 10 seconds depending on context? (Index presence, table size, connection load, hardware.)
- When is a Python loop better than SQL? (When logic cannot be expressed in SQL: calling an API per row, complex branching with external state.)

---

## Creative thinking

Think of SQL as a **wish**. You state what you want; the database grants it as efficiently as it can. Unlike a genie, though, PostgreSQL tells you what it is planning before it does it (`EXPLAIN`) and does not misinterpret your wish.

---

## Systems thinking

SQL queries go through a pipeline:

```
Text → Parser → Analyzer → Rewriter → Planner → Executor → Results
```

Each stage transforms the query. The Planner is the most expensive — it evaluates multiple execution strategies and picks the lowest-cost one based on table statistics. This is why `ANALYZE` (update statistics) matters: bad statistics → bad plan → slow query.

---

## MCP and agent perspective

An AI agent issuing SQL queries is making **structured requests to its memory**. The declarative nature of SQL is ideal: the agent states what information it needs (`SELECT tasks WHERE due < now()`), and the database handles retrieval. The agent does not need to know how the data is physically stored.

For write operations, the agent uses `INSERT` and `UPDATE` — again declarative: "this fact now exists." The database handles conflict detection, constraint enforcement, and durability.

---

## Ontology perspective

SQL SELECT is essentially an **ontological query**: "Which instances of this class have these properties?" The `WHERE` clause filters the extension of a concept. `GROUP BY` creates new aggregate concepts. `JOIN` composes two concepts into a combined view.

---

## Practice session

See `practice/beginner/01-basic-sql/` for SELECT, INSERT, UPDATE, DELETE exercises on a library books table.

---

## References

| Resource | URL |
|----------|-----|
| PostgreSQL 16 — SELECT | https://www.postgresql.org/docs/16/sql-select.html |
| PostgreSQL 16 — DML | https://www.postgresql.org/docs/16/dml.html |
| PostgreSQL Tutorial (free) | https://www.postgresqltutorial.com/ |
| SQLZoo (interactive, free) | https://sqlzoo.net/ |
| Mode SQL Tutorial (free) | https://mode.com/sql-tutorial/ |
