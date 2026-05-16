# Critical Thinking Prompts

15+ questions that challenge common assumptions and cargo-cult patterns in PostgreSQL and SQL design.

---

## Normalization

### Q: Is normalization always good? What are the legitimate reasons to denormalize?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** Normalization reduces redundancy and update anomalies. But what does it cost at read time? When does a join across 5 tables on 100M rows become more expensive than duplication?  
**Reference:** [[design-principles/intermediate-design-principles]] Principle 1

---

### Q: A database is in 3NF. Is it automatically a good schema? What does 3NF not address?
**Type:** Critical  
**Level:** Advanced  
**Hint:** 3NF addresses functional dependencies. Does it address query performance? Does it address column naming? Does it prevent storing NULLs where values should always be present?  
**Reference:** [[design-principles/schema-design-principles]]

---

## Indexes

### Q: Should every column have an index? What happens to a write-heavy table if you index every column?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** Consider a table with 20 columns and 20 indexes. Every INSERT, UPDATE, and DELETE must update all indexes that cover changed columns. What is the I/O and lock overhead?  
**Reference:** [[design-principles/indexing-design-principles]]

---

### Q: Is an index always faster than a sequential scan? Give a concrete scenario where it is not.
**Type:** Critical  
**Level:** Intermediate  
**Hint:** Think about: a small table, a low-selectivity column, or a query that needs to return a large fraction of rows. When does the random I/O of an index scan exceed the cost of reading all pages sequentially?  
**Reference:** [[diagrams/index-selection-flow]]

---

### Q: Can too many indexes on a table actually cause query slowdowns, not just write slowdowns?
**Type:** Critical  
**Level:** Advanced  
**Hint:** The planner must consider every index during planning. With 30 indexes, planning time increases. Could a bad plan be chosen because the planner found a "cheaper looking" plan with a rarely-updated index whose statistics are stale?  
**Reference:** [[design-principles/indexing-design-principles]] Principle 1

---

## NULL and Constraints

### Q: Should every column have a NOT NULL constraint? What is the cost of allowing NULL where you shouldn't?
**Type:** Critical  
**Level:** Beginner  
**Hint:** NULLs propagate through expressions, are excluded from aggregates, and require `IS NULL` rather than `= NULL`. What is the real cost in application code for each nullable column? What is the legitimate use of NULL?  
**Reference:** [[design-principles/beginner-design-principles]] Principle 6

---

### Q: Is it safer to validate data in the application layer or the database layer? What are the trade-offs?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** Application validation is flexible and provides better UX (specific error messages). Database constraints are unfakeable. What happens when you have 3 services, 2 migration scripts, and a direct psql connection all writing to the same table?  
**Reference:** [[design-principles/intermediate-design-principles]] Principle 2

---

## Transactions

### Q: Should every write be wrapped in an explicit transaction? What is the overhead of BEGIN/COMMIT?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** Every statement in PostgreSQL is implicitly transactional. What does an explicit transaction add? What is the cost of a COMMIT (WAL flush)? When does batching writes in one transaction improve performance?  
**Reference:** [[design-principles/transaction-design-principles]]

---

### Q: Is SERIALIZABLE isolation always safer than READ COMMITTED? What does "safer" even mean in this context?
**Type:** Critical  
**Level:** Advanced  
**Hint:** SERIALIZABLE prevents anomalies but causes more aborts. An application that does not retry on serialization failure may silently drop writes. Is a silent drop "safer" than a phantom read?  
**Reference:** [[design-principles/transaction-design-principles]] Principle 5

---

## Performance

### Q: Is a query that runs in 10ms "fast enough"? What context is missing from that statement?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** 10ms at 1 request/second vs 10ms at 10,000 requests/second have very different implications. What matters: absolute duration, concurrency, and connection pool exhaustion at scale?  
**Reference:** [[design-principles/query-design-principles]] Principle 6

---

### Q: If `EXPLAIN` shows a sequential scan, should you always add an index?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** What is the table size? What fraction of rows does the query return? What is the actual duration? A sequential scan on a 1,000-row table takes microseconds. Would an index even help?  
**Reference:** [[design-principles/indexing-design-principles]] Principle 1

---

## Schema Design

### Q: Is soft deletion (a `deleted_at` column) always better than hard deletion?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** Soft deletion preserves history and allows recovery. But what does it do to every query that should only return non-deleted rows? What happens to UNIQUE constraints that should only enforce uniqueness among active rows?  
**Reference:** [[design-principles/schema-design-principles]] Principle 3

---

### Q: Is adding a `version` column for optimistic locking always the right approach for preventing concurrent conflicts?
**Type:** Critical  
**Level:** Advanced  
**Hint:** Optimistic locking works well when conflicts are rare. What happens in a high-contention scenario where many transactions update the same row? How many retries can pile up, and what is the throughput impact?  
**Reference:** [[design-principles/concurrency-design-principles]] Principle 3

---

## Extensions and Features

### Q: Should you store JSONB in PostgreSQL instead of in a dedicated document store like MongoDB? What are the legitimate trade-offs?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** PostgreSQL's JSONB gives you transactions, joins, and SQL. A dedicated document store may have more flexible querying, better horizontal scaling, and schema-free development. When is each appropriate?  
**Reference:** [[diagrams/sql-vs-non-sql-capability-map]]

---

### Q: Is enabling every available extension a good idea? What are the risks?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** Extensions add functions, types, and operators to the shared namespace. They have version dependencies, may affect upgrade paths, and some (like `pg_stat_statements`) have run-time overhead. What is the minimum-extension principle?  
**Reference:** [[diagrams/extension-ecosystem-map]]

---

### Q: Row Level Security adds safety — does it also add performance overhead? Is the overhead always acceptable?
**Type:** Critical  
**Level:** Advanced  
**Hint:** RLS policies are evaluated for every row touched. If a policy calls a function, that function is called per row. What happens to a bulk analytics query on a 10M-row table with an RLS policy that calls `current_setting('app.tenant_id')`?  
**Reference:** [[design-principles/security-design-principles]] Principle 2
