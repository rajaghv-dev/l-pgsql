# SQL Ontology

Level: Beginner
Domain: SQL

## Definition
The SQL (Structured Query Language) ontology covers the core statements and clauses that define how data is retrieved, modified, and structured in a relational database.

## Why this concept matters
SQL is the universal interface to PostgreSQL — every interaction from an application, a DBA, or an AI agent passes through it. Understanding each clause's semantics, evaluation order, and scope prevents logical errors and performance surprises.

## Related concepts
- [[schema-design-ontology]] — parent (tables and columns SQL operates on)
- [[query-ontology]] — child (how SQL is parsed and executed)
- [[transaction-ontology]] — related (SQL runs inside transactions)
- [[index-ontology]] — related (indexes affect SQL execution plans)

---

## Core SQL Concepts

### SELECT
One-line definition: Retrieves rows and columns from one or more tables, applying projections, filters, and ordering.

Clause evaluation order (logical, not written order):
`FROM` → `JOIN` → `WHERE` → `GROUP BY` → `HAVING` → `SELECT` → `DISTINCT` → `ORDER BY` → `LIMIT/OFFSET`

```sql
-- blocked: Docker not accessible
SELECT column_list
FROM table_name
WHERE condition
ORDER BY column ASC
LIMIT n;
```

Related: [[query-ontology]], [[index-ontology]]

---

### INSERT
One-line definition: Adds one or more new rows to a table.

```sql
-- blocked: Docker not accessible
INSERT INTO table_name (col1, col2)
VALUES (val1, val2)
RETURNING id;
```

Related: [[transaction-ontology]], [[schema-design-ontology]]

---

### UPDATE
One-line definition: Modifies existing rows that match a WHERE condition; without WHERE, updates all rows.

```sql
-- blocked: Docker not accessible
UPDATE table_name
SET col1 = val1
WHERE condition
RETURNING col1;
```

Related: [[transaction-ontology]], [[mvcc]]

---

### DELETE
One-line definition: Removes rows matching a WHERE condition; TRUNCATE is faster for full-table removal.

```sql
-- blocked: Docker not accessible
DELETE FROM table_name WHERE condition;
TRUNCATE table_name;  -- no WHERE, resets sequence optionally
```

Related: [[transaction-ontology]], [[schema-design-ontology]]

---

### WHERE
One-line definition: A row-level filter applied before grouping and aggregation; operates on individual rows.

Supports: comparison operators, `BETWEEN`, `IN`, `LIKE`, `ILIKE`, `IS NULL`, `EXISTS`, boolean logic (`AND`/`OR`/`NOT`).

Related: [[query-ontology]], [[index-ontology]] (predicate determines index eligibility)

---

### JOIN
One-line definition: Combines rows from two or more tables based on a join condition.

| Type | Behavior |
|------|---------|
| INNER JOIN | Only rows with matches on both sides |
| LEFT JOIN | All left rows; NULL fill for unmatched right |
| RIGHT JOIN | All right rows; NULL fill for unmatched left |
| FULL JOIN | All rows from both sides; NULL where no match |
| CROSS JOIN | Cartesian product — every combination |
| LATERAL JOIN | Subquery that references outer row per iteration |

```sql
-- blocked: Docker not accessible
SELECT a.id, b.name
FROM a
JOIN b ON a.b_id = b.id;
```

Related: [[query-ontology]], [[entity-relationship-ontology]], [[performance-ontology]]

---

### GROUP BY
One-line definition: Collapses rows with identical values in the specified columns into a single summary row, enabling aggregate functions.

Aggregate functions: `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, `ARRAY_AGG`, `STRING_AGG`, `JSONB_AGG`.

```sql
-- blocked: Docker not accessible
SELECT dept, COUNT(*), AVG(salary)
FROM employees
GROUP BY dept;
```

Related: [[query-ontology]]

---

### HAVING
One-line definition: A post-GROUP BY filter that operates on aggregate results; analogous to WHERE but for groups.

```sql
-- blocked: Docker not accessible
SELECT dept, COUNT(*)
FROM employees
GROUP BY dept
HAVING COUNT(*) > 10;
```

Related: [[query-ontology]]

---

### ORDER BY
One-line definition: Sorts the result set by one or more columns or expressions, ascending or descending.

Notes: `NULLS FIRST` / `NULLS LAST` controls null sort position; can reference SELECT aliases.

Related: [[query-ontology]], [[index-ontology]] (sorted index can avoid a sort step)

---

### LIMIT / OFFSET
One-line definition: Restricts the number of rows returned and skips a leading count of rows for pagination.

Caution: large OFFSET values still require the planner to scan and discard rows; keyset pagination is preferred for deep pages.

Related: [[query-ontology]], [[performance-ontology]]

---

### Subquery
One-line definition: A SELECT statement nested inside another query, used in WHERE, FROM, SELECT, or HAVING clauses.

Types:
- **Scalar subquery** — returns a single value
- **Row subquery** — returns one row
- **Table subquery** — returns a relation (used in FROM as a derived table)
- **Correlated subquery** — references columns from the outer query; re-executes per outer row

```sql
-- blocked: Docker not accessible
SELECT * FROM orders
WHERE customer_id IN (
    SELECT id FROM customers WHERE country = 'US'
);
```

Related: [[query-ontology]], [[performance-ontology]] (correlated subqueries can be slow)

---

### CTE (Common Table Expression)
One-line definition: A named, temporary result set defined with `WITH` that can be referenced once or multiple times in the main query.

Features:
- **Non-recursive CTE** — `WITH cte AS (SELECT ...)` — acts as a named subquery
- **Recursive CTE** — `WITH RECURSIVE` — iterates over hierarchical or graph data
- In PostgreSQL 12+, CTEs are inlined by default (treated as subqueries for optimization); use `MATERIALIZED` to force a fence

```sql
-- blocked: Docker not accessible
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC) AS rn
    FROM employees
)
SELECT * FROM ranked WHERE rn = 1;
```

Related: [[query-ontology]], [[performance-ontology]]

---

## System catalog reference
- `pg_operator` — registered operators used in WHERE and JOIN conditions
- `pg_aggregate` — registered aggregate functions (COUNT, SUM, etc.)
- `pg_proc` — all functions including window and aggregate functions

---

## Beginner mental model
SQL is a set of English-like commands: SELECT gets data, INSERT adds data, UPDATE changes data, DELETE removes data. Filters narrow down rows, JOINs combine tables, and GROUP BY summarizes.

## Intermediate mental model
SQL has a logical evaluation order that differs from its written order. Understanding this order (FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT) prevents surprises like referencing SELECT aliases in WHERE. JOINs are intersection operations on sets.

## Advanced mental model
Every SQL statement is a declarative specification; the query planner converts it to an imperative execution tree. The planner's choices (join strategy, scan type, sort method) depend on table statistics. Writing SQL with the planner in mind — proper predicate placement, index-friendly expressions, CTE materialization fences — is the difference between milliseconds and minutes.

## MCP and agent perspective
An AI agent submitting SQL must treat each statement as a transaction boundary. INSERT/UPDATE/DELETE should be wrapped in explicit transactions with ROLLBACK capability. SELECT queries should use LIMIT to bound result size. Agents must avoid SQL injection by using parameterized queries. DDL statements (CREATE TABLE, ALTER) require elevated privileges and should trigger human approval workflows.

## Practical implication
| Situation | Implication |
|-----------|-------------|
| WHERE references unindexed column | Full sequential scan; add index if selective |
| Correlated subquery in SELECT list | Executes once per output row; rewrite as JOIN |
| OFFSET 10000 for pagination | Scans and discards 10k rows; use keyset pagination |
| CTE referenced twice | By default materialized once in PG 12+ if marked MATERIALIZED |
| TRUNCATE vs DELETE | TRUNCATE is faster but cannot be rolled back in some contexts and does not fire row-level triggers |

## Obsidian connections
[[schema-design-ontology]] [[query-ontology]] [[transaction-ontology]] [[index-ontology]] [[performance-ontology]] [[entity-relationship-ontology]]

## References
- PostgreSQL 16 SQL Commands: https://www.postgresql.org/docs/16/sql-commands.html
- PostgreSQL 16 Queries: https://www.postgresql.org/docs/16/queries.html
