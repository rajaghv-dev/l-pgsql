# Extension Thinking Prompts

10+ questions about PostgreSQL extensions — when to choose them, why they work the way they do, and what trade-offs they carry.

---

## ltree vs Recursive CTEs

### Q: When would you choose ltree over a recursive CTE for hierarchical data?
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** A recursive CTE can traverse any parent-child relationship but requires a query per traversal. ltree stores the path as a string (`A.B.C.D`) and can use a GiST index for ancestor/descendant queries with pattern matching. What does ltree lose compared to a recursive CTE?  
**Reference:** [[diagrams/extension-ecosystem-map]]

---

### Q: ltree stores paths as strings like `A.B.C`. What happens when you need to rename a node in the middle of the tree?
**Type:** Critical  
**Level:** Advanced  
**Hint:** Renaming a node (e.g., `Electronics` → `Consumer Electronics`) requires updating all paths that contain that label. With a recursive adjacency list, you only update one row. What is the trade-off in write cost vs query cost?  
**Reference:** [[diagrams/extension-ecosystem-map]]

---

## pgvector

### Q: Why does pgvector need a special index — why not just sort by cosine distance and take the top K?
**Type:** First principles  
**Level:** Intermediate  
**Hint:** Exact nearest-neighbor search requires computing the distance from the query vector to every row. On a table with 10M vectors of 1,536 dimensions each, this is an enormous computation. What does an Approximate Nearest Neighbor (ANN) index trade for speed?  
**Reference:** [[diagrams/vector-search-flow]]

---

### Q: What is the difference between ivfflat and hnsw indexes in pgvector? When would you choose each?
**Type:** Critical  
**Level:** Advanced  
**Hint:** ivfflat partitions vectors into lists and searches a subset. hnsw builds a multi-layer graph and navigates from coarse to fine. Compare: build time, memory, update support, and recall at equivalent query time.  
**Reference:** [[diagrams/vector-search-flow]]

---

### Q: You embedded documents with model A and now want to switch to model B for higher quality. What is the migration strategy?
**Type:** Creative  
**Level:** Advanced  
**Hint:** Embeddings from different models are not comparable — you cannot mix them in the same index. What is the safe migration path? Consider: a dual-column approach, a background re-embedding job, and a cutover strategy that ensures no query uses mixed embeddings.  
**Reference:** [[diagrams/vector-search-flow]]

---

## pg_trgm

### Q: How does pg_trgm achieve fast LIKE '%pattern%' searches when B-tree indexes cannot?
**Type:** First principles  
**Level:** Intermediate  
**Hint:** Trigrams are overlapping 3-character substrings of a string (`"hello"` → `"  h"`, `" he"`, `"hel"`, `"ell"`, `"llo"`, `"lo "`). A GIN index stores which rows contain each trigram. When you search for `%ello%`, what trigrams does PostgreSQL generate to probe the index?  
**Reference:** [[diagrams/extension-ecosystem-map]]

---

### Q: pg_trgm similarity search and FTS full-text search both find relevant text. When would you use each?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** pg_trgm works on character-level similarity — it finds "simillar" when you search "similar" (typo tolerance). FTS works on word-level: it tokenizes, stems, and matches linguistic concepts. What does FTS do that pg_trgm cannot? What does pg_trgm do that FTS cannot?  
**Reference:** [[diagrams/sql-vs-non-sql-capability-map]]

---

## pgcrypto

### Q: pgcrypto's `crypt()` uses bcrypt. Why is bcrypt used for password hashing instead of SHA-256?
**Type:** First principles  
**Level:** Intermediate  
**Hint:** SHA-256 is designed to be fast. bcrypt is designed to be slow and configurable (the "cost" parameter). Why is slowness a feature for password hashing? What does the cost parameter control?  
**Reference:** [[design-principles/security-design-principles]] Principle 3

---

## pg_stat_statements

### Q: pg_stat_statements shows a query's `mean_exec_time` is 2ms. Is this query a problem?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** 2ms × 1 call/day = irrelevant. 2ms × 500,000 calls/day = 1,000 seconds of CPU time. What other columns in `pg_stat_statements` help you assess whether a fast query is still expensive at scale?  
**Reference:** [[diagrams/extension-ecosystem-map]]

---

### Q: Why does pg_stat_statements normalize query text (replacing literals with $1, $2)?
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** `SELECT * FROM users WHERE id = 1` and `SELECT * FROM users WHERE id = 2` are the same query pattern with different parameters. Normalization groups them as one entry. What would happen to the pg_stat_statements table size if it tracked each unique literal value?  
**Reference:** [[diagrams/extension-ecosystem-map]]

---

## unaccent and citext

### Q: What is the difference between `unaccent` and `citext` for case-insensitive, accent-insensitive search?
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** `citext` is a data type that stores text and compares case-insensitively. `unaccent` is a text search dictionary that removes accents. Can you index a `citext` column normally? Can you use `unaccent` in a B-tree index? How do they combine?  
**Reference:** [[diagrams/extension-ecosystem-map]]

---

### Q: You want to store user emails case-insensitively (alice@example.com and ALICE@example.com should be treated as the same). What are your options in PostgreSQL?
**Type:** Creative  
**Level:** Intermediate  
**Hint:** Options: `citext` type, a CHECK constraint that normalizes to lowercase before insert, a generated column `lower(email)` with UNIQUE, or an expression index `UNIQUE (lower(email))`. What are the trade-offs for each approach in terms of storage, query syntax, and ORM compatibility?  
**Reference:** [[diagrams/extension-ecosystem-map]], [[design-principles/intermediate-design-principles]] Principle 10
