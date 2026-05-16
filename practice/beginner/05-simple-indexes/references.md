# References: Simple Indexes

Topic-specific references for this practice session.

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|-----------|
| PostgreSQL docs — Indexes | https://www.postgresql.org/docs/current/indexes.html | Official docs | Beginner | 20 min | Index types, creation options |
| PostgreSQL docs — CREATE INDEX | https://www.postgresql.org/docs/current/sql-createindex.html | Official docs | Beginner | 15 min | Full syntax including CONCURRENTLY, partial |
| PostgreSQL docs — EXPLAIN | https://www.postgresql.org/docs/current/sql-explain.html | Official docs | Beginner | 15 min | Reading plan output |
| PostgreSQL docs — Using EXPLAIN | https://www.postgresql.org/docs/current/using-explain.html | Official docs | Intermediate | 30 min | Deep dive into cost model |
| Use The Index, Luke | https://use-the-index-luke.com/ | Free book | Beginner–Intermediate | Long | Best free resource on SQL indexing |
| Use The Index, Luke — Where Clause | https://use-the-index-luke.com/sql/where-clause | Free book | Beginner | 20 min | Selectivity and when indexes are used |
| PostgreSQL docs — Partial Indexes | https://www.postgresql.org/docs/current/indexes-partial.html | Official docs | Beginner | 10 min | When and how to use partial indexes |

---

## Further reading

After completing this practice session, continue with:

- `concepts/beginner/13-transactions-as-safe-change.md` — how indexes behave inside transactions
- `practice/beginner/06-simple-transactions/` — write operations that also update indexes
- `concepts/intermediate/` (future) — advanced index types: GIN for JSONB/FTS, GiST for ranges, covering indexes

---

## Reference quality note

All references in this file are free to access and verified relevant to index creation and EXPLAIN interpretation.
