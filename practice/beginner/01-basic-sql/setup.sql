-- =============================================================================
-- Practice 01: Basic SQL — setup.sql
-- Idempotent: safe to run multiple times
-- =============================================================================
-- Run with:
--   docker exec -i cfp_postgres psql -U cfp -d cfp < practice/beginner/01-basic-sql/setup.sql
--
-- blocked: Docker not accessible; validate against cfp_postgres when available
-- =============================================================================

-- Create the books table if it does not already exist
CREATE TABLE IF NOT EXISTS books (
    id        BIGSERIAL   PRIMARY KEY,
    title     TEXT        NOT NULL,
    author    TEXT        NOT NULL,
    year      INTEGER     NOT NULL,
    available BOOLEAN     NOT NULL DEFAULT true
);

-- Seed data — ON CONFLICT DO NOTHING makes this idempotent
-- We check by id to avoid duplicates on repeated runs
INSERT INTO books (id, title, author, year, available) VALUES
    (1, 'Dune',            'Frank Herbert',  1965, true),
    (2, 'Neuromancer',     'William Gibson', 1984, true),
    (3, 'Foundation',      'Isaac Asimov',   1951, false),
    (4, '1984',            'George Orwell',  1949, true),
    (5, 'Brave New World', 'Aldous Huxley',  1932, false)
ON CONFLICT (id) DO NOTHING;

-- Reset the sequence to avoid conflicts when later inserts use BIGSERIAL
SELECT setval(pg_get_serial_sequence('books', 'id'), (SELECT MAX(id) FROM books));

-- Confirm the table and rows exist
SELECT id, title, author, year, available FROM books ORDER BY id;
