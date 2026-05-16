-- Practice 07: Full-Text Search and Fuzzy Search
-- STATUS: blocked — Docker not accessible in this session
-- Run with: docker exec cfp_postgres psql -U cfp -d cfp -f setup.sql

CREATE EXTENSION IF NOT EXISTS pg_trgm;

DROP TABLE IF EXISTS article_tags CASCADE;
DROP TABLE IF EXISTS tags CASCADE;
DROP TABLE IF EXISTS articles CASCADE;

CREATE TABLE articles (
    id            SERIAL PRIMARY KEY,
    title         TEXT NOT NULL,
    body          TEXT NOT NULL,
    language      REGCONFIG NOT NULL DEFAULT 'english',
    author        TEXT NOT NULL,
    published_at  DATE NOT NULL DEFAULT CURRENT_DATE,
    search_vector TSVECTOR GENERATED ALWAYS AS (
        setweight(to_tsvector(language::regconfig, title), 'A') ||
        setweight(to_tsvector(language::regconfig, body), 'B')
    ) STORED
);

CREATE TABLE tags (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE article_tags (
    article_id INT REFERENCES articles(id) ON DELETE CASCADE,
    tag_id     INT REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (article_id, tag_id)
);

-- GIN index for FTS
CREATE INDEX ON articles USING gin(search_vector);

-- GIN trigram index for fuzzy title search
CREATE INDEX ON articles USING gin(title gin_trgm_ops);

-- ============================================================
-- Seed data — synthetic articles
-- ============================================================

INSERT INTO articles (title, body, author, published_at) VALUES
    ('PostgreSQL Performance Tuning',
     'Optimizing PostgreSQL involves understanding the query planner, using EXPLAIN ANALYZE, and tuning autovacuum. Index selection is critical for read performance.',
     'Alice', '2024-01-15'),

    ('Introduction to JSONB in PostgreSQL',
     'JSONB is a binary JSON format that supports GIN indexing. It allows flexible schema design while maintaining query performance. Use operators like @> for containment checks.',
     'Bob', '2024-02-20'),

    ('Understanding MVCC and Vacuum',
     'Multi-Version Concurrency Control allows PostgreSQL to provide consistent reads without blocking writes. Dead tuples accumulate after updates and deletes; vacuum reclaims space.',
     'Alice', '2024-03-10'),

    ('Full Text Search in PostgreSQL',
     'PostgreSQL provides built-in full text search using tsvector and tsquery types. The GIN index accelerates text search queries. Use ts_rank for relevance ranking.',
     'Carol', '2024-04-05'),

    ('Row Level Security for Multi-tenant Applications',
     'RLS allows you to enforce data isolation at the database level using policies. Set the tenant context with current_setting and define policies per table.',
     'Dave', '2024-05-01'),

    ('Using pgvector for Semantic Search',
     'pgvector extends PostgreSQL with vector similarity search. Store embeddings as vector columns and use operators like <=> for cosine distance. HNSW indexes provide fast ANN retrieval.',
     'Eve', '2024-06-15'),

    ('Database Transactions and Isolation Levels',
     'Isolation levels control how concurrent transactions see each other. SERIALIZABLE prevents anomalies but requires retry logic. REPEATABLE READ suits most reporting workloads.',
     'Bob', '2024-07-20'),

    ('Monitoring PostgreSQL with pg_stat_statements',
     'pg_stat_statements tracks query execution statistics including total time, calls, and rows. Use it to identify slow queries and optimize index usage.',
     'Carol', '2024-08-10');

INSERT INTO tags (name) VALUES
    ('performance'), ('jsonb'), ('mvcc'), ('full-text-search'),
    ('security'), ('vector'), ('transactions'), ('monitoring');

INSERT INTO article_tags (article_id, tag_id) VALUES
    (1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (8, 8);

-- Verify
SELECT 'articles' AS tbl, COUNT(*) FROM articles
UNION ALL
SELECT 'tags', COUNT(*) FROM tags;
