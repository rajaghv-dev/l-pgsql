# Data Types and Values

Level: Beginner

---

## One-line intuition

A data type tells PostgreSQL exactly what kind of value a column holds — so it can store it efficiently, validate it automatically, and answer questions about it correctly.

---

## Why this exists

Without types, a database is just a spreadsheet. With types:
- PostgreSQL rejects `'hello'` for an `INTEGER` column automatically
- Date arithmetic (`now() - created_at`) works correctly
- Indexes are built correctly for the data's structure
- Storage is efficient (a BOOLEAN takes 1 byte; TEXT takes as many as needed)

Type enforcement is one of the ways the database protects data quality without relying on application code.

---

## First-principles explanation

Every value in a computer is ultimately bytes. A type is a contract that says: "these bytes represent X, and operations on them follow rules for X." `DATE '2024-01-15' + 7` gives `2024-01-22` because the database knows these are calendar days, not raw integers.

PostgreSQL has over 40 built-in types. You need about 10 for most work.

---

## Micro-concepts: The Essential 10

| Type | Use for | Example |
|------|---------|---------|
| `INTEGER` | Whole numbers up to ~2.1 billion | `year`, `quantity`, `age` |
| `BIGINT` | Whole numbers up to ~9.2 quintillion | `id`, `user_count` |
| `TEXT` | Strings of any length | `title`, `description`, `email` |
| `VARCHAR(n)` | Strings with a max length | `code VARCHAR(10)`, `country_code VARCHAR(2)` |
| `BOOLEAN` | true / false / NULL | `active`, `verified`, `available` |
| `DATE` | Calendar date, no time | `birth_date`, `due_date` |
| `TIMESTAMPTZ` | Date + time + timezone | `created_at`, `updated_at`, `processed_at` |
| `NUMERIC(p,s)` | Exact decimal numbers | `price NUMERIC(10,2)`, `tax_rate NUMERIC(5,4)` |
| `UUID` | Universally unique identifier | `id UUID DEFAULT gen_random_uuid()` |
| `JSONB` | Semi-structured data, binary JSON | `metadata JSONB`, `config JSONB` |

---

## Beginner view

**Choosing a type is like choosing a container:**

- Ice cube tray (INTEGER) — fixed small compartments
- Filing cabinet drawer (TEXT) — takes what you give it, any size
- Calendar page (DATE) — only valid dates fit
- Safe deposit box with a unique key (UUID) — globally unique
- Mixed container with labeled compartments (JSONB) — flexible structure inside a typed column

---

## Intermediate view

### TEXT vs VARCHAR(n)

In PostgreSQL, `TEXT` and `VARCHAR` use the same internal storage. There is **no performance difference**. Use `TEXT` unless you have a business rule that requires a maximum length (e.g. a postal code must be at most 10 characters). In that case `VARCHAR(10)` adds a constraint. `CHAR(n)` pads with spaces — almost never what you want.

### TIMESTAMPTZ vs TIMESTAMP

- `TIMESTAMP` stores date+time with no timezone awareness — dangerous for distributed systems
- `TIMESTAMPTZ` stores the moment in UTC, displays in the session timezone

**Always use `TIMESTAMPTZ`** for anything that records when something happened.

### NUMERIC vs FLOAT

- `FLOAT` (double precision) is approximate — `0.1 + 0.2 = 0.30000000000000004`
- `NUMERIC(p,s)` is exact — use for money, tax rates, scientific measurements

**Always use `NUMERIC` for money.**

---

## Advanced view

PostgreSQL stores types with different strategies:
- Fixed-size types (INTEGER, BIGINT, BOOLEAN, DATE): stored inline in the row, constant-time access
- Variable-size types (TEXT, JSONB, BYTEA): stored inline if small, in TOAST if large (>~2 KB)
- UUID: stored as 16 bytes (binary), displayed as text, indexed efficiently as a B-tree

JSONB operators (`->>`, `->`, `@>`, `?`) allow querying inside JSON. GIN indexes on JSONB columns make this fast.

---

## Mental model

```
Column definition: price NUMERIC(10,2)
                         │       │
                         │       └── 2 decimal places (scale)
                         └────────── 10 total digits (precision)

Valid:   99999999.99
Invalid: 100000000.00 (11 digits before decimal)
Invalid: 9.999        (3 decimal places)
```

---

## PostgreSQL view

```sql
-- Check what types a table uses
SELECT column_name, data_type, character_maximum_length, numeric_precision, numeric_scale
FROM   information_schema.columns
WHERE  table_name = 'products';

-- Cast a value to a different type
SELECT '42'::INTEGER;
SELECT '2024-01-15'::DATE;
SELECT now()::DATE;  -- truncate timestamp to date

-- Generate a UUID
SELECT gen_random_uuid();
```

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## SQL view

```sql
CREATE TABLE IF NOT EXISTS products (
    id           UUID         DEFAULT gen_random_uuid() PRIMARY KEY,
    name         TEXT         NOT NULL,
    sku          VARCHAR(20)  NOT NULL,
    price        NUMERIC(10,2) NOT NULL,
    in_stock     BOOLEAN      DEFAULT true,
    created_at   TIMESTAMPTZ  DEFAULT now(),
    metadata     JSONB
);

INSERT INTO products (name, sku, price, metadata)
VALUES (
    'Widget Pro',
    'WGT-001',
    29.99,
    '{"color": "blue", "weight_kg": 0.5}'
);

-- Query JSONB field
SELECT name, metadata->>'color' AS color
FROM   products
WHERE  metadata @> '{"color": "blue"}';
```

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Non-SQL or hybrid view

In Python, types are dynamic: `x = 1; x = "hello"` is valid. In PostgreSQL, column types are static and enforced: once a column is declared `INTEGER`, it will never hold text. This is closer to TypeScript than Python in philosophy. The database is the type checker for your data layer.

---

## Design principle

**Match the type to the business rule, not just the storage format.**
- Email addresses: `TEXT` — they have no max length rule in practice
- Country codes: `VARCHAR(2)` — ISO 3166-1 alpha-2 is always exactly 2 characters
- Prices: `NUMERIC(10,2)` — must be exact, two decimal places
- Event timestamps: `TIMESTAMPTZ` — always timezone-aware
- Surrogate IDs: `BIGSERIAL` (small apps) or `UUID` (distributed apps)

---

## Critical thinking

- Why does PostgreSQL have both `FLOAT` and `NUMERIC` when computers store everything as binary? (FLOAT is fast but approximate; NUMERIC is slow but exact. Choose by whether the domain requires exactness.)
- When would you choose `UUID` over `BIGSERIAL` as a primary key? (UUID: distributed systems where no central sequence generator exists; BIGSERIAL: single-server systems where sequential IDs are acceptable and smaller storage is preferred.)
- What is the risk of using `TEXT` for everything? (No validation at the type level; dates stored as text are not compared as dates; indexes are less efficient for non-text operations.)

---

## Creative thinking

Data types are like physical containers at a lab. You would not store acid in a paper bag or measure a star's mass in milligrams. The container and the unit must match the substance. PostgreSQL types are the database's container vocabulary — choose the right one and the database enforces fitness for purpose automatically.

---

## Systems thinking

Types interact with:
- **Indexes**: BIGSERIAL → B-tree index. UUID → B-tree but slightly larger. JSONB → GIN index for key/value search.
- **Replication**: fixed-size types replicate predictably. TOAST data adds complexity.
- **Query planning**: statistics per column help the planner. TEXT with low cardinality vs high cardinality changes the plan.
- **Application ORM**: SQLAlchemy, ActiveRecord, Prisma map PostgreSQL types to language types. Mismatches cause subtle bugs.

---

## MCP and agent perspective

When an agent writes to PostgreSQL, type enforcement is a safety net. If the agent tries to insert a non-numeric value into a `NUMERIC` price column, PostgreSQL rejects it before it lands. This means agents can write boldly: the database will catch type mismatches. Agents using JSONB columns for flexible metadata get schema-on-read flexibility without losing the surrounding relational structure.

---

## Ontology perspective

Types are **ranges** in ontological terms: `BOOLEAN` has the range {true, false, NULL}; `DATE` has the range of all valid calendar dates. A column definition is an **axiom** that restricts which individuals can have that property. This is directly analogous to OWL datatype restrictions in a formal ontology.

---

## Practice session

Types appear in `practice/beginner/02-schema-and-table-basics/` and `practice/beginner/03-keys-and-constraints/`.

---

## References

| Resource | URL |
|----------|-----|
| PostgreSQL 16 — Data Types | https://www.postgresql.org/docs/16/datatype.html |
| PostgreSQL 16 — Numeric Types | https://www.postgresql.org/docs/16/datatype-numeric.html |
| PostgreSQL 16 — Date/Time Types | https://www.postgresql.org/docs/16/datatype-datetime.html |
| PostgreSQL 16 — JSON Types | https://www.postgresql.org/docs/16/datatype-json.html |
| PostgreSQL 16 — UUID | https://www.postgresql.org/docs/16/datatype-uuid.html |
| TEXT vs VARCHAR — depesz blog | https://www.depesz.com/2010/03/02/charvaracharnvarchar/ |
