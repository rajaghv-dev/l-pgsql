# Library Catalog Example

Level: Beginner
Domain: Book catalog with borrower checkout tracking
Synthetic data: Yes

## Overview

A two-table library catalog for a fictional branch called "Fernwood Public Library".
Demonstrates foreign keys, INNER JOIN, LEFT JOIN, date arithmetic, and the classic
"find unreturned items" pattern. This is a practical introduction to relational
thinking: one table holds the books, another holds borrowing events.

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

CREATE TABLE books (
    id          SERIAL PRIMARY KEY,
    title       TEXT    NOT NULL,
    author      TEXT    NOT NULL,
    isbn        TEXT    UNIQUE,
    year        INT     CHECK (year BETWEEN 1000 AND 2100),
    available   BOOLEAN NOT NULL DEFAULT TRUE   -- FALSE when currently on loan
);

CREATE TABLE checkouts (
    id              SERIAL PRIMARY KEY,
    book_id         INT         NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    borrower_name   TEXT        NOT NULL,
    checked_out_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    due_date        DATE        NOT NULL,
    returned_at     TIMESTAMPTZ             -- NULL means not yet returned
);

CREATE INDEX idx_checkouts_book_id     ON checkouts (book_id);
CREATE INDEX idx_checkouts_returned_at ON checkouts (returned_at) WHERE returned_at IS NULL;
```

## Seed data

```sql
-- Books
INSERT INTO books (title, author, isbn, year, available) VALUES
  ('The Midnight Library',        'Matt Haig',          '978-0-525-55947-4', 2020, FALSE),
  ('Project Hail Mary',           'Andy Weir',          '978-0-593-13520-4', 2021, TRUE),
  ('Klara and the Sun',           'Kazuo Ishiguro',     '978-0-571-36488-5', 2021, FALSE),
  ('The Thursday Murder Club',    'Richard Osman',      '978-0-241-42533-4', 2020, TRUE),
  ('Piranesi',                    'Susanna Clarke',     '978-1-5266-2138-0', 2020, FALSE),
  ('Normal People',               'Sally Rooney',       '978-0-571-33489-5', 2018, TRUE),
  ('Circe',                       'Madeline Miller',    '978-0-316-55634-7', 2018, TRUE),
  ('A Gentleman in Moscow',       'Amor Towles',        '978-0-670-02603-5', 2016, FALSE),
  ('The Song of Achilles',        'Madeline Miller',    '978-0-062-06044-6', 2012, TRUE),
  ('Anxious People',              'Fredrik Backman',    '978-1-250-27831-0', 2020, TRUE);

-- Checkouts (mix of returned and active)
INSERT INTO checkouts (book_id, borrower_name, checked_out_at, due_date, returned_at) VALUES
  -- Returned on time
  (2, 'Jordan Ellison',   NOW() - INTERVAL '30 days', CURRENT_DATE - 16, NOW() - INTERVAL '18 days'),
  (4, 'Morgan Liu',       NOW() - INTERVAL '45 days', CURRENT_DATE - 31, NOW() - INTERVAL '33 days'),
  (6, 'Casey Donovan',    NOW() - INTERVAL '20 days', CURRENT_DATE - 6,  NOW() - INTERVAL '8 days'),

  -- Active (not yet returned)
  (1, 'Alex Rivera',      NOW() - INTERVAL '14 days', CURRENT_DATE + 7,  NULL),   -- due in future
  (3, 'Sam Patel',        NOW() - INTERVAL '21 days', CURRENT_DATE - 7,  NULL),   -- OVERDUE
  (5, 'Taylor Brooks',    NOW() - INTERVAL '10 days', CURRENT_DATE + 11, NULL),   -- due in future
  (8, 'Jamie Ortega',     NOW() - INTERVAL '35 days', CURRENT_DATE - 21, NULL);   -- OVERDUE
```

## Example queries

### All books currently available

```sql
SELECT id, title, author, year
FROM   books
WHERE  available = TRUE
ORDER  BY title;
```

### All active checkouts with book details (INNER JOIN)

```sql
SELECT c.id        AS checkout_id,
       b.title,
       b.author,
       c.borrower_name,
       c.due_date,
       c.checked_out_at::DATE AS checked_out
FROM   checkouts c
JOIN   books     b ON b.id = c.book_id
WHERE  c.returned_at IS NULL
ORDER  BY c.due_date;
```

### Overdue books (due_date has passed and not returned)

```sql
SELECT b.title,
       c.borrower_name,
       c.due_date,
       CURRENT_DATE - c.due_date AS days_overdue
FROM   checkouts c
JOIN   books     b ON b.id = c.book_id
WHERE  c.returned_at IS NULL
  AND  c.due_date < CURRENT_DATE
ORDER  BY days_overdue DESC;
```

### Books never checked out (LEFT JOIN anti-pattern)

```sql
SELECT b.id, b.title, b.author
FROM   books     b
LEFT   JOIN checkouts c ON c.book_id = b.id
WHERE  c.id IS NULL
ORDER  BY b.title;
```

### Checkout history for a specific book

```sql
SELECT c.borrower_name,
       c.checked_out_at::DATE AS checked_out,
       c.due_date,
       c.returned_at::DATE    AS returned
FROM   checkouts c
WHERE  c.book_id = 2   -- Project Hail Mary
ORDER  BY c.checked_out_at DESC;
```

### Most borrowed books

```sql
SELECT b.title, b.author, COUNT(c.id) AS times_borrowed
FROM   books     b
LEFT   JOIN checkouts c ON c.book_id = b.id
GROUP  BY b.id, b.title, b.author
ORDER  BY times_borrowed DESC;
```

### Return a book (simulate returning book_id=1)

```sql
-- Step 1: mark the checkout as returned
UPDATE checkouts
SET    returned_at = NOW()
WHERE  book_id = 1
  AND  returned_at IS NULL;

-- Step 2: make the book available again
UPDATE books
SET    available = TRUE
WHERE  id = 1;
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- 1. Book count
SELECT COUNT(*) AS total_books FROM books;
-- Expected: 10

-- 2. Checkout count
SELECT COUNT(*) AS total_checkouts FROM checkouts;
-- Expected: 7

-- 3. Active (unreturned) checkouts
SELECT COUNT(*) AS active_checkouts FROM checkouts WHERE returned_at IS NULL;
-- Expected: 4

-- 4. Overdue count
SELECT COUNT(*) AS overdue
FROM checkouts
WHERE returned_at IS NULL AND due_date < CURRENT_DATE;
-- Expected: 2

-- 5. FK constraint works (should raise error)
-- INSERT INTO checkouts (book_id, borrower_name, due_date) VALUES (9999, 'Test', CURRENT_DATE);
```

## Practice tasks

1. **Find books by author.** Write a query that returns all books by 'Madeline Miller'.
   How many has she written in the catalog?

2. **Borrow a book.** Insert a checkout for book_id=7 (Circe). Update `books.available`
   to FALSE. Then verify both tables reflect the change.

3. **Overdue report.** Modify the overdue query to also show the borrower's email
   (pretend there is an `email` column — add it to the `checkouts` table with ALTER TABLE).

4. **Checkout frequency by borrower.** Which borrower has checked out the most books?
   Write a GROUP BY query over the `checkouts` table.

5. **Active loan duration.** For each unreturned book, calculate how many days it
   has been checked out (`CURRENT_DATE - checked_out_at::DATE`). Are any books
   overdue by more than 30 days?

## MCP and agent perspective

An agent acting as a library assistant via MCP would:

- **Check availability** before recommending a book — `WHERE available = TRUE`.
- **Record checkouts** — INSERT into `checkouts` and UPDATE `books.available = FALSE`
  in a transaction.
- **Run the overdue report daily** — surface a list of overdue books so staff can
  send reminders.
- **Process returns** — UPDATE both `checkouts.returned_at` and `books.available`
  atomically inside a transaction.
- **Answer browsing questions** — "Do you have any books by Madeline Miller that
  are currently available?"

The two-table design is the agent's first encounter with transaction safety:
both the checkout and the availability flag must change together.

## Teardown

```sql
DROP INDEX IF EXISTS idx_checkouts_returned_at;
DROP INDEX IF EXISTS idx_checkouts_book_id;
DROP TABLE IF EXISTS checkouts;
DROP TABLE IF EXISTS books;
```

## References

- PostgreSQL JOIN types: https://www.postgresql.org/docs/current/queries-table-expressions.html
- Date/Time functions: https://www.postgresql.org/docs/current/functions-datetime.html
- Foreign Keys: https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK
