# Database, Schema, Table, Row, Column

Level: Beginner

---

## One-line intuition

Database → Schema → Table → Row → Column is a five-level container hierarchy: from the whole library down to one fact in one record.

---

## Why this exists

Large systems have many teams, many applications, and many kinds of data. Without namespace separation, table names collide and permissions cannot be scoped. The hierarchy — database > schema > table — solves this by creating logical boundaries that the database engine enforces.

---

## First-principles explanation

Any collection of facts needs:
1. A **container** to hold them (database)
2. A **namespace** to organize them (schema)
3. A **type** to structure each kind of fact (table)
4. A **record** for each individual fact (row)
5. An **attribute** for each property of a fact (column)

These five levels map directly to how PostgreSQL organizes data.

---

## Micro-concepts

| Level | PostgreSQL term | Library analogy |
|-------|----------------|-----------------|
| 1 | **Database** | The whole library building |
| 2 | **Schema** | A floor or section (Fiction, Non-Fiction, Reference) |
| 3 | **Table** | A catalog card index for one type of item |
| 4 | **Row** | One catalog card (one book's entry) |
| 5 | **Column** | One field on the card (title, author, ISBN) |

---

## Beginner view

**Library book catalog as a database:**

```
Database: library
  Schema: public
    Table: books
      Columns: id, title, author, isbn, year, available
      Row 1:   1, 'Dune', 'Frank Herbert', '978-...', 1965, true
      Row 2:   2, 'Neuromancer', 'William Gibson', '978-...', 1984, false
```

- The **database** (`library`) is the building.
- The **schema** (`public`) is the section of the building.
- The **table** (`books`) is one kind of catalogued thing.
- Each **row** is one specific book.
- Each **column** is one attribute every book has.

---

## Intermediate view

A **schema** in PostgreSQL is a namespace. The default schema is `public`. Multiple schemas in one database let you:
- Separate concerns: `app.users`, `audit.events`, `reporting.summaries`
- Apply different permissions per schema
- Use the same table name in two schemas without conflict

The **search_path** setting controls which schema PostgreSQL looks in first when you write just `books` instead of `public.books`.

---

## Advanced view

Rows are stored in **heap files** on disk. Each file is divided into 8 KB **pages**. Each page holds a variable number of rows (called **tuples**). Columns with variable-length data (TEXT, JSONB) that exceed ~2 KB are stored separately in TOAST tables.

Indexes are separate files that map column values to row locations (ctid). This is why adding an index does not change the table data — it creates a parallel lookup structure.

---

## Mental model

```
Database
└─ Schema (namespace)
   └─ Table (typed grid)
      ├─ Column A (attribute definition + type)
      ├─ Column B
      └─ Row 1 (one complete fact: values for every column)
          Row 2
          Row 3
```

A table is a **contract**: every row must provide a value (or NULL) for every column, and the value must match the column's declared type.

---

## PostgreSQL view

```sql
-- Show current database
SELECT current_database();

-- List all schemas
SELECT schema_name
FROM   information_schema.schemata
ORDER  BY schema_name;

-- List tables in public schema
SELECT table_name
FROM   information_schema.tables
WHERE  table_schema = 'public'
  AND  table_type = 'BASE TABLE';

-- Show columns of a table
SELECT column_name, data_type, is_nullable
FROM   information_schema.columns
WHERE  table_schema = 'public'
  AND  table_name = 'books'
ORDER  BY ordinal_position;
```

> blocked: Docker not accessible; validate against cfp_postgres when available

In psql, shorthand meta-commands do the same:
```
\l             -- list databases
\dn            -- list schemas
\dt public.*   -- list tables in public schema
\d books       -- describe table structure
```

---

## SQL view

```sql
-- Create a schema
CREATE SCHEMA IF NOT EXISTS catalog;

-- Create a table in that schema
CREATE TABLE IF NOT EXISTS catalog.books (
    id        BIGSERIAL PRIMARY KEY,
    title     TEXT      NOT NULL,
    author    TEXT      NOT NULL,
    isbn      VARCHAR(20),
    year      INTEGER,
    available BOOLEAN   DEFAULT true
);

-- Insert a row
INSERT INTO catalog.books (title, author, year)
VALUES ('The Pragmatic Programmer', 'David Thomas', 1999);

-- Select all columns of all rows
SELECT * FROM catalog.books;
```

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Non-SQL or hybrid view

A MongoDB **collection** is roughly equivalent to a PostgreSQL **table**, but rows (documents) do not need a fixed schema — each document can have different fields. This flexibility trades enforcement for freedom. PostgreSQL's JSONB column type offers a middle ground: relational structure where you need it, flexible JSON where you do not.

---

## Design principle

**Name things at the right level of granularity.** Schemas should group tables by logical domain, not by technical layer. Prefer `payments.transactions` and `inventory.products` over `app.table_001` and `app.table_002`. Future developers (and agents) read schema names to understand what lives where.

---

## Critical thinking

- Why might a multi-tenant application put each tenant's data in a separate schema instead of a separate database? (Shared connection pool, shared extensions, easier schema-level permission grants.)
- What is the cost of having thousands of tables in one schema? (pg_catalog scans get slower; consider partitioning or schemas.)
- Can two tables in different schemas have the same name? (Yes — that is the whole point of schemas as namespaces.)

---

## Creative thinking

Schemas are like namespaces in code (`import payments.models` vs `import inventory.models`). The database equivalent is `payments.transactions` vs `inventory.items`. Both share the same "runtime" (the database server) but live in separate namespaces. Same concept, different technology.

---

## Systems thinking

The hierarchy matters for:
- **Permissions**: GRANT USAGE ON SCHEMA, GRANT SELECT ON TABLE — you can scope to any level
- **Backup**: pg_dump can back up a whole database, a schema, or a single table
- **Migration tools**: Liquibase, Flyway, sqitch operate at the schema + table level
- **Multi-tenancy**: Row-level security, schema-per-tenant, database-per-tenant are three patterns with different tradeoffs

---

## MCP and agent perspective

An agent browsing a PostgreSQL database uses `information_schema` to discover what exists — databases, schemas, tables, columns — before querying data. This introspection is the agent equivalent of reading an API's documentation. A well-named schema hierarchy makes this introspection fast and informative.

---

## Ontology perspective

- **Database** = closed world assumption boundary (everything about this domain is in here)
- **Schema** = ontological module or namespace
- **Table** = class (concept)
- **Column** = property (attribute of that concept)
- **Row** = individual (one instance of the class)

This mapping is exact. A SQL table definition IS a class definition: it specifies which properties every instance must have and what types those properties take.

---

## Practice session

See `practice/beginner/02-schema-and-table-basics/` for hands-on exercises creating schemas and tables.

---

## References

| Resource | URL |
|----------|-----|
| PostgreSQL 16 — Schemas | https://www.postgresql.org/docs/16/ddl-schemas.html |
| PostgreSQL 16 — CREATE TABLE | https://www.postgresql.org/docs/16/sql-createtable.html |
| PostgreSQL 16 — information_schema | https://www.postgresql.org/docs/16/information-schema.html |
| PostgreSQL 16 — System Catalogs | https://www.postgresql.org/docs/16/catalogs.html |
