# References: JSONB Basics

Topic-specific references for this practice session.

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|-----------|
| PostgreSQL docs — JSON Types | https://www.postgresql.org/docs/current/datatype-json.html | Official docs | Beginner | 20 min | JSONB vs JSON, storage, operators |
| PostgreSQL docs — JSON Functions | https://www.postgresql.org/docs/current/functions-json.html | Official docs | Beginner | 20 min | Full operator and function list |
| PostgreSQL docs — GIN Indexes | https://www.postgresql.org/docs/current/gin.html | Official docs | Intermediate | 15 min | GIN index internals, operator classes |
| Crunchy Data — JSONB Guide | https://www.crunchydata.com/blog/unleashing-the-power-of-storing-json-in-postgres | Article | Beginner | 15 min | Practical patterns and examples |
| PostgreSQL docs — jsonb_path_ops | https://www.postgresql.org/docs/current/datatype-json.html#JSON-INDEXING | Official docs | Intermediate | 10 min | Smaller GIN index for containment only |

---

## Further reading

After completing this practice session, continue with:

- `practice/beginner/08-views-and-functions-basics/` — create views that simplify JSONB queries
- `concepts/beginner/17-extensions-as-capability-addons.md` — pg_trgm for fuzzy search within JSONB text values
- `concepts/beginner/19-vector-search-intuition.md` — pgvector as an alternative to JSONB for ML embedding storage
