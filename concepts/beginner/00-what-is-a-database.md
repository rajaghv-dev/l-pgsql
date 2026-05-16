# What Is a Database?

Level: Beginner

---

## One-line intuition

A database is a structured container that lets you store, find, and change facts reliably — even across millions of records, simultaneous users, and server crashes.

---

## Why this exists

Files (CSV, JSON, text) work fine for small, single-user data. They break down when:

- Two people write at the same time → corrupted file
- You need to find one record in a million → full file scan every time
- You crash mid-write → partial data, no rollback
- Data grows → no enforced structure, any shape gets written

A **Database Management System (DBMS)** solves all four. PostgreSQL is one.

---

## First-principles explanation

Data is just facts. "Book X was published in 1984." "User 42 placed order 7 at 14:03 UTC."

Problems arise when facts:
1. Need to be found quickly (indexing)
2. Need to stay consistent across multiple related updates (transactions)
3. Need to be read by many and written by few simultaneously (concurrency)
4. Need to survive hardware failure (durability)

A DBMS is the software layer that handles all four, so application code does not have to.

---

## Micro-concepts

| Term | Plain meaning |
|------|---------------|
| **Database** | A named collection of related tables and objects |
| **DBMS** | The software that manages databases (PostgreSQL, MySQL, SQLite) |
| **Table** | A grid of rows and columns, like a spreadsheet tab |
| **Row** | One record — one book, one user, one order |
| **Column** | One attribute — title, email, created_at |
| **Query** | A question you ask in SQL |
| **Index** | A shortcut structure that speeds up lookups |
| **Transaction** | A group of changes that either all succeed or all fail |

---

## Beginner view

Think of a public library. The library holds thousands of books. Without a catalog:
- You would walk every aisle to find one book
- Two librarians checking out the same book simultaneously would lose track
- A power cut mid-checkout would leave the book status unknown

The **card catalog** (or its modern digital equivalent) is the database. It tracks every book, its location, and its availability. You query the catalog; you do not read every shelf.

PostgreSQL is the librarian software that runs the catalog.

---

## Intermediate view

A relational database stores data in **tables** (relations). Tables are linked by **keys**. The database engine enforces **constraints** — rules that keep data valid — so applications cannot accidentally write nonsense.

Example: A `books` table and a `loans` table. A loan row must reference a real book ID. The database enforces this with a foreign key constraint. No code check required.

---

## Advanced view

Modern databases separate concerns:

- **Storage engine** — how bytes land on disk (PostgreSQL uses heap files + WAL)
- **Query planner** — how to execute a query efficiently (sequential scan vs index scan)
- **Transaction manager** — MVCC (multi-version concurrency control) lets readers not block writers
- **Replication** — streaming WAL to replicas for high availability

You do not need to know these on day one, but knowing they exist explains why a database is not just "a file with a query layer on top."

---

## Mental model

```
Application code
      |
   SQL query   ← "Give me all available books published after 2010"
      |
  Query planner  ← chooses how to execute efficiently
      |
  Storage engine ← reads pages from disk / memory
      |
  Table data (rows, columns, indexes)
```

---

## PostgreSQL view

In PostgreSQL:
- One **server** can hold many **databases**
- One **database** holds many **schemas**
- One **schema** holds many **tables**, **views**, **functions**, **sequences**
- Data lives in tables; everything else is metadata or structure

The database you are using in this repo is named `cfp`. It lives inside the `cfp_postgres` Docker container.

---

## SQL view

```sql
-- List all databases on the server
SELECT datname FROM pg_database;

-- List all tables in the current schema
SELECT tablename FROM pg_tables WHERE schemaname = 'public';

-- A simple query
SELECT title, author FROM books WHERE available = true;
```

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Non-SQL or hybrid view

SQLite embeds a database in a single file — fine for mobile apps or local tools. MongoDB stores JSON documents without a fixed schema — flexible but harder to enforce consistency. Redis keeps everything in memory for speed.

PostgreSQL is the general-purpose choice: schema-enforced, ACID-compliant, extensible, and battle-tested at scale.

---

## Design principle

**Keep data close to its constraints.** If a rule belongs to the data (e.g. "year must be positive"), put it in the database as a CHECK constraint, not only in application code. Applications can be bypassed; the database cannot.

---

## Critical thinking

- What happens if two processes write to a flat CSV at the same time?
- Why is "just use a file" a valid choice for a config file but not for 10 million order records?
- When might a database be the wrong tool? (e.g. raw log streams, binary blobs, real-time sensor data)

---

## Creative thinking

Imagine a database as a city's record office. Each table is a department (births, vehicles, properties). Citizens are rows. The foreign key between vehicles and citizens ensures no car is registered to a non-existent person. Constraints are laws. The DBMS is the bureaucracy enforcing them — tedious but reliable.

---

## Systems thinking

A database is a **shared state machine** for distributed processes. Every application instance that connects reads and writes the same state. This centralization is both the power (consistency) and the bottleneck (scaling writes is hard). Understanding this tension is the foundation of database engineering.

---

## MCP and agent perspective

When an AI agent uses tools, it needs persistent memory across sessions. A flat file works for small state, but:
- Agents may run concurrently
- State may need to be queried ("find all tasks with status = pending")
- State must survive crashes

PostgreSQL is a natural agent memory store. MCP (Model Context Protocol) servers can expose PostgreSQL as a tool: the agent writes rows, queries them, and relies on the database's constraints to keep its memory valid.

---

## Ontology perspective

A database instantiates an **ontology** — a formal model of what exists and how it relates. Each table is a **class**. Each row is an **instance**. Each column is a **property**. Constraints are **axioms**. SQL queries are **questions over the ontology**.

Understanding this mapping helps when designing schemas: you are not just making tables, you are describing a world.

---

## Practice session

See `practice/beginner/00-environment-setup/` for hands-on exercises connecting to PostgreSQL and running your first queries.

---

## References

| Resource | URL |
|----------|-----|
| PostgreSQL 16 Docs — About | https://www.postgresql.org/docs/16/intro-whatis.html |
| PostgreSQL 16 Docs — Tutorial | https://www.postgresql.org/docs/16/tutorial.html |
| CMU 15-445 Intro to Databases (free lectures) | https://15445.courses.cs.cmu.edu/ |
| Use The Index, Luke (free) | https://use-the-index-luke.com/ |
