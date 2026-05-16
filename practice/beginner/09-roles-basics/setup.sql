-- practice/beginner/09-roles-basics/setup.sql
-- Setup for role and permission basics practice.
-- validation: blocked — Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- Create a simple table for demonstrating role access
CREATE TABLE IF NOT EXISTS public.library_books (
    id BIGSERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    available BOOLEAN DEFAULT true
);

-- Seed data (synthetic)
INSERT INTO library_books (title, author, available) VALUES
    ('PostgreSQL: Up and Running', 'Regina Obe', true),
    ('The Art of PostgreSQL', 'Dimitri Fontaine', true),
    ('Database Design for Mere Mortals', 'Michael Hernandez', false)
ON CONFLICT DO NOTHING;

-- NOTE: Role creation requires superuser.
-- Run these interactively in the container:
--
--   CREATE ROLE readonly_user LOGIN PASSWORD 'readonly';
--   GRANT CONNECT ON DATABASE cfp TO readonly_user;
--   GRANT USAGE ON SCHEMA public TO readonly_user;
--   GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
--
-- Verify: connect as readonly_user and try INSERT (should fail).
