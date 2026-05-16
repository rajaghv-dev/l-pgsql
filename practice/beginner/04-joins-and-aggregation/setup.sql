-- Practice: JOINs and Aggregation
-- Level: Beginner
-- Purpose: Library catalog schema with authors, books, and checkouts.
-- Run with: docker exec cfp_postgres psql -U cfp -d cfp -f /path/to/setup.sql
-- blocked: Docker not accessible; validate against cfp_postgres when available

-- ─── Tear down (idempotent re-run) ────────────────────────────────────────────
DROP TABLE IF EXISTS checkouts CASCADE;
DROP TABLE IF EXISTS books CASCADE;
DROP TABLE IF EXISTS authors CASCADE;

-- ─── Schema ───────────────────────────────────────────────────────────────────
CREATE TABLE authors (
    id         SERIAL PRIMARY KEY,
    name       TEXT NOT NULL,
    birth_year INT
);

COMMENT ON TABLE authors IS 'Authors in the library catalog.';
COMMENT ON COLUMN authors.name IS 'Full name of the author.';

CREATE TABLE books (
    id             SERIAL PRIMARY KEY,
    title          TEXT NOT NULL,
    author_id      INT REFERENCES authors(id),
    published_year INT,
    pages          INT
);

COMMENT ON TABLE books IS 'Books in the library catalog.';
COMMENT ON COLUMN books.author_id IS 'FK → authors.id. NULL = unknown author.';

CREATE TABLE checkouts (
    id             SERIAL PRIMARY KEY,
    book_id        INT NOT NULL REFERENCES books(id),
    patron_id      INT NOT NULL,
    checked_out_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    returned_at    TIMESTAMPTZ
);

COMMENT ON TABLE checkouts IS 'Patron checkout records.';
COMMENT ON COLUMN checkouts.returned_at IS 'NULL = currently checked out.';

-- ─── Indexes on foreign keys ───────────────────────────────────────────────────
CREATE INDEX idx_books_author_id   ON books (author_id);
CREATE INDEX idx_checkouts_book_id ON checkouts (book_id);

-- ─── Seed: Authors ─────────────────────────────────────────────────────────────
INSERT INTO authors (name, birth_year) VALUES
    ('Isaac Asimov',    1920),
    ('Frank Herbert',   1920),
    ('Ursula K. Le Guin', 1929),
    ('Arthur C. Clarke', 1917),
    ('Philip K. Dick',  1928),
    ('Octavia Butler',  1947);

-- ─── Seed: Books (some with NULL author_id to enable LEFT JOIN exercises) ──────
INSERT INTO books (title, author_id, published_year, pages) VALUES
    ('Foundation',                 1, 1951, 244),
    ('Foundation and Empire',      1, 1952, 247),
    ('Second Foundation',          1, 1953, 256),
    ('Dune',                       2, 1965, 412),
    ('Dune Messiah',               2, 1969, 272),
    ('The Left Hand of Darkness',  3, 1969, 286),
    ('The Dispossessed',           3, 1974, 341),
    ('2001: A Space Odyssey',      4, 1968, 221),
    ('Rendezvous with Rama',       4, 1973, 243),
    ('Do Androids Dream?',         5, 1968, 210),
    ('The Man in the High Castle', 5, 1962, 249),
    ('Kindred',                    6, 1979, 287),
    ('Parable of the Sower',       6, 1993, 329),
    ('Anonymous Classic',       NULL, 1890, 180);  -- no known author, for LEFT JOIN demo

-- ─── Seed: Checkouts ──────────────────────────────────────────────────────────
-- Several books have multiple checkouts; some books have no checkouts (for LEFT JOIN)
INSERT INTO checkouts (book_id, patron_id, checked_out_at, returned_at) VALUES
    (1,  101, now() - INTERVAL '60 days',  now() - INTERVAL '39 days'),   -- Foundation, returned
    (1,  102, now() - INTERVAL '30 days',  now() - INTERVAL '9 days'),    -- Foundation, returned
    (1,  103, now() - INTERVAL '7 days',   NULL),                          -- Foundation, still out
    (2,  101, now() - INTERVAL '45 days',  now() - INTERVAL '24 days'),
    (3,  104, now() - INTERVAL '20 days',  now() - INTERVAL '6 days'),
    (4,  102, now() - INTERVAL '90 days',  now() - INTERVAL '69 days'),
    (4,  105, now() - INTERVAL '15 days',  NULL),                          -- Dune, still out
    (5,  103, now() - INTERVAL '50 days',  now() - INTERVAL '36 days'),
    (6,  106, now() - INTERVAL '25 days',  now() - INTERVAL '11 days'),
    (7,  101, now() - INTERVAL '10 days',  NULL),                          -- Dispossessed, still out
    (8,  107, now() - INTERVAL '35 days',  now() - INTERVAL '21 days'),
    (10, 102, now() - INTERVAL '40 days',  now() - INTERVAL '26 days'),
    (12, 108, now() - INTERVAL '55 days',  now() - INTERVAL '34 days'),
    (13, 101, now() - INTERVAL '5 days',   NULL);                          -- Parable, still out
-- Books 9, 11, 14 have no checkouts (for LEFT JOIN exercises)

-- ─── Verification ─────────────────────────────────────────────────────────────
DO $$
BEGIN
    ASSERT (SELECT COUNT(*) FROM authors) = 6,
        'Expected 6 authors';
    ASSERT (SELECT COUNT(*) FROM books) = 14,
        'Expected 14 books';
    ASSERT (SELECT COUNT(*) FROM checkouts) = 14,
        'Expected 14 checkouts';
    RAISE NOTICE 'setup.sql: OK — % authors, % books, % checkouts',
        (SELECT COUNT(*) FROM authors),
        (SELECT COUNT(*) FROM books),
        (SELECT COUNT(*) FROM checkouts);
END;
$$;
