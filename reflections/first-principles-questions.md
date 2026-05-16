# First Principles Questions

15+ questions that require reasoning from first principles — not looking up an answer, but reconstructing it from core ideas.

---

## Declarative vs Procedural

### Q: If SQL is declarative ("what I want"), who decides how to execute it?
**Type:** First principles  
**Level:** Beginner  
**Hint:** There must be a component that takes the "what" and produces the "how." What is it called? What information does it use to make decisions? What is its optimization target?  
**Reference:** [[diagrams/sql-query-lifecycle]]

---

### Q: Why does the same SQL query sometimes produce a different execution plan after you INSERT a million rows?
**Type:** First principles  
**Level:** Intermediate  
**Hint:** The planner uses statistics, not the actual data. When do those statistics update? What does the planner use to estimate how many rows a filter will produce?  
**Reference:** [[diagrams/sql-query-lifecycle]]

---

## MVCC and Consistency

### Q: Why does MVCC need vacuum? Why can't old row versions just be overwritten immediately?
**Type:** First principles  
**Level:** Intermediate  
**Hint:** A concurrent transaction started before the UPDATE still needs to see the old value. What is the safest point to discard the old version? Who determines when that point is reached?  
**Reference:** [[diagrams/transaction-mvcc-flow]]

---

### Q: Why can two transactions both think they are "the first" to insert a row with the same unique key?
**Type:** First principles  
**Level:** Intermediate  
**Hint:** Each transaction takes a snapshot and sees consistent state. What happens when both are running concurrently and neither has committed? When does the second transaction find out about the first?  
**Reference:** [[concepts/intermediate/08-mvcc-and-snapshot-thinking]]

---

### Q: If READ COMMITTED transactions re-read data on each statement, why can they still be affected by write skew?
**Type:** First principles  
**Level:** Advanced  
**Hint:** Write skew requires two transactions to each read data, then write based on what they read. READ COMMITTED sees committed data at each statement — but between statements, what can change?  
**Reference:** [[concepts/intermediate/07-transactions-and-isolation]]

---

## Constraints and Correctness

### Q: Why are CHECK constraints enforced even when the application already validates the same rule?
**Type:** First principles  
**Level:** Beginner  
**Hint:** How many ways can data reach the database? List them all. Can a CHECK constraint be bypassed?  
**Reference:** [[design-principles/intermediate-design-principles]] Principle 2

---

### Q: Why does PostgreSQL have both UNIQUE constraints and PRIMARY KEY constraints? What does PK add that UNIQUE does not?
**Type:** First principles  
**Level:** Beginner  
**Hint:** Start from what each constraint enforces. A PK is UNIQUE + NOT NULL. But is that all? What role does the PK play in foreign key references?  
**Reference:** [[design-principles/schema-design-principles]]

---

## Indexes

### Q: Why does a B-tree index support range queries but a hash index does not?
**Type:** First principles  
**Level:** Intermediate  
**Hint:** A hash maps keys to buckets with no order preserved. A B-tree maintains sorted order. What does "find all keys between A and B" require from the data structure?  
**Reference:** [[diagrams/index-selection-flow]]

---

### Q: Why does an index make reads faster but writes slower?
**Type:** First principles  
**Level:** Beginner  
**Hint:** Every index is a separate data structure that must be kept synchronized with the table. What work does an INSERT into a table with 5 indexes require?  
**Reference:** [[design-principles/indexing-design-principles]]

---

### Q: Why would removing an index sometimes make a query faster?
**Type:** First principles  
**Level:** Intermediate  
**Hint:** The planner chooses plans. If an index exists, the planner might choose it even when a sequential scan would be faster (e.g., high bloat, wrong statistics, non-selective predicate). What can a bad plan cost?  
**Reference:** [[diagrams/index-selection-flow]]

---

## Storage and WAL

### Q: Why does PostgreSQL write changes to WAL before writing them to the heap file?
**Type:** First principles  
**Level:** Intermediate  
**Hint:** Consider what happens if the server crashes after writing to the heap but before the write completes. What makes WAL writes more crash-safe than random heap writes?  
**Reference:** [[diagrams/postgres-mental-model]]

---

### Q: Why does PostgreSQL need checkpointing, and what happens if it checkpoints too frequently?
**Type:** First principles  
**Level:** Advanced  
**Hint:** A checkpoint writes all dirty pages from shared buffers to disk. After a crash, recovery only needs to replay WAL from the last checkpoint. What is the trade-off between checkpoint frequency and crash recovery time?  
**Reference:** [[diagrams/postgres-mental-model]]

---

## Connection and Process Architecture

### Q: Why does PostgreSQL use one process per connection instead of threads?
**Type:** First principles  
**Level:** Intermediate  
**Hint:** This is a historical design choice. Processes have separate memory spaces; threads share memory. What safety and crash isolation benefits do separate processes provide? What is the main performance cost?  
**Reference:** [[diagrams/postgres-mental-model]]

---

### Q: Why does a connection pool like PgBouncer help even when the database can handle 1,000 connections?
**Type:** First principles  
**Level:** Intermediate  
**Hint:** Each connection is a process. 1,000 processes share CPU time and memory. At what point does the overhead of managing processes exceed the benefit of more concurrency?  
**Reference:** [[diagrams/application-to-database-flow]]

---

## Relational Model

### Q: SQL allows NULL in a column, but the relational model of E.F. Codd originally had reservations about NULL. Why?
**Type:** First principles  
**Level:** Advanced  
**Hint:** Codd's relational model is based on set theory and two-valued logic (TRUE/FALSE). NULL introduces three-valued logic. What happens to universal quantifiers ("for all rows") and existential quantifiers ("there exists a row") when NULLs are present?  
**Reference:** [[concepts/beginner/04-data-types-and-values]]

---

### Q: Why is a join more fundamental to relational databases than a subquery?
**Type:** First principles  
**Level:** Intermediate  
**Hint:** Think about what a relational query means: you are querying a set of tuples formed from relations. A join is set-algebraic (Cartesian product + filter). A correlated subquery is procedural. Which maps directly to the mathematical foundation?  
**Reference:** [[diagrams/sql-vs-non-sql-capability-map]]
