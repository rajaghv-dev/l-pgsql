-- Practice: Views and Functions Basics
-- Level: Beginner
-- Session: 08-views-and-functions-basics
-- blocked: Docker not accessible; validate against cfp_postgres

-- ---------------------------------------------------------------
-- Clean slate
-- ---------------------------------------------------------------
DROP VIEW  IF EXISTS available_books;
DROP VIEW  IF EXISTS active_checkouts;
DROP FUNCTION IF EXISTS days_overdue(DATE);
DROP TABLE IF EXISTS checkouts;
DROP TABLE IF EXISTS books;

-- ---------------------------------------------------------------
-- Schema: library catalog theme
-- ---------------------------------------------------------------
CREATE TABLE books (
    id          SERIAL PRIMARY KEY,
    title       TEXT        NOT NULL,
    author      TEXT        NOT NULL,
    genre       TEXT,
    year        INT,
    total_copies INT NOT NULL DEFAULT 1 CHECK (total_copies > 0)
);

CREATE TABLE checkouts (
    id           SERIAL PRIMARY KEY,
    book_id      INT  NOT NULL REFERENCES books(id),
    patron_name  TEXT NOT NULL,
    checked_out  DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date     DATE NOT NULL,
    returned_at  DATE
);

-- ---------------------------------------------------------------
-- Seed: books
-- ---------------------------------------------------------------
INSERT INTO books (title, author, genre, year, total_copies) VALUES
    ('The Pragmatic Programmer',  'Hunt & Thomas',  'Technology', 1999, 3),
    ('Designing Data-Intensive Applications', 'Kleppmann', 'Technology', 2017, 2),
    ('Dune',                      'Frank Herbert',  'Sci-Fi',     1965, 4),
    ('Thinking, Fast and Slow',   'Kahneman',       'Psychology', 2011, 2),
    ('The Left Hand of Darkness', 'Le Guin',        'Sci-Fi',     1969, 1);

-- ---------------------------------------------------------------
-- Seed: checkouts (mix of active and returned)
-- ---------------------------------------------------------------
INSERT INTO checkouts (book_id, patron_name, checked_out, due_date, returned_at) VALUES
    (1, 'Alice',   '2026-04-01', '2026-04-15', '2026-04-13'),
    (1, 'Bob',     '2026-04-20', '2026-05-04', NULL),
    (2, 'Charlie', '2026-04-10', '2026-04-24', NULL),
    (3, 'Diana',   '2026-03-01', '2026-03-15', '2026-03-14'),
    (4, 'Eve',     '2026-05-01', '2026-05-15', NULL);

-- ---------------------------------------------------------------
-- View 1: books currently available (no active checkout)
-- ---------------------------------------------------------------
CREATE VIEW available_books AS
SELECT b.id, b.title, b.author, b.genre
FROM books b
WHERE b.id NOT IN (
    SELECT book_id FROM checkouts WHERE returned_at IS NULL
);

-- ---------------------------------------------------------------
-- View 2: active checkouts with book title joined in
-- ---------------------------------------------------------------
CREATE VIEW active_checkouts AS
SELECT
    c.id            AS checkout_id,
    b.title,
    c.patron_name,
    c.checked_out,
    c.due_date
FROM checkouts c
JOIN books b ON b.id = c.book_id
WHERE c.returned_at IS NULL;

-- ---------------------------------------------------------------
-- Function: days overdue (negative means still on time)
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION days_overdue(due DATE)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT (CURRENT_DATE - due)::INT;
$$;

-- ---------------------------------------------------------------
-- Verify
-- ---------------------------------------------------------------
SELECT 'available_books' AS view_name, count(*) FROM available_books;
SELECT 'active_checkouts' AS view_name, count(*) FROM active_checkouts;
SELECT patron_name, title, due_date, days_overdue(due_date) AS days_overdue
FROM active_checkouts
ORDER BY due_date;
