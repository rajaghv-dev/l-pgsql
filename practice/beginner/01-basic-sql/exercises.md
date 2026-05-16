# Exercises — Practice 01: Basic SQL

Run `setup.sql` before starting. All SQL targets the `books` table.

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Exercise 1 — SELECT all columns

**Goal:** Retrieve every row and every column from the books table.

**SQL:**
```sql
SELECT * FROM books;
```

**Expected result:** 5 rows, all columns.

**Agent/MCP angle:** `SELECT *` is useful for discovery but avoid it in production queries — it returns columns the agent may not need and breaks if columns are added/removed.

---

## Exercise 2 — SELECT with WHERE

**Goal:** Find only books that are currently available.

**SQL:**
```sql
SELECT id, title, author, year
FROM   books
WHERE  available = true
ORDER  BY year ASC;
```

**Expected result:**
```
 id │ title       │ author          │ year
────┼─────────────┼─────────────────┼──────
  4 │ 1984        │ George Orwell   │ 1949
  1 │ Dune        │ Frank Herbert   │ 1965
  2 │ Neuromancer │ William Gibson  │ 1984
```

**Agent/MCP angle:** An agent managing a lending system would run this query to determine what it can recommend to a patron.

---

## Exercise 3 — Filter with AND/OR

**Goal:** Find available books published after 1960, OR any book by Isaac Asimov.

**SQL:**
```sql
SELECT id, title, author, year, available
FROM   books
WHERE  (available = true AND year > 1960)
    OR  author = 'Isaac Asimov'
ORDER  BY year;
```

**Expected result:** Neuromancer (1984, available), Dune (1965, available), Foundation (1951, Asimov).

**Agent/MCP angle:** Complex filter logic is more natural in SQL than in Python loops — the database evaluates it efficiently using indexes.

---

## Exercise 4 — INSERT a new book

**Goal:** Add a new book to the catalog.

**SQL:**
```sql
INSERT INTO books (title, author, year, available)
VALUES ('The Left Hand of Darkness', 'Ursula K. Le Guin', 1969, true)
RETURNING id, title;
```

**Expected result:**
```
 id │ title
────┼───────────────────────────
  6 │ The Left Hand of Darkness
```

**Note:** `RETURNING` gives back the assigned `id` without a separate SELECT.

**Agent/MCP angle:** `RETURNING` is essential for agents — they need the generated `id` to reference the new row in subsequent operations.

---

## Exercise 5 — UPDATE a single row

**Goal:** Mark "Foundation" (id=3) as available.

**SQL:**
```sql
UPDATE books
SET    available = true
WHERE  id = 3
RETURNING id, title, available;
```

**Expected result:**
```
 id │ title       │ available
────┼─────────────┼──────────
  3 │ Foundation  │ t
```

**Agent/MCP angle:** Always use `WHERE id = ...` (PK) for single-row updates in agent writes. Using WHERE on a non-indexed column risks updating multiple rows.

---

## Exercise 6 — UPDATE multiple rows

**Goal:** Mark all books published before 1960 as unavailable (they are being archived).

**SQL:**
```sql
UPDATE books
SET    available = false
WHERE  year < 1960
RETURNING id, title, year, available;
```

**Expected result:** Foundation (1951), 1984 (1949), Brave New World (1932) — all set to false.

**Agent/MCP angle:** Before running a bulk UPDATE, an agent should first run `SELECT ... WHERE year < 1960` to confirm which rows will be affected.

---

## Exercise 7 — DELETE a row

**Goal:** Remove "Brave New World" from the catalog.

**SQL:**
```sql
DELETE FROM books
WHERE  id = 5
RETURNING id, title;
```

**Expected result:**
```
 id │ title
────┼─────────────────
  5 │ Brave New World
```

**Agent/MCP angle:** Use `RETURNING` on DELETE to log what was removed. Always DELETE by primary key unless the intent is a bulk deletion.

---

## Exercise 8 — Aggregate: statistics about the catalog

**Goal:** Compute summary statistics about the current book catalog.

**SQL:**
```sql
SELECT
    COUNT(*)                           AS total_books,
    COUNT(*) FILTER (WHERE available)  AS available_books,
    MIN(year)                          AS oldest_year,
    MAX(year)                          AS newest_year,
    ROUND(AVG(year))                   AS avg_year
FROM books;
```

**Expected result (will vary based on previous exercises):** One row with counts and year statistics.

**Agent/MCP angle:** Aggregate queries give an agent a quick "state of the world" summary without iterating rows in application code. An agent maintaining a library system would run this as a health check after each batch operation.
