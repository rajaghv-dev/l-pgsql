-- Practice: JSONB Basics
-- Level: Beginner
-- Session: 07-jsonb-basics
-- blocked: Docker not accessible; validate against cfp_postgres

-- ---------------------------------------------------------------
-- Clean slate
-- ---------------------------------------------------------------
DROP TABLE IF EXISTS user_profiles;

-- ---------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------
CREATE TABLE user_profiles (
    id       SERIAL PRIMARY KEY,
    username TEXT   NOT NULL UNIQUE,
    metadata JSONB
);

-- ---------------------------------------------------------------
-- Seed: 5 synthetic rows with varied JSONB shapes
-- ---------------------------------------------------------------
INSERT INTO user_profiles (username, metadata) VALUES
    ('alice',
     '{"age": 29, "plan": "pro", "tags": ["admin", "beta"], "location": {"city": "London", "country": "GB"}}'),
    ('bob',
     '{"age": 34, "plan": "free", "tags": ["user"], "location": {"city": "Berlin", "country": "DE"}}'),
    ('charlie',
     '{"age": 22, "plan": "pro", "tags": ["user", "early-adopter"], "location": {"city": "Tokyo", "country": "JP"}}'),
    ('diana',
     '{"age": 41, "plan": "enterprise", "tags": ["admin"], "preferences": {"theme": "dark", "lang": "en"}}'),
    ('eve',
     '{"age": 27, "plan": "free", "tags": ["user"], "location": {"city": "Sydney", "country": "AU"}}');

-- ---------------------------------------------------------------
-- Verify: basic retrieval
-- ---------------------------------------------------------------
SELECT id, username, metadata FROM user_profiles ORDER BY id;

-- ---------------------------------------------------------------
-- Demo 1: extract a top-level field as text
-- ---------------------------------------------------------------
SELECT username, metadata->>'plan' AS plan FROM user_profiles;

-- ---------------------------------------------------------------
-- Demo 2: filter by nested JSONB value
-- ---------------------------------------------------------------
SELECT username FROM user_profiles
WHERE metadata->>'plan' = 'pro';

-- ---------------------------------------------------------------
-- Demo 3: navigate nested object
-- ---------------------------------------------------------------
SELECT username,
       metadata->'location'->>'city'    AS city,
       metadata->'location'->>'country' AS country
FROM user_profiles
WHERE metadata ? 'location';

-- ---------------------------------------------------------------
-- Demo 4: check tag array contains a value
-- ---------------------------------------------------------------
SELECT username
FROM user_profiles
WHERE metadata->'tags' ? 'admin';
