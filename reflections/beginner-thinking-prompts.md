# Beginner Thinking Prompts

20+ questions for learners building their first PostgreSQL mental model.

---

## Data and NULL

### Q: What happens if you run `DELETE FROM orders` without a WHERE clause?
**Type:** Critical  
**Level:** Beginner  
**Hint:** PostgreSQL does not require a WHERE clause on DELETE. Think about what "no filter" means.  
**Reference:** [[design-principles/beginner-design-principles]] Principle 2

---

### Q: What is the difference between NULL and an empty string ('') in PostgreSQL?
**Type:** Ontology  
**Level:** Beginner  
**Hint:** NULL means "unknown or absent". An empty string is a known, specific value. How would `WHERE email = ''` and `WHERE email IS NULL` behave differently?  
**Reference:** [[concepts/beginner/04-data-types-and-values]]

---

### Q: Why does `SELECT 1 = NULL` return NULL instead of FALSE?
**Type:** First principles  
**Level:** Beginner  
**Hint:** If something is unknown, is the result of comparing it to anything known or unknown?  
**Reference:** [[concepts/beginner/04-data-types-and-values]]

---

### Q: Why does `COUNT(*)` and `COUNT(column)` return different numbers when the column has NULL values?
**Type:** Critical  
**Level:** Beginner  
**Hint:** `COUNT(*)` counts rows. `COUNT(column)` counts non-NULL values in that column. What does this mean for a column with 3 NULLs out of 10 rows?  
**Reference:** [[concepts/beginner/11-aggregation-intuition]]

---

## Schema

### Q: What is the difference between a schema and a database in PostgreSQL?
**Type:** Ontology  
**Level:** Beginner  
**Hint:** Databases are isolated from each other. What can schemas share? Can a query JOIN tables in two different databases?  
**Reference:** [[concepts/beginner/03-database-schema-table-row-column]]

---

### Q: What does a PRIMARY KEY constraint actually enforce?
**Type:** Ontology  
**Level:** Beginner  
**Hint:** Think about two properties: uniqueness and non-nullability. What happens if you try to INSERT a row with a duplicate id?  
**Reference:** [[design-principles/beginner-design-principles]] Principle 1

---

### Q: Why does PostgreSQL say "column does not exist" when you reference a column alias in a WHERE clause?
**Type:** Critical  
**Level:** Beginner  
**Hint:** SQL is not executed top-to-bottom like procedural code. In what order does PostgreSQL evaluate SELECT, FROM, WHERE, GROUP BY?  
**Reference:** [[concepts/beginner/08-select-filter-sort-limit]]

---

### Q: What is the difference between `UNIQUE` and `PRIMARY KEY`?
**Type:** Ontology  
**Level:** Beginner  
**Hint:** Both enforce uniqueness. What does PRIMARY KEY enforce additionally? Can a table have multiple UNIQUE constraints?  
**Reference:** [[design-principles/schema-design-principles]]

---

## Queries

### Q: Why does this query return no rows: `SELECT * FROM users WHERE name != 'Alice'` when some users have NULL in the name column?
**Type:** Critical  
**Level:** Beginner  
**Hint:** How does PostgreSQL evaluate `NULL != 'Alice'`? Is that TRUE, FALSE, or NULL?  
**Reference:** [[concepts/beginner/04-data-types-and-values]]

---

### Q: What is the difference between WHERE and HAVING?
**Type:** Ontology  
**Level:** Beginner  
**Hint:** WHERE filters rows before grouping. HAVING filters groups after aggregation. Can you use an aggregate function like COUNT() in a WHERE clause?  
**Reference:** [[concepts/beginner/11-aggregation-intuition]]

---

### Q: What does a LEFT JOIN return that an INNER JOIN does not?
**Type:** Ontology  
**Level:** Beginner  
**Hint:** Think about users who have no orders. What does each join type return for those users?  
**Reference:** [[concepts/beginner/10-joins-intuition]]

---

### Q: If you ORDER BY a column with some NULL values, where do the NULLs appear in the result?
**Type:** Critical  
**Level:** Beginner  
**Hint:** PostgreSQL treats NULL as "greater than any value" in descending order. What does `NULLS FIRST` and `NULLS LAST` do?  
**Reference:** [[concepts/beginner/08-select-filter-sort-limit]]

---

### Q: What does DISTINCT do, and why might it be slow?
**Type:** Critical  
**Level:** Beginner  
**Hint:** DISTINCT eliminates duplicate rows. What operation does the database need to perform to find duplicates? Think about what happens with millions of rows.  
**Reference:** [[concepts/beginner/08-select-filter-sort-limit]]

---

## Types and Values

### Q: Why should you use `timestamptz` instead of `timestamp` for storing when something happened?
**Type:** Critical  
**Level:** Beginner  
**Hint:** What is the difference between a point in time and a clock reading? What happens if your server moves to a different timezone?  
**Reference:** [[design-principles/beginner-design-principles]] Principle 3

---

### Q: Why does PostgreSQL have both `int` (4 bytes) and `bigint` (8 bytes)? When should you use each?
**Type:** Ontology  
**Level:** Beginner  
**Hint:** `int` maxes out at about 2.1 billion. At what rate would an application exhaust an int primary key? What happens when it wraps?  
**Reference:** [[design-principles/beginner-design-principles]] Principle 7

---

### Q: What is the difference between `text` and `varchar(255)` in PostgreSQL's storage engine?
**Type:** Critical  
**Level:** Beginner  
**Hint:** Do they use different storage formats? Does `varchar(255)` store data more compactly than `text`?  
**Reference:** [[design-principles/beginner-design-principles]] Principle 4

---

## Writes

### Q: What does RETURNING do in an INSERT statement, and why is it better than a follow-up SELECT?
**Type:** Critical  
**Level:** Beginner  
**Hint:** Think about what can change between an INSERT and a subsequent SELECT. Can another transaction affect the result?  
**Reference:** [[design-principles/query-design-principles]] Principle 3

---

### Q: If you UPDATE a row and the new value is the same as the old value, does PostgreSQL write anything to disk?
**Type:** Systems  
**Level:** Beginner  
**Hint:** Think about how MVCC works — does an UPDATE always create a new row version? What does HOT (Heap Only Tuple) optimization do?  
**Reference:** [[concepts/intermediate/08-mvcc-and-snapshot-thinking]]

---

### Q: What happens when you INSERT a row that violates a NOT NULL constraint?
**Type:** Critical  
**Level:** Beginner  
**Hint:** Who catches the error — the application, or the database? What is the error message? Is the transaction automatically rolled back?  
**Reference:** [[design-principles/beginner-design-principles]] Principle 6

---

### Q: What is the difference between TRUNCATE and DELETE without WHERE?
**Type:** Critical  
**Level:** Beginner  
**Hint:** Both remove all rows. Which one is faster? Which one can be rolled back? Which one fires row-level triggers?  
**Reference:** [[concepts/intermediate/07-transactions-and-isolation]]

---

### Q: When you run `SELECT now()` twice in the same transaction, do you get the same value both times?
**Type:** Systems  
**Level:** Beginner  
**Hint:** `now()` returns the transaction start time in PostgreSQL, not the clock time at each call. What function would return the actual current clock time?  
**Reference:** [[concepts/beginner/04-data-types-and-values]]

---

### Q: What does `ON CONFLICT DO NOTHING` do, and when would you use it?
**Type:** Critical  
**Level:** Beginner  
**Hint:** This is PostgreSQL's "upsert" mechanism. What conflict does it ignore? What is the difference from `DO UPDATE SET`?  
**Reference:** [[concepts/beginner/09-insert-update-delete]]
