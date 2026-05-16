# Extensions as Capability Add-ons

Level: Beginner

## One-line intuition

An extension is a plugin that adds new data types, functions, operators, or index methods to PostgreSQL without modifying the core database.

## Why this exists

The PostgreSQL core is deliberately conservative. Specialized capabilities (vector math, cryptography, fuzzy text search, hierarchical data) are shipped as extensions — you add only what you need. This keeps the core lean and lets the ecosystem grow independently.

## First-principles explanation

An extension is a packaged collection of SQL objects (functions, types, operators, index classes, casts) installed into a specific database. Installing an extension:

1. Runs an SQL script that creates the objects.
2. Records the extension in `pg_extension` system catalog.
3. Ties the objects to the extension (DROP EXTENSION removes all of them cleanly).

Extensions are per-database — installed in one database, not visible in others.

## Micro-concepts

| Command | Purpose |
|---------|---------|
| `CREATE EXTENSION IF NOT EXISTS name` | Install an extension |
| `DROP EXTENSION name` | Remove an extension and all its objects |
| `SELECT * FROM pg_available_extensions` | List extensions available to install |
| `SELECT * FROM pg_extension` | List installed extensions |
| `\dx` (psql) | Short list of installed extensions |

## Beginner view

Think of PostgreSQL as a smartphone. The core OS does calls, texts, and basic apps. Extensions are App Store apps — you download only the ones you need. If you uninstall them, they leave no trace. Each phone (database) has its own installed apps.

```sql
-- See what is available
SELECT name, default_version, comment
FROM pg_available_extensions
ORDER BY name;

-- Install an extension
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Now pgcrypto functions are available in this database
SELECT gen_random_uuid();

-- Remove it cleanly
DROP EXTENSION pgcrypto;
```

## Intermediate view

**Key extensions (available in standard PostgreSQL builds):**

| Extension | Adds | Use case |
|-----------|------|---------|
| `pgvector` | `vector` type, `<->` operator | Semantic/similarity search |
| `pg_trgm` | Trigram similarity | Fuzzy text matching |
| `pgcrypto` | Hashing, encryption, UUID | Security, authentication |
| `uuid-ossp` | `uuid_generate_v4()` | UUID primary keys (prefer `gen_random_uuid()` in PG14+) |
| `ltree` | `ltree` type | Hierarchical/tree data (categories, org charts) |
| `hstore` | `hstore` type | Simple key-value (largely superseded by JSONB) |
| `pg_stat_statements` | Query statistics view | Performance monitoring |
| `unaccent` | `unaccent()` function | Remove accents for search normalization |
| `tablefunc` | `crosstab()`, `normal_rand()` | Pivot tables, random data |
| `intarray` | Array operators for int[] | Fast array operations |

**Extensions not available in the local stack (not installed in cfp_postgres):**

- `pg_cron` — requires superuser and a running background worker.
- `timescaledb` — a third-party extension; not installed by default.

## Advanced view

- Extensions can define new **index access methods** (e.g., `ivfflat` and `hnsw` from pgvector).
- Extensions can define new **base types** with their own storage and input/output functions.
- The `CREATE EXTENSION ... SCHEMA schema_name` option installs extension objects into a specific schema.
- Extension versions: `ALTER EXTENSION name UPDATE TO 'new_version'` upgrades without reinstalling.
- Trusted extensions (PostgreSQL 13+): can be installed by non-superusers if marked as trusted in the control file.

## Mental model

Extension = SQL script + compiled library (optional). The script creates functions, types, operators. The compiled library (a `.so` file) provides the C implementations. `CREATE EXTENSION` runs the script and loads the library. `DROP EXTENSION` reverses it.

## PostgreSQL view

```sql
-- Check what is installed
SELECT extname, extversion FROM pg_extension;

-- Check if pgvector is available
SELECT name, default_version
FROM pg_available_extensions
WHERE name = 'vector';

-- Install pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- Check functions added by an extension
SELECT p.proname AS function_name
FROM pg_proc p
JOIN pg_depend d ON d.objid = p.oid
JOIN pg_extension e ON e.oid = d.refobjid
WHERE e.extname = 'pgcrypto'
  AND d.deptype = 'e'
ORDER BY p.proname;
```

## SQL view

```sql
-- pgcrypto: hash a password (demonstration only — use application-level bcrypt in production)
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SELECT crypt('my_password', gen_salt('bf'));

-- uuid-ossp: generate a UUID (prefer gen_random_uuid() in PG14+ without extension)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
SELECT uuid_generate_v4();

-- pg_trgm: similarity search
CREATE EXTENSION IF NOT EXISTS pg_trgm;
SELECT similarity('PostgreSQL', 'Postgresql');  -- Returns: 0.9090...
SELECT word_similarity('postgres', 'postgresql databases');

-- ltree: hierarchical categories
CREATE EXTENSION IF NOT EXISTS ltree;
CREATE TABLE categories (id SERIAL PRIMARY KEY, path ltree);
INSERT INTO categories VALUES (1, 'Science.Physics.Quantum');
SELECT * FROM categories WHERE path <@ 'Science';  -- all Science subcategories
```

## Non-SQL or hybrid view

Extensions are analogous to npm packages for Node.js or PyPI packages for Python. The difference: they run inside the database process (not a separate service), so they have direct access to table data with zero network overhead.

## Design principle

**Install extensions intentionally.** Each extension adds surface area — more functions to secure, more library code in the database process. Only install what your application actually uses. Uninstall extensions that are no longer needed.

## Critical thinking

- Extensions must be installed per-database. If you have 10 databases and need pgvector in all of them, you must run `CREATE EXTENSION vector` in each one.
- Some extensions (pg_stat_statements, auto_explain) require `shared_preload_libraries` in `postgresql.conf` and a server restart. Check the extension docs before expecting `CREATE EXTENSION` to work on its own.

## Creative thinking

Build your own simple extension as a learning exercise: write a SQL file that creates a few helper functions, package it with a `.control` file, install it with `CREATE EXTENSION`. This demystifies what extensions are — they are just SQL + metadata.

## Systems thinking

Extensions move specialized computation into the database tier. This reduces the "impedance mismatch" between the application and the data — the computation runs where the data lives, avoiding data movement. The trade-off: the database becomes more complex and extension bugs affect database stability.

## MCP and agent perspective

An agent that needs semantic search uses pgvector's `<->` operator:

```sql
SELECT title, embedding <-> $1::vector AS distance
FROM documents
ORDER BY distance
LIMIT 5;
```

The extension makes this possible with one SQL query — no external search service required. The agent needs SELECT on the `documents` table and USAGE on the schema. No special extension-level permission is required at query time.

## Ontology perspective

- An extension is a **module** in the PostgreSQL type system — a named collection of database objects.
- `CREATE EXTENSION` is a **DDL operation** that changes the database schema.
- Extension objects are **owned by the extension** — they cannot be dropped individually; only via `DROP EXTENSION`.
- `pg_available_extensions` is a **catalog view** — it reflects what is installed on the OS, not what is enabled in the database.

## Practice session

Extensions are used in `practice/beginner/07-jsonb-basics/` (no extension needed — JSONB is built in) and `practice/beginner/08-views-and-functions-basics/` (uses built-in SQL functions). pgvector is introduced in `concepts/beginner/19-vector-search-intuition.md`.

## References

| Resource | URL | Why |
|----------|-----|-----|
| PostgreSQL docs — Extensions | https://www.postgresql.org/docs/current/extend-extensions.html | How extensions work internally |
| PostgreSQL docs — Packaged Extensions | https://www.postgresql.org/docs/current/contrib.html | Extensions bundled with PostgreSQL |
| PostgreSQL docs — CREATE EXTENSION | https://www.postgresql.org/docs/current/sql-createextension.html | Syntax and options |
| pgvector GitHub | https://github.com/pgvector/pgvector | Vector search extension |
| pg_trgm docs | https://www.postgresql.org/docs/current/pgtrgm.html | Fuzzy text search |
