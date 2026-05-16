# Schema Design Ontology

Level: Beginner → Intermediate
Domain: PostgreSQL / SQL

## Definition
Schema design is the process of organizing data into tables, columns, types, and constraints that faithfully represent the domain model while supporting the intended query patterns efficiently.

## Why this concept matters
Schema decisions are the hardest to reverse — adding a column is easy; splitting a table or changing a column type under production load requires careful migration. Getting normalization, types, and constraints right from the start prevents entire categories of data quality bugs and performance problems.

## Related concepts
- [[entity-relationship-ontology]] — parent (ER model drives schema design)
- [[sql-ontology]] — related (SQL operates on the schema)
- [[index-ontology]] — child (indexes are defined on schema columns)
- [[transaction-ontology]] — related (constraints are enforced per transaction)
- [[domain-ontology-examples]] — child (concrete schema designs)

---

## Schema (Namespace)

One-line definition: A named namespace within a database that groups tables, views, types, and functions; analogous to a package or module.

```sql
-- blocked: Docker not accessible
CREATE SCHEMA app;
CREATE SCHEMA audit;

-- Set search path so unqualified names resolve to app first
SET search_path = app, public;

-- Inspect
SELECT schema_name FROM information_schema.schemata;
```

PostgreSQL resolves unqualified object names by searching schemas in `search_path` order. The `public` schema is the default.

---

## Table

One-line definition: A named, structured relation consisting of a fixed set of columns and a variable number of rows.

```sql
-- blocked: Docker not accessible
CREATE TABLE app.orders (
    id          BIGSERIAL PRIMARY KEY,
    customer_id BIGINT    NOT NULL REFERENCES app.customers(id),
    total       NUMERIC(12,2) NOT NULL CHECK (total >= 0),
    status      TEXT      NOT NULL DEFAULT 'pending',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Inspect tables
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'app';

-- Remove
DROP TABLE IF EXISTS app.orders CASCADE;
```

---

## Column

One-line definition: A named field of a specific data type within a table; every row has exactly one value per column (or NULL if the column permits it).

### Choosing column types

| Use case | Recommended type |
|----------|-----------------|
| Surrogate PK (auto-increment) | `BIGSERIAL` or `BIGINT` + sequence |
| UUID primary key | `UUID` with `gen_random_uuid()` |
| Short text | `TEXT` (no length limit needed in PG) |
| Exact decimal (money) | `NUMERIC(precision, scale)` |
| Floating point | `DOUBLE PRECISION` (64-bit IEEE 754) |
| Boolean | `BOOLEAN` |
| Timestamp with timezone | `TIMESTAMPTZ` (stores UTC, displays in session tz) |
| Date only | `DATE` |
| Duration | `INTERVAL` |
| JSON (flexible) | `JSONB` (binary, indexed) over `JSON` (text) |
| Enum (fixed values) | `TEXT` with CHECK constraint or `CREATE TYPE ... AS ENUM` |
| Binary data | `BYTEA` |
| Network addresses | `INET`, `CIDR`, `MACADDR` |
| Arrays | `TEXT[]`, `INT[]`, etc. |

---

## Constraint

### NOT NULL
One-line definition: Prevents a column from holding a NULL value; should be applied to any column that must always have a meaningful value.

```sql
-- blocked: Docker not accessible
ALTER TABLE orders ALTER COLUMN status SET NOT NULL;
```

### UNIQUE
One-line definition: Ensures no two rows have the same value(s) in the constrained column(s); automatically creates a B-tree index.

```sql
-- blocked: Docker not accessible
ALTER TABLE users ADD CONSTRAINT uq_users_email UNIQUE (email);
-- Composite unique: no two rows share the same (org_id, slug)
ALTER TABLE posts ADD CONSTRAINT uq_posts_org_slug UNIQUE (org_id, slug);
```

### CHECK
One-line definition: Validates that a boolean expression is true for every row; evaluated on INSERT and UPDATE.

```sql
-- blocked: Docker not accessible
ALTER TABLE products ADD CONSTRAINT chk_price_positive CHECK (price > 0);
ALTER TABLE events ADD CONSTRAINT chk_end_after_start CHECK (end_at > start_at);
```

### PRIMARY KEY (PK)
One-line definition: A NOT NULL + UNIQUE constraint that uniquely identifies each row; a table has at most one PK; PostgreSQL automatically creates a B-tree index.

```sql
-- blocked: Docker not accessible
-- Composite PK (junction table)
CREATE TABLE product_tag (
    product_id BIGINT REFERENCES products(id),
    tag_id     BIGINT REFERENCES tags(id),
    PRIMARY KEY (product_id, tag_id)
);
```

### FOREIGN KEY (FK)
One-line definition: A referential integrity constraint that requires the column value(s) to match an existing row in the referenced table or be NULL.

```sql
-- blocked: Docker not accessible
ALTER TABLE orders
    ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE;
```

Related: [[entity-relationship-ontology]]

---

## Domain

One-line definition: A named data type with constraints attached; allows reuse of type + constraint definitions across multiple columns.

```sql
-- blocked: Docker not accessible
CREATE DOMAIN positive_numeric AS NUMERIC CHECK (VALUE > 0);
CREATE DOMAIN email_address AS TEXT CHECK (VALUE ~* '^[^@]+@[^@]+\.[^@]+$');

CREATE TABLE products (
    price positive_numeric NOT NULL
);
```

---

## Normalization

One-line definition: The process of decomposing tables to eliminate redundancy and update anomalies by ensuring each fact is stored in exactly one place.

| Normal Form | Rule |
|-------------|------|
| 1NF | Atomic (indivisible) column values; no repeating groups |
| 2NF | 1NF + no partial dependency on composite PK |
| 3NF | 2NF + no transitive dependency (non-key columns depend only on PK) |
| BCNF | Stronger 3NF — every determinant is a candidate key |
| 4NF | BCNF + no multi-valued dependencies |

In practice: normalize to 3NF/BCNF by default; selectively denormalize for read performance.

---

## Denormalization

One-line definition: Intentionally introducing redundancy (e.g., storing derived data, duplicating columns, embedding JSON) to improve read performance at the cost of write complexity.

Common patterns:
- **Summary columns**: `total_order_count` stored on customer row (updated by trigger or event)
- **JSONB embedding**: storing address as JSONB on user row instead of a separate address table
- **Materialized view**: pre-computed join result refreshed on schedule

Related: [[performance-ontology]]

---

## Inspect schema structure

```sql
-- blocked: Docker not accessible
-- All columns in a table
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'orders'
ORDER BY ordinal_position;

-- All constraints
SELECT constraint_name, constraint_type, table_name
FROM information_schema.table_constraints
WHERE table_schema = 'app';

-- Table sizes
SELECT relname, pg_size_pretty(pg_total_relation_size(oid)) AS total_size
FROM pg_class
WHERE relnamespace = 'app'::regnamespace AND relkind = 'r'
ORDER BY pg_total_relation_size(oid) DESC;
```

---

## System catalog reference
- `pg_class` — tables, indexes, sequences, views (`relkind = 'r'` for tables)
- `pg_attribute` — columns (joined with `pg_class` on `attrelid`)
- `pg_constraint` — all constraints (PK, FK, UNIQUE, CHECK)
- `pg_type` — data types including enums and domains
- `pg_namespace` — schemas
- `information_schema.columns` — columns (ANSI-standard, verbose but portable)
- `information_schema.table_constraints` — constraints

---

## Beginner mental model
A database is like a spreadsheet workbook: schemas are sheets-tabs, tables are the grids, columns are the column headers, and rows are the data. Constraints are the validation rules that prevent bad data from being entered.

## Intermediate mental model
Normalization eliminates redundancy by storing each fact once. A customer's name is in the `customers` table; orders reference it by `customer_id`. If you store the name in both places, you'll get inconsistencies when it changes. Foreign keys enforce this relationship at the database level so application bugs can't break it.

## Advanced mental model
Schema design is a set of tradeoffs: normalize for integrity and write simplicity, denormalize for read performance. Type choice affects storage, index type, and operator availability. Generated columns (`GENERATED ALWAYS AS (expr) STORED`) avoid trigger-based denormalization with automatic consistency. Partitioning (`PARTITION BY RANGE`, `LIST`, `HASH`) is a schema-level decision that affects query planning, vacuum, and index design.

## MCP and agent perspective
An agent exploring an unknown database should query `information_schema.tables`, `information_schema.columns`, and `pg_constraint` to build a schema map before generating SQL. Schema changes (ALTER TABLE, CREATE TABLE) should always be proposed to a human before execution — they may cause locking or irreversible data changes. Agents should validate that FK targets exist before inserting child rows.

## Practical implication
| Situation | Implication |
|-----------|-------------|
| TEXT column with unconstrained length | Correct in PostgreSQL; no performance difference from VARCHAR(n) |
| Using FLOAT for currency | Floating-point rounding errors corrupt financial data; use NUMERIC |
| Missing NOT NULL on required column | Application bugs can insert NULL; constraint is the last line of defense |
| No index on FK column | JOIN from child to parent requires seq scan of child table |
| Storing data as CSV string in one column | Cannot filter, index, or join; violates 1NF |
| JSONB vs separate table | JSONB: flexible schema, harder to index; table: rigid schema, full SQL |

## Obsidian connections
[[entity-relationship-ontology]] [[sql-ontology]] [[index-ontology]] [[transaction-ontology]] [[domain-ontology-examples]] [[performance-ontology]] [[extension-ontology]]

## References
- PostgreSQL DDL: https://www.postgresql.org/docs/16/ddl.html
- Data Types: https://www.postgresql.org/docs/16/datatype.html
- Constraints: https://www.postgresql.org/docs/16/ddl-constraints.html
