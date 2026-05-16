-- Practice 09: pgvector Retrieval
-- STATUS: blocked — Docker not accessible in this session
-- Run with: docker exec cfp_postgres psql -U cfp -d cfp -f setup.sql
-- Note: vector extension IS available in cfp_postgres

CREATE EXTENSION IF NOT EXISTS vector;

DROP TABLE IF EXISTS documents CASCADE;

CREATE TABLE documents (
    id        SERIAL PRIMARY KEY,
    content   TEXT NOT NULL,
    category  TEXT NOT NULL,
    source    TEXT,
    embedding vector(3),  -- toy dimension; use 768+ in production
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- Synthetic embeddings — 3D vectors for learning
-- Technical documents cluster near [0.1-0.2, 0.7-0.9, 0.3-0.5]
-- Food documents cluster near [0.8-0.9, 0.1-0.2, 0.2-0.4]
-- ============================================================

INSERT INTO documents (content, category, source, embedding) VALUES
    ('PostgreSQL is a powerful relational database',     'technical', 'blog', '[0.10, 0.80, 0.30]'),
    ('SQL joins merge data from multiple tables',        'technical', 'docs', '[0.15, 0.85, 0.35]'),
    ('Indexes speed up query execution significantly',   'technical', 'blog', '[0.12, 0.78, 0.40]'),
    ('MVCC allows concurrent reads and writes',         'technical', 'docs', '[0.18, 0.82, 0.38]'),
    ('pgvector enables semantic similarity search',     'technical', 'blog', '[0.11, 0.75, 0.45]'),
    ('Full text search uses tsvector and tsquery',      'technical', 'docs', '[0.20, 0.70, 0.42]'),
    ('Coffee is a popular morning beverage worldwide',  'food',      'blog', '[0.85, 0.12, 0.22]'),
    ('Tea has many varieties including green and black', 'food',     'blog', '[0.82, 0.15, 0.25]'),
    ('Espresso is concentrated brewed coffee',          'food',      'wiki', '[0.88, 0.10, 0.20]'),
    ('Oat milk is a popular dairy alternative',         'food',      'blog', '[0.80, 0.18, 0.30]');

-- ============================================================
-- Index options (choose one for exercises)
-- ============================================================

-- HNSW index (best recall, recommended)
CREATE INDEX ON documents USING hnsw(embedding vector_cosine_ops);

-- IVFFlat alternative (uncomment to compare):
-- DROP INDEX IF EXISTS documents_embedding_idx;
-- CREATE INDEX ON documents USING ivfflat(embedding vector_l2_ops) WITH (lists = 5);

-- Verify
SELECT 'documents' AS tbl, COUNT(*) FROM documents
UNION ALL
SELECT 'technical', COUNT(*) FROM documents WHERE category = 'technical'
UNION ALL
SELECT 'food', COUNT(*) FROM documents WHERE category = 'food';
