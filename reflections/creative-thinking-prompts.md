# Creative Thinking Prompts

10+ open-ended design questions. There is no single correct answer — the goal is to think through trade-offs, constraints, and alternatives.

---

## System Design

### Q: How would you design a PostgreSQL schema for a social network with 1 billion users?
**Type:** Creative  
**Level:** Advanced  
**Hint:** Start with the core entities: users, posts, follows, likes. Which tables will be hot? Which relationships are expensive to query (followers of followers)? Consider: partitioning, denormalization for feed queries, read replicas, materialized views for counts, and whether PostgreSQL is the right store for every piece of data.  
**Reference:** [[design-principles/advanced-design-principles]], [[design-principles/schema-design-principles]]

---

### Q: Design a work queue using only PostgreSQL — no Redis, no RabbitMQ.
**Type:** Creative  
**Level:** Intermediate  
**Hint:** You need: jobs table, status transitions, worker assignment without conflicts, retry handling for failed jobs, and dead letter queue for permanent failures. Which PostgreSQL features handle each requirement? Consider: `SKIP LOCKED`, `FOR UPDATE`, `CHECK` constraints on status transitions, partial indexes for pending jobs.  
**Reference:** [[design-principles/concurrency-design-principles]] Principle 1, [[diagrams/transaction-mvcc-flow]]

---

### Q: Design a rate limiter using only PostgreSQL — without any application-side caching.
**Type:** Creative  
**Level:** Advanced  
**Hint:** You need: count requests per user per time window, enforce a maximum, and reset at window boundaries. Consider: a table per time bucket vs a rolling window with timestamps; INSERT with conflict on (user_id, window); partial indexes; cleanup of old windows; performance at 10,000 requests/second.  
**Reference:** [[design-principles/transaction-design-principles]], [[design-principles/concurrency-design-principles]]

---

### Q: How would you design a multi-tenant SaaS database where each tenant's data is completely isolated?
**Type:** Creative  
**Level:** Advanced  
**Hint:** Three approaches: separate databases per tenant, separate schemas per tenant, or shared tables with RLS. What are the trade-offs for each in terms of isolation, cross-tenant reporting, migration complexity, and connection pooling?  
**Reference:** [[design-principles/security-design-principles]] Principle 2, [[design-principles/mcp-tool-design-principles]]

---

### Q: Design a version-controlled document system in PostgreSQL — every edit creates a new version, old versions are queryable.
**Type:** Creative  
**Level:** Intermediate  
**Hint:** Consider: storing full copies vs diffs; a `versions` table with `document_id`, `version_number`, `content`, `created_at`; efficient querying of "latest version" without reading all versions; storage implications for large documents. How does JSONB `||` help for partial updates?  
**Reference:** [[design-principles/schema-design-principles]], [[diagrams/sql-vs-non-sql-capability-map]]

---

### Q: You need to store a product catalog with arbitrarily nested categories (Electronics > Computers > Laptops > Gaming Laptops). Design the schema.
**Type:** Creative  
**Level:** Intermediate  
**Hint:** Three approaches: adjacency list (parent_id FK), closure table (all ancestor-descendant pairs), or ltree paths. Evaluate each for: "find all descendants", "find breadcrumb path", "move a subtree", and "count products in category and all subcategories".  
**Reference:** [[diagrams/extension-ecosystem-map]], [[reflections/extension-thinking-prompts]]

---

### Q: Design a leaderboard system that updates in real time for a game with 100,000 concurrent players.
**Type:** Creative  
**Level:** Advanced  
**Hint:** You need: fast writes for score updates, fast reads for "top 100", "player rank", and "players near me in rank". Consider: materialized views with scheduled refresh vs real-time views; window functions for rank; partial indexes for top-N; whether you need exact rank or approximate rank.  
**Reference:** [[design-principles/query-design-principles]], [[design-principles/indexing-design-principles]]

---

### Q: Design an audit trail for a financial system where every change to an account balance must be traceable, irrevocable, and queryable.
**Type:** Creative  
**Level:** Advanced  
**Hint:** Append-only ledger vs mutable balance + trigger log. Which is "more correct"? How do you prevent balance manipulation? Consider: BEFORE trigger with balance verification, a `transactions` table (not an `audit_log`), idempotency keys, and constraint that `sum of transactions = current balance`.  
**Reference:** [[design-principles/security-design-principles]] Principle 4, [[design-principles/transaction-design-principles]]

---

### Q: How would you build a full-text search system in PostgreSQL that handles 10 million documents in multiple languages?
**Type:** Creative  
**Level:** Advanced  
**Hint:** You need: language-specific text search configurations, stored tsvectors for performance, GIN index, partial updates when documents change, relevance ranking, and handling of queries with accents or synonyms. When does FTS stop being sufficient and pgvector become necessary?  
**Reference:** [[diagrams/hybrid-search-flow]], [[diagrams/extension-ecosystem-map]]

---

### Q: Design a feature flag system where flags can be toggled per user, per company, or globally, with percentage rollouts.
**Type:** Creative  
**Level:** Intermediate  
**Hint:** Entities: flags, flag_rules (global/company/user), rollout_percentage. How do you check a flag for a user efficiently? Consider: JSONB for flag configuration vs normalized tables; caching in application vs database; ensuring consistency when a flag is partially rolled out.  
**Reference:** [[diagrams/sql-vs-non-sql-capability-map]], [[design-principles/schema-design-principles]]

---

### Q: You need to build a geospatial "nearby stores" feature without using PostGIS. How close can you get with core PostgreSQL?
**Type:** Creative  
**Level:** Advanced  
**Hint:** `earthdistance` and `cube` are bundled extensions. What do they provide? How would you calculate great-circle distance? How would you index it without PostGIS geometry types? At what point does the approximation error become unacceptable?  
**Reference:** [[diagrams/extension-ecosystem-map]], [[diagrams/sql-vs-non-sql-capability-map]]
