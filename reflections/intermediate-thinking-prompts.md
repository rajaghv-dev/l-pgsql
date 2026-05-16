# Intermediate Thinking Prompts

20+ questions for developers who have built applications on PostgreSQL and are ready to go deeper.

---

## Indexes and Query Planning

### Q: Why would a query with an available index be slower than a sequential scan on a small table?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** An index scan requires two disk accesses: one to read the index entry, another to read the heap page. A sequential scan reads pages in order. At what table size does the crossover happen?  
**Reference:** [[diagrams/index-selection-flow]]

---

### Q: You add an index, run EXPLAIN, and the planner still chooses a sequential scan. What are three possible reasons?
**Type:** Systems  
**Level:** Intermediate  
**Hint:** Consider: table size, column selectivity, statistics freshness, and cost model settings.  
**Reference:** [[design-principles/indexing-design-principles]] Principle 2

---

### Q: What does `random_page_cost` affect, and why does the default of 4.0 matter for cloud databases?
**Type:** Systems  
**Level:** Intermediate  
**Hint:** The planner weighs random I/O cost against sequential I/O cost. Cloud SSDs have different random/sequential ratios than spinning disks. What happens to index usage if you lower `random_page_cost`?  
**Reference:** [[diagrams/sql-query-lifecycle]]

---

### Q: When does a Bitmap Index Scan appear in EXPLAIN, and why does PostgreSQL use it instead of a plain Index Scan?
**Type:** Systems  
**Level:** Intermediate  
**Hint:** Think about selectivity and heap page access patterns. If 20% of rows match, what is more efficient — jumping around the heap via index pointers, or building a bitmap of pages to fetch?  
**Reference:** [[diagrams/sql-query-lifecycle]]

---

### Q: Why does a partial index on `WHERE status = 'active'` only help queries that include that exact WHERE condition?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** A partial index only contains entries for rows where the partial index predicate is true. What happens if you query without the WHERE clause?  
**Reference:** [[design-principles/indexing-design-principles]] Principle 4 (beginner)

---

## Transactions and MVCC

### Q: When does VACUUM not help with table bloat?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** VACUUM can only reclaim dead tuples that no open transaction's snapshot still needs. What blocks VACUUM from reclaiming tuples?  
**Reference:** [[diagrams/transaction-mvcc-flow]]

---

### Q: You have a table with 10M rows. After running `DELETE FROM orders WHERE status = 'old'` (deleting 8M rows), the table file on disk is still the same size. Why?
**Type:** Systems  
**Level:** Intermediate  
**Hint:** MVCC marks rows as dead but does not shrink the file. What reclaims space within the file? What reclaims the file pages back to the OS?  
**Reference:** [[diagrams/transaction-mvcc-flow]]

---

### Q: Two transactions both read `balance = 1000` for account 42 and both try to deduct 100. READ COMMITTED isolation is used. What is the final balance, and why?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** READ COMMITTED re-reads data at each statement. Does the second UPDATE see the first's changes? What would `SELECT ... FOR UPDATE` change?  
**Reference:** [[design-principles/transaction-design-principles]] Principle 6

---

### Q: Why does changing isolation level from READ COMMITTED to REPEATABLE READ not prevent all anomalies?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** REPEATABLE READ prevents phantom reads in PostgreSQL's implementation, but does it prevent write skew? Think of a "check seat, then book" pattern.  
**Reference:** [[concepts/intermediate/07-transactions-and-isolation]]

---

### Q: What is the difference between a deadlock and a lock wait? Which one PostgreSQL automatically resolves?
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** A lock wait is one transaction waiting for another to finish. A deadlock is a cycle of waits. What does PostgreSQL do when it detects a deadlock cycle?  
**Reference:** [[concepts/intermediate/09-locks-and-concurrency]]

---

## Schema and Constraints

### Q: Why does adding a CHECK constraint to an existing table scan the entire table by default?
**Type:** Systems  
**Level:** Intermediate  
**Hint:** PostgreSQL needs to verify that all existing rows satisfy the new constraint. How can you add a constraint without the validation scan?  
**Reference:** [[design-principles/intermediate-design-principles]] Principle 2

---

### Q: What is a deferred constraint and when would you use it?
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** Normally constraints are checked immediately. `DEFERRABLE INITIALLY DEFERRED` moves the check to COMMIT time. When would you need to insert two rows that reference each other?  
**Reference:** [[concepts/intermediate/02-constraints-as-business-invariants]]

---

### Q: Why does PostgreSQL not automatically create indexes on foreign key columns?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** Consider the trade-off. Automatic indexes would add write overhead for every FK column regardless of whether the query pattern benefits. What is the PostgreSQL design philosophy here?  
**Reference:** [[design-principles/intermediate-design-principles]] Principle 3

---

### Q: What is the difference between a generated column and a view? When would you choose one over the other?
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** Generated columns store data physically; views compute it on query. Which is faster to read? Which takes storage? Which can be indexed?  
**Reference:** [[design-principles/advanced-design-principles]] Principle 10

---

## Aggregates and Window Functions

### Q: What is the difference between `RANK()` and `DENSE_RANK()`? Give an example where they differ.
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** If three rows tie for 1st place, what rank does the next row get with each function?  
**Reference:** [[concepts/beginner/11-aggregation-intuition]]

---

### Q: Why does `GROUP BY 1` work in PostgreSQL but is considered bad practice?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** `GROUP BY 1` groups by the first column in the SELECT list. What happens when someone reorders the columns? Is this self-documenting SQL?  
**Reference:** [[design-principles/query-design-principles]]

---

### Q: What is the difference between `FILTER (WHERE ...)` on an aggregate and a WHERE clause on the query?
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** `SUM(amount) FILTER (WHERE status = 'paid')` vs `WHERE status = 'paid'` before GROUP BY. How do they differ when you need multiple conditional aggregates in one query?  
**Reference:** [[concepts/beginner/11-aggregation-intuition]]

---

## Query Optimization

### Q: What does `EXPLAIN (ANALYZE, BUFFERS)` tell you that plain `EXPLAIN` does not?
**Type:** Systems  
**Level:** Intermediate  
**Hint:** ANALYZE actually runs the query and shows actual rows and time. BUFFERS shows how many shared buffer hits and reads occurred. Why does "actual rows" vs "estimated rows" matter?  
**Reference:** [[design-principles/indexing-design-principles]] Principle 2

---

### Q: What is a hash join, and when does the planner prefer it over a nested loop join?
**Type:** Systems  
**Level:** Intermediate  
**Hint:** A hash join builds a hash table from one input and probes it with the other. When is this faster than nested loops? What is the cost when the hash table does not fit in `work_mem`?  
**Reference:** [[diagrams/sql-query-lifecycle]]

---

### Q: You have a CTE that is referenced three times in a query. In PostgreSQL 12+, is it executed three times?
**Type:** Critical  
**Level:** Intermediate  
**Hint:** In PG 12+, CTEs without side effects are inlined by default. What keyword forces materialization? What behavior did PG 11 and earlier have?  
**Reference:** [[design-principles/intermediate-design-principles]] Principle 6

---

### Q: Why does `LIKE '%pattern%'` not use a B-tree index, but `LIKE 'pattern%'` (prefix match) does?
**Type:** Systems  
**Level:** Intermediate  
**Hint:** B-trees are ordered structures. A prefix (`%` at the end) preserves the order. A suffix (`%` at the start) does not — you cannot efficiently navigate a sorted structure for "ends with X". What index type can handle middle-of-string matching?  
**Reference:** [[diagrams/index-selection-flow]]

---

### Q: What is `work_mem` and what query operations use it?
**Type:** Systems  
**Level:** Intermediate  
**Hint:** `work_mem` is the memory budget for sorting and hash operations per query operation (not per query). A query with 3 sorts uses up to 3 × work_mem. What happens when an operation exceeds work_mem?  
**Reference:** [[diagrams/sql-query-lifecycle]]
