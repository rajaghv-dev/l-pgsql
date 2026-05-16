# Examples

Generated: 2026-05-16  
Phase: 11

---

## Current status

Content examples (`examples/beginner/`, `examples/intermediate/`, `examples/advanced/`) are placeholder directories. They will be populated in Stages 15, 16, and 17 respectively.

The inline code examples in `arch.md` are the only runnable examples currently in the repo.

---

## Inline examples (arch.md)

All examples below can be run against the `cfp_postgres` container:

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "<SQL>"
```

---

## Example: pgvector — vector similarity search

### Purpose
Semantic memory retrieval, RAG document search.

### Command
```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    content TEXT,
    embedding vector(3)
);

CREATE INDEX IF NOT EXISTS documents_embedding_idx
    ON documents USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 1);

INSERT INTO documents (content, embedding) VALUES
    ('hello world', '[0.1, 0.2, 0.3]'),
    ('foo bar baz', '[0.9, 0.8, 0.7]');

SELECT content, embedding <=> '[0.1, 0.2, 0.4]'::vector AS distance
FROM documents
ORDER BY distance
LIMIT 5;
```

### Expected output
Two rows ordered by cosine distance to the query vector.

### Files used
Inline in `arch.md`. Will get a full practice session in `practice/intermediate/pgvector/`.

### What it teaches
Vector indexing, similarity operators, IVFFlat index parameters.

### Current status
Runnable — validated during Stage 0 (vector extension confirmed available).

---

## Example: pg_trgm — fuzzy search

### Purpose
Typo-tolerant search, user input correction.

### Command
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS products (name TEXT);
INSERT INTO products VALUES ('postgresql'), ('postgres'), ('postgis');
CREATE INDEX IF NOT EXISTS products_name_trgm_idx ON products USING gin (name gin_trgm_ops);

SELECT name, similarity(name, 'postgress') AS sim
FROM products
WHERE name % 'postgress'
ORDER BY sim DESC;
```

### Expected output
Rows matching the misspelled query, ordered by similarity score.

### Current status
Runnable — pg_trgm confirmed available.

---

## Example: pgcrypto — password hashing

### Purpose
Secure password storage in agent-managed tables.

### Command
```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS demo_users (
    email TEXT PRIMARY KEY,
    password_hash TEXT
);

INSERT INTO demo_users (email, password_hash)
VALUES ('alice@example.com', crypt('secret', gen_salt('bf')));

SELECT crypt('secret', password_hash) = password_hash AS valid
FROM demo_users
WHERE email = 'alice@example.com';
```

### Expected output
`valid = t`

### Current status
Runnable — pgcrypto confirmed available.

---

## Example: ltree — hierarchy

### Purpose
Hierarchical permission trees, org structures, category browsing.

### Command
```sql
CREATE EXTENSION IF NOT EXISTS ltree;

CREATE TABLE IF NOT EXISTS categories (path ltree, label TEXT);
INSERT INTO categories VALUES
    ('science', 'Science'),
    ('science.physics', 'Physics'),
    ('science.physics.quantum', 'Quantum Physics')
ON CONFLICT DO NOTHING;

SELECT * FROM categories WHERE path <@ 'science';
```

### Expected output
All three rows (all are descendants of `science`).

### Current status
Runnable — ltree confirmed available.

---

## Example: Row Level Security (RLS) — tenant isolation

### Purpose
Multi-tenant SaaS, per-user data isolation for agent writes.

### Command
```sql
CREATE TABLE IF NOT EXISTS tenant_documents (
    id SERIAL PRIMARY KEY,
    tenant_id INT NOT NULL,
    content TEXT
);

ALTER TABLE tenant_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_isolation ON tenant_documents;
CREATE POLICY tenant_isolation ON tenant_documents
    USING (tenant_id = current_setting('app.tenant_id')::int);

INSERT INTO tenant_documents (tenant_id, content)
VALUES (1, 'tenant 1 data'), (2, 'tenant 2 data');

SET app.tenant_id = '1';
SELECT * FROM tenant_documents;
```

### Expected output
Only the row with `tenant_id = 1`.

### What it teaches
RLS policy creation, `current_setting()`, session-scoped context variables.

### Current status
Runnable — requires superuser or table owner. `cfp` user has superuser privileges.

---

## Planned examples (Stages 15–17)

| Stage | Directory | Domain examples planned |
|---|---|---|
| 15 | `examples/beginner/` | E-commerce basics, library catalog, simple blog |
| 16 | `examples/intermediate/` | Multi-tenant SaaS, audit log, vector search app |
| 17 | `examples/advanced/` | Queue worker, MVCC demo, partitioned time-series |

All planned examples will use synthetic data. No real PII or production schemas.
