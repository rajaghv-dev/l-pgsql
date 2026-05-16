# Beginner Design Principles

Ten foundational rules for anyone starting out with PostgreSQL. These principles prevent the most common and painful beginner mistakes.

---

## Principle 1: Always use a primary key

### One-line rule
Every table must have a primary key — never create a table without one.

### Rationale
A primary key uniquely identifies each row. Without it, you cannot update or delete a specific row reliably, joins become ambiguous, and ORMs break in unpredictable ways.

### Example (correct)
```sql
CREATE TABLE users (
    id         bigserial PRIMARY KEY,
    email      text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now()
);
```

### Counter-example (incorrect)
```sql
CREATE TABLE users (
    email      text,
    name       text
);
-- No way to uniquely identify a row. Duplicate rows possible.
```

### When this principle applies
Always — every table, without exception.

### When to break it (with justification)
Junction tables (many-to-many) sometimes use a composite primary key (`PRIMARY KEY (user_id, role_id)`) instead of a surrogate key. This is acceptable and often preferable.

### PostgreSQL implementation
Use `bigserial` or `bigint GENERATED ALWAYS AS IDENTITY` for surrogate keys. Use `uuid` (`gen_random_uuid()`) for distributed systems where IDs must be globally unique without coordination.

### Agent/MCP implications
MCP tools that insert rows must always receive or generate the PK value before inserting. Never rely on "the database will figure it out" without confirming the column has a default.

### Related principles
[[schema-design-principles]]

### References
- PostgreSQL docs: [CREATE TABLE](https://www.postgresql.org/docs/current/sql-createtable.html)

---

## Principle 2: Never omit WHERE on UPDATE or DELETE

### One-line rule
Always include a WHERE clause on UPDATE and DELETE — treat an unfiltered statement as a bug.

### Rationale
`UPDATE orders SET status = 'cancelled'` without a WHERE clause updates every row in the table. PostgreSQL will not warn you. This mistake has caused production incidents at companies of every size.

### Example (correct)
```sql
UPDATE orders SET status = 'cancelled' WHERE id = 42 AND status = 'pending';
DELETE FROM sessions WHERE expires_at < now();
```

### Counter-example (incorrect)
```sql
UPDATE orders SET status = 'cancelled';  -- Cancels ALL orders
DELETE FROM sessions;                     -- Deletes ALL sessions
```

### When this principle applies
Always, unless you deliberately intend to touch every row (e.g., a one-time migration). Even then, test on a COUNT first.

### When to break it (with justification)
Bulk resets during schema migrations or test teardowns. Always run `SELECT count(*)` with the same conditions first to verify scope.

### PostgreSQL implementation
Use transactions + `RETURNING` to verify what you modified:
```sql
BEGIN;
DELETE FROM sessions WHERE expires_at < now() RETURNING id;
-- Review count, then:
COMMIT;  -- or ROLLBACK if count is wrong
```

### Agent/MCP implications
MCP tools that expose UPDATE or DELETE must require a filter parameter and refuse to execute if the filter is empty or missing. Consider a dry-run mode (SELECT count(*) first).

### Related principles
[[transaction-design-principles]]

---

## Principle 3: Use timestamptz, not timestamp

### One-line rule
Store all timestamps as `timestamptz` (timestamp with time zone), never bare `timestamp`.

### Rationale
`timestamp` stores no timezone information. When your application server, database server, or user's location changes timezone, all stored timestamps become ambiguous. `timestamptz` stores UTC internally and displays in the session timezone — it is unambiguous.

### Example (correct)
```sql
CREATE TABLE events (
    id         bigserial PRIMARY KEY,
    occurred_at timestamptz NOT NULL DEFAULT now()
);
```

### Counter-example (incorrect)
```sql
CREATE TABLE events (
    occurred_at timestamp DEFAULT now()  -- Which timezone? Unknown.
);
```

### When this principle applies
Always for application-facing timestamps.

### When to break it (with justification)
Calendaring applications that must preserve "3pm on December 25th regardless of timezone" use `timestamp` intentionally. This is rare and requires explicit design documentation.

### PostgreSQL implementation
```sql
-- Always returns UTC-anchored time
SELECT now();                          -- timestamptz
SELECT now() AT TIME ZONE 'US/Eastern'; -- convert for display only
```

### Agent/MCP implications
MCP tools that accept date/time parameters should require ISO 8601 format with timezone offset (e.g., `2024-01-15T10:30:00Z`).

### Related principles
[[schema-design-principles]]

---

## Principle 4: Prefer TEXT over VARCHAR(n)

### One-line rule
Use `text` for variable-length strings; only use `varchar(n)` when you have a business reason for the exact length limit.

### Rationale
In PostgreSQL, `text` and `varchar` have identical storage and performance characteristics. `varchar(255)` does not make queries faster or storage smaller — it only adds a length check. That check should come from a CHECK constraint when it has business meaning.

### Example (correct)
```sql
CREATE TABLE products (
    sku    text NOT NULL,
    name   text NOT NULL,
    -- SKU has a real business format constraint:
    CONSTRAINT sku_format CHECK (sku ~ '^[A-Z]{2}-[0-9]{4}$')
);
```

### Counter-example (incorrect)
```sql
CREATE TABLE products (
    sku   varchar(10),   -- Why 10? What happens at 11?
    name  varchar(255)   -- The classic cargo-cult number
);
```

### When this principle applies
All new schemas. Migrating legacy `varchar(n)` columns is low priority unless the limit causes application errors.

### When to break it (with justification)
When interfacing with an external system that has a documented maximum length, and you want the database to enforce that contract.

### PostgreSQL implementation
```sql
ALTER TABLE products ALTER COLUMN sku TYPE text;  -- Safe, instant in Postgres
```

### Agent/MCP implications
MCP tool schemas that accept string inputs should document max length in the JSON Schema description, not rely on database varchar limits.

---

## Principle 5: Name tables as plural nouns

### One-line rule
Use plural snake_case nouns for table names: `users`, `orders`, `order_items`.

### Rationale
A table is a set of rows. `SELECT * FROM users` reads as "give me the set of users" — which is how SQL naturally works. Singular names (`user`, `order`) create cognitive friction and often conflict with SQL reserved words.

### Example (correct)
```sql
CREATE TABLE users (...);
CREATE TABLE orders (...);
CREATE TABLE order_items (...);
```

### Counter-example (incorrect)
```sql
CREATE TABLE User (...);   -- Case-sensitive name, reserved word risk
CREATE TABLE order (...);  -- 'order' is a reserved word in SQL
```

### When this principle applies
All new table names.

### When to break it (with justification)
When integrating with a legacy system or ORM that mandates singular names. Consistency within a project matters more than any single convention.

### PostgreSQL implementation
PostgreSQL names are case-insensitive unless quoted. Always use lowercase snake_case without quotes.

---

## Principle 6: Always define NOT NULL on columns that must have a value

### One-line rule
Add `NOT NULL` to every column that cannot meaningfully be absent — NULL should be a deliberate modeling choice, not the default.

### Rationale
NULL means "unknown or absent." If a `users.email` can be NULL, your application must handle that case everywhere — or get NullPointerExceptions. Nullable columns make queries harder to reason about and aggregates silently ignore NULL values.

### Example (correct)
```sql
CREATE TABLE users (
    id         bigserial PRIMARY KEY,
    email      text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz    -- NULL means not deleted — intentional
);
```

### Counter-example (incorrect)
```sql
CREATE TABLE users (
    id    bigserial PRIMARY KEY,
    email text   -- NULL allowed? Then what does a NULL email mean?
);
```

### When this principle applies
All new columns. Default to NOT NULL; add nullable only when absence has distinct meaning.

### When to break it (with justification)
Soft-delete columns (`deleted_at`), optional profile fields, and foreign keys where the relationship is optional all legitimately allow NULL.

### PostgreSQL implementation
```sql
ALTER TABLE users ALTER COLUMN email SET NOT NULL;
```

---

## Principle 7: Use SERIAL or IDENTITY, not application-generated integers

### One-line rule
Let PostgreSQL generate surrogate integer keys using `bigserial` or `GENERATED ALWAYS AS IDENTITY` — do not manage sequences in application code.

### Rationale
Application-generated IDs require coordination, risk race conditions, and complicate distributed inserts. PostgreSQL sequences are atomic and performant.

### Example (correct)
```sql
id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY
-- or equivalently:
id bigserial PRIMARY KEY
```

### Counter-example (incorrect)
```sql
-- Application fetches max(id) then inserts max(id)+1 — race condition!
INSERT INTO orders (id, ...) VALUES ((SELECT max(id)+1 FROM orders), ...);
```

### When to break it (with justification)
Use `uuid` (`gen_random_uuid()`) for distributed systems. Use natural keys (e.g., ISO country codes) when the identifier has external meaning.

---

## Principle 8: Always quote string literals with single quotes

### One-line rule
Use single quotes for string literals; use double quotes only for identifiers (table and column names).

### Rationale
PostgreSQL treats `"name"` as an identifier and `'name'` as a string. Confusing them causes subtle bugs, especially in dynamic SQL or when column names match keywords.

### Example (correct)
```sql
SELECT * FROM users WHERE status = 'active';
SELECT "order" FROM legacy_table;  -- 'order' is a reserved word, must double-quote
```

### Counter-example (incorrect)
```sql
SELECT * FROM users WHERE status = "active";  -- Error: column "active" does not exist
```

---

## Principle 9: Test INSERT, UPDATE, DELETE inside a transaction before committing

### One-line rule
Wrap any manual data change in `BEGIN; ... ROLLBACK;` to preview its effect before you `COMMIT`.

### Rationale
You can always rollback. You cannot always undo a committed DELETE. This habit prevents accidental data loss, especially in production psql sessions.

### Example (correct)
```sql
BEGIN;
DELETE FROM orders WHERE status = 'test_data';
-- Check: SELECT count(*) FROM orders;
-- If count looks right:
COMMIT;
-- If wrong:
-- ROLLBACK;
```

### Counter-example (incorrect)
```sql
DELETE FROM orders WHERE status = 'test_data';  -- Immediately committed, no preview
```

### When to break it (with justification)
Automated migration scripts that are already wrapped in their own transaction management. But even then, run in staging first.

---

## Principle 10: Use EXPLAIN before adding an index

### One-line rule
Run `EXPLAIN` (or `EXPLAIN ANALYZE`) on your query before adding an index to verify the problem and confirm the index helps.

### Rationale
Indexes have a write cost, storage cost, and planner-complexity cost. Adding indexes without EXPLAIN is guessing. Worse, you may add an index the planner ignores because the table is too small or the selectivity is wrong.

### Example (correct)
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE user_id = 42;
-- If Seq Scan shows high cost and the table is large:
CREATE INDEX ON orders (user_id);
-- Then re-run EXPLAIN to confirm Index Scan is chosen.
```

### Counter-example (incorrect)
```sql
-- "It seems slow, let me add an index"
CREATE INDEX ON orders (status);  -- status has 3 values — low selectivity, often not used
```

### Related principles
[[indexing-design-principles]]

### References
- PostgreSQL docs: [EXPLAIN](https://www.postgresql.org/docs/current/sql-explain.html)
