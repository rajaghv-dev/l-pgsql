-- Practice 13: Ontology-Driven Schema Design
-- STATUS: blocked — Docker not accessible in this session
-- Run with: docker exec cfp_postgres psql -U cfp -d cfp -f setup.sql
--
-- This practice models a conference management domain using ontology-driven principles.
-- Entity types: Conference, Talk, Speaker (entities with identity)
-- Event types: Submission, Registration (events with timestamps)
-- Role type: Presenter (relationship with attributes)
-- Value type: Bio (embedded JSONB, no independent identity)
-- Hierarchy: Topic taxonomy with ltree

CREATE EXTENSION IF NOT EXISTS ltree;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

DROP TABLE IF EXISTS presentation_roles CASCADE;
DROP TABLE IF EXISTS registrations CASCADE;
DROP TABLE IF EXISTS submissions CASCADE;
DROP TABLE IF EXISTS talks CASCADE;
DROP TABLE IF EXISTS speakers CASCADE;
DROP TABLE IF EXISTS conferences CASCADE;
DROP TABLE IF EXISTS topics CASCADE;

-- ============================================================
-- Entities
-- ============================================================

CREATE TABLE topics (
    id    SERIAL PRIMARY KEY,
    name  TEXT NOT NULL UNIQUE,
    path  LTREE NOT NULL UNIQUE   -- ontological hierarchy
);
CREATE INDEX ON topics USING gist(path);

CREATE TABLE conferences (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    edition     INT NOT NULL DEFAULT 1,
    start_date  DATE NOT NULL,
    end_date    DATE NOT NULL,
    location    TEXT,
    website     TEXT,
    CHECK (end_date >= start_date),
    UNIQUE (name, edition)
);

CREATE TABLE speakers (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name   TEXT NOT NULL,
    email       TEXT UNIQUE NOT NULL,
    bio_data    JSONB,           -- value object: variable attributes
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE talks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conference_id   UUID NOT NULL REFERENCES conferences(id),
    topic_id        INT REFERENCES topics(id),
    title           TEXT NOT NULL,
    abstract        TEXT,
    duration_min    INT CHECK (duration_min > 0),
    status          TEXT NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft','accepted','rejected','scheduled')),
    -- FTS search vector
    search_vector   TSVECTOR GENERATED ALWAYS AS (
        setweight(to_tsvector('english', title), 'A') ||
        setweight(to_tsvector('english', COALESCE(abstract, '')), 'B')
    ) STORED,
    -- Semantic embedding (for similarity search)
    embedding       vector(3),   -- toy dim; 768 in production
    created_at      TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX ON talks USING gin(search_vector);
CREATE INDEX ON talks USING hnsw(embedding vector_cosine_ops);

-- ============================================================
-- Events (append-only, immutable)
-- ============================================================

CREATE TABLE submissions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    talk_id         UUID NOT NULL REFERENCES talks(id),
    speaker_id      UUID NOT NULL REFERENCES speakers(id),
    submitted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    decision        TEXT CHECK (decision IN ('accepted','rejected','pending')) DEFAULT 'pending',
    decided_at      TIMESTAMPTZ
);

CREATE TABLE registrations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conference_id   UUID NOT NULL REFERENCES conferences(id),
    speaker_id      UUID NOT NULL REFERENCES speakers(id),
    registered_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (conference_id, speaker_id)
);

-- ============================================================
-- Role (relationship with attributes)
-- ============================================================

CREATE TABLE presentation_roles (
    talk_id     UUID NOT NULL REFERENCES talks(id),
    speaker_id  UUID NOT NULL REFERENCES speakers(id),
    role        TEXT NOT NULL DEFAULT 'presenter'
                CHECK (role IN ('presenter','co-presenter','moderator')),
    PRIMARY KEY (talk_id, speaker_id)
);

-- ============================================================
-- Seed data
-- ============================================================

INSERT INTO topics (name, path) VALUES
    ('Technology',          'tech'),
    ('Databases',           'tech.db'),
    ('PostgreSQL',          'tech.db.postgres'),
    ('Performance',         'tech.db.postgres.perf'),
    ('Security',            'tech.db.postgres.security'),
    ('Machine Learning',    'tech.ml'),
    ('Vector Search',       'tech.ml.vector');

INSERT INTO conferences (id, name, edition, start_date, end_date, location) VALUES
    ('c0000001-0000-0000-0000-000000000001', 'PGConf', 2024, '2024-09-15', '2024-09-17', 'Berlin'),
    ('c0000002-0000-0000-0000-000000000002', 'PGDay', 2024, '2024-11-10', '2024-11-11', 'Online');

INSERT INTO speakers (id, full_name, email, bio_data) VALUES
    ('s0000001-0000-0000-0000-000000000001', 'Alice Chen',
     'alice@example.com',
     '{"company":"DataCo","years_experience":8,"github":"alicechen","specialties":["PostgreSQL","performance"]}'),
    ('s0000002-0000-0000-0000-000000000002', 'Bob Müller',
     'bob@example.com',
     '{"company":"VectorAI","years_experience":5,"github":"bmuller","specialties":["pgvector","ML"]}');

INSERT INTO talks (id, conference_id, topic_id, title, abstract, duration_min, status, embedding) VALUES
    ('t0000001-0000-0000-0000-000000000001',
     'c0000001-0000-0000-0000-000000000001', 4,
     'PostgreSQL Query Optimization Deep Dive',
     'A deep dive into EXPLAIN ANALYZE, index strategies, and autovacuum tuning.',
     45, 'accepted', '[0.10, 0.82, 0.35]'),
    ('t0000002-0000-0000-0000-000000000002',
     'c0000001-0000-0000-0000-000000000001', 7,
     'Semantic Search with pgvector',
     'Building RAG pipelines using pgvector, HNSW indexes, and local embedding models.',
     30, 'accepted', '[0.12, 0.70, 0.45]'),
    ('t0000003-0000-0000-0000-000000000003',
     'c0000002-0000-0000-0000-000000000002', 5,
     'Row Level Security for Multi-tenant SaaS',
     'Implementing tenant isolation using RLS policies and session context.',
     30, 'draft', '[0.18, 0.75, 0.38]');

INSERT INTO submissions (talk_id, speaker_id, decision) VALUES
    ('t0000001-0000-0000-0000-000000000001', 's0000001-0000-0000-0000-000000000001', 'accepted'),
    ('t0000002-0000-0000-0000-000000000002', 's0000002-0000-0000-0000-000000000002', 'accepted'),
    ('t0000003-0000-0000-0000-000000000003', 's0000001-0000-0000-0000-000000000001', 'pending');

INSERT INTO presentation_roles (talk_id, speaker_id, role) VALUES
    ('t0000001-0000-0000-0000-000000000001', 's0000001-0000-0000-0000-000000000001', 'presenter'),
    ('t0000002-0000-0000-0000-000000000002', 's0000002-0000-0000-0000-000000000002', 'presenter'),
    ('t0000002-0000-0000-0000-000000000002', 's0000001-0000-0000-0000-000000000001', 'co-presenter');

-- Verify
SELECT 'topics' AS tbl, COUNT(*) FROM topics
UNION ALL SELECT 'conferences', COUNT(*) FROM conferences
UNION ALL SELECT 'speakers', COUNT(*) FROM speakers
UNION ALL SELECT 'talks', COUNT(*) FROM talks
UNION ALL SELECT 'submissions', COUNT(*) FROM submissions
UNION ALL SELECT 'presentation_roles', COUNT(*) FROM presentation_roles;
