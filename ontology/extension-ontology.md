# Extension Ontology

Level: Intermediate
Domain: Extensions

## Definition
A PostgreSQL extension is a packaged set of SQL objects (functions, types, operators, indexes, views) that integrates with the database engine and can be installed with `CREATE EXTENSION`.

## Why this concept matters
Extensions are PostgreSQL's primary extensibility mechanism — they allow the core engine to remain lean while enabling specialized capabilities (full-text search, geospatial, vectors, encryption, foreign data) without leaving the database. Understanding the extension ecosystem helps you choose the right tool and understand its integration depth.

## Related concepts
- [[schema-design-ontology]] — parent (extensions install objects into schemas)
- [[vector-search-ontology]] — child (pgvector is an extension)
- [[geospatial-ontology]] — child (PostGIS is an extension)
- [[performance-ontology]] — related (pg_stat_statements is an extension)
- [[security-ontology]] — related (pgcrypto is an extension)

---

## What an extension is

An extension consists of:
1. A **control file** (`.control`) — name, version, dependencies, schema
2. A **SQL script** (`.sql`) — DDL to create the extension's objects
3. Optional **shared library** (`.so`) — C code for new types, index methods, functions

Extensions are versioned. `ALTER EXTENSION name UPDATE TO 'version'` upgrades in place.

### Create
```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA public;
```

### Inspect
```sql
-- blocked: Docker not accessible
SELECT * FROM pg_extension;
SELECT * FROM pg_available_extensions ORDER BY name;
SELECT * FROM pg_available_extension_versions WHERE name = 'pgvector';
```

### Modify
```sql
-- blocked: Docker not accessible
ALTER EXTENSION pgvector UPDATE TO '0.8.0';
```

### Remove
```sql
-- blocked: Docker not accessible
DROP EXTENSION IF EXISTS pgvector CASCADE;
```

---

## Extension categories

### Search and full-text
| Extension | Purpose |
|-----------|---------|
| `pg_trgm` | Trigram similarity search; powers ILIKE optimization |
| `unaccent` | Strip accents for locale-insensitive search |
| `dict_ispell` | Custom dictionary for full-text search |

Related: [[sql-ontology]] (WHERE LIKE patterns), [[index-ontology]] (GIN indexes for full-text)

---

### Indexing
| Extension | Purpose |
|-----------|---------|
| `bloom` | Probabilistic multi-column index; small but has false positives |
| `btree_gin` | Adds B-tree operators to GIN indexes |
| `btree_gist` | Adds B-tree operators to GiST indexes for exclusion constraints |

Related: [[index-ontology]]

---

### Security and encryption
| Extension | Purpose |
|-----------|---------|
| `pgcrypto` | Symmetric/asymmetric encryption, hashing, UUID generation |
| `sslinfo` | Inspect SSL connection properties |

Related: [[security-ontology]]

---

### Geospatial
| Extension | Purpose |
|-----------|---------|
| `PostGIS` | Geometry/geography types, spatial indexes, spatial functions |
| `address_standardizer` | Normalize address strings |

Related: [[geospatial-ontology]]

Note: PostGIS is not available in this local environment.

---

### Data types
| Extension | Purpose |
|-----------|---------|
| `hstore` | Key-value pairs stored in a single column |
| `ltree` | Label trees; hierarchy path queries |
| `citext` | Case-insensitive text type |
| `isn` | International standard numbers (ISBN, ISSN, EAN) |

Related: [[schema-design-ontology]]

---

### Observability and performance
| Extension | Purpose |
|-----------|---------|
| `pg_stat_statements` | Per-query cumulative execution statistics |
| `pg_buffercache` | Inspect shared buffer cache contents |
| `auto_explain` | Log slow query plans automatically |
| `pg_prewarm` | Pre-load relation data into buffer cache |

Related: [[observability-ontology]], [[performance-ontology]]

---

### Foreign data
| Extension | Purpose |
|-----------|---------|
| `postgres_fdw` | Access remote PostgreSQL instances |
| `file_fdw` | Read flat files as tables |
| `redis_fdw` | Access Redis from SQL |

Related: [[schema-design-ontology]]

---

### Vector and AI
| Extension | Purpose |
|-----------|---------|
| `pgvector` | Vector type, L2/cosine/IP distance, ivfflat and hnsw indexes |

Related: [[vector-search-ontology]], [[ai-agent-memory-ontology]]

---

## System catalog reference
- `pg_extension` — installed extensions
- `pg_available_extensions` — extensions available on the server
- `pg_available_extension_versions` — all versions of available extensions
- `pg_depend` — dependency graph (extension objects depend on the extension)

---

## Beginner mental model
An extension is like an app you install into your database. After `CREATE EXTENSION`, new functions, types, and operators become available as if they were built in.

## Intermediate mental model
Extensions are schema-aware — objects are created in a target schema (default: the first schema in `search_path`). Extensions can have dependencies on other extensions (`requires` in the control file). The shared library (`.so`) is loaded at session start when the extension's functions are called.

## Advanced mental model
Extensions participate in the catalog dependency system: `pg_depend` tracks which catalog objects belong to which extension, enabling clean `DROP EXTENSION CASCADE`. Custom index access methods (like `ivfflat`) register in `pg_am` and integrate with the planner's cost model. A poorly written extension with an unoptimized cost function can corrupt planner estimates.

## MCP and agent perspective
An agent querying `pg_available_extensions` can discover what capabilities are present. `CREATE EXTENSION` requires SUPERUSER or at minimum the `pg_extension_owner_member` role in PostgreSQL 15+. Agents should check extension availability before emitting extension-dependent SQL. Extension version mismatches (e.g., pgvector 0.4 vs 0.8 index types) can cause silent failures.

## Practical implication
| Situation | Implication |
|-----------|-------------|
| Extension not in `pg_extension` | SQL using its types/functions will error at parse time |
| Extension installed in wrong schema | Functions not visible unless schema is in `search_path` |
| Extension update changes behavior | Test after `ALTER EXTENSION ... UPDATE` |
| `DROP EXTENSION CASCADE` | Drops all dependent objects — can delete data |
| Extension requires shared library | Server reload or reconnect may be needed after install |

## Obsidian connections
[[schema-design-ontology]] [[index-ontology]] [[security-ontology]] [[observability-ontology]] [[performance-ontology]] [[vector-search-ontology]] [[geospatial-ontology]] [[ai-agent-memory-ontology]]

## References
- PostgreSQL Extensions: https://www.postgresql.org/docs/16/extend-extensions.html
- PGXN (extension network): https://pgxn.org
