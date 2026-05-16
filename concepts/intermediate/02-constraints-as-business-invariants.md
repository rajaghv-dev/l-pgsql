# Constraints as Business Invariants
Level: Intermediate

## One-line intuition
A constraint is a business rule that the database enforces automatically, regardless of which application, script, or agent writes data.

## Why this exists
Business rules like "a price cannot be negative" or "a customer must have an email" are almost always expressed first in application code. But application code can be bypassed: a direct psql session, a data import script, a migrated dataset, or a buggy agent can write data that violates the rule. Constraints put the rule in the database, where it cannot be bypassed.

## First-principles explanation
A constraint is a predicate that must hold true for every row in a table (or across rows, for UNIQUE/EXCLUDE). PostgreSQL checks it on every `INSERT`, `UPDATE`, and optionally on `DELETE` (via FK `ON DELETE` behavior). If the predicate is false, the operation is rejected with an error.

This makes constraints **executable documentation**: they describe what the data must look like, and they verify it continuously.

## Micro-concepts
| Constraint | What it enforces |
|---|---|
| `NOT NULL` | Column must always have a value |
| `UNIQUE` | No two rows may share the same value(s) in this column(s) |
| `PRIMARY KEY` | `NOT NULL` + `UNIQUE`; the row's identity |
| `FOREIGN KEY` | Value in this column must exist as a PK in the referenced table |
| `CHECK` | An arbitrary boolean expression must be true |
| `EXCLUDE` | No two rows may overlap on a given operator (e.g., date ranges) |
| `DEFERRABLE` | Constraint can be checked at commit time instead of statement time |
| Partial unique index | `CREATE UNIQUE INDEX ... WHERE cond` — unique only within a subset of rows |

## Beginner view
```sql
CREATE TABLE products (
    id     SERIAL PRIMARY KEY,
    name   TEXT   NOT NULL,           -- can't be NULL
    price  NUMERIC(10,2) NOT NULL
               CHECK (price > 0),     -- must be positive
    sku    TEXT   UNIQUE              -- no two products share a SKU
);
```
If any INSERT violates these, PostgreSQL raises an error immediately. The application doesn't need to check — the database does.

## Intermediate view
**CHECK constraints** encode business rules inline:
```sql
ALTER TABLE orders
    ADD CONSTRAINT valid_status
    CHECK (status IN ('pending', 'confirmed', 'shipped', 'cancelled'));
```

**FK constraints** are directional integrity:
```sql
-- If product is deleted, what happens to order_items?
FOREIGN KEY (product_id) REFERENCES products(id)
    ON DELETE RESTRICT   -- block delete if rows exist
  | ON DELETE CASCADE    -- delete child rows
  | ON DELETE SET NULL   -- set child column to NULL
```

**EXCLUDE constraint** — the most powerful, least-known:
```sql
-- No two reservations for the same room may have overlapping time ranges.
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE reservations (
    id       SERIAL PRIMARY KEY,
    room_id  INT    NOT NULL,
    during   TSRANGE NOT NULL,
    EXCLUDE USING GIST (room_id WITH =, during WITH &&)
);
-- "&&" = overlap. Two rows match if room_id is equal AND during overlaps.
-- validation: blocked — Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled
```

**Partial UNIQUE index** as an alternative to UNIQUE constraint:
```sql
-- Email must be unique only among active customers (not deleted ones)
CREATE UNIQUE INDEX customers_active_email_idx
    ON customers(email)
    WHERE deleted_at IS NULL;
```
This cannot be expressed as a UNIQUE constraint alone — it requires an index.

## Advanced view
**Deferred constraints** allow temporarily violating a constraint within a transaction:
```sql
ALTER TABLE order_items
    ADD CONSTRAINT order_items_order_fk
    FOREIGN KEY (order_id) REFERENCES orders(id)
    DEFERRABLE INITIALLY DEFERRED;
-- Now you can INSERT order_items before INSERT orders in the same transaction;
-- the FK is checked at COMMIT.
```
This is essential when loading data with circular references or when batch-inserting dependent rows.

**Constraint naming** matters for error handling:
```sql
-- Named constraint produces a named violation message
ALTER TABLE products
    ADD CONSTRAINT price_must_be_positive CHECK (price > 0);
-- ERROR: new row for relation "products" violates check constraint "price_must_be_positive"
-- Application can catch and map this to a user-facing message.
```

**Constraints vs. triggers**: Constraints are evaluated by the planner and executor; they are cheaper than triggers for simple predicates. Use `CHECK` for stateless rules (column-level); use triggers only for stateful rules (cross-row, cross-table conditions that CHECK cannot express).

## Mental model
Constraints are like lock pins in a filing cabinet drawer: it doesn't matter who tries to file a document — the cabinet itself rejects anything that doesn't fit. Application code is the office policy; constraints are the physical cabinet. Both can say "no", but only the cabinet can't be talked around.

## PostgreSQL view
```sql
-- View all constraints on a table
SELECT conname, contype, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'orders'::regclass;

-- contype: p=primary, u=unique, f=foreign, c=check, x=exclude

-- Temporarily disable a constraint (e.g., for bulk load)
ALTER TABLE order_items DISABLE TRIGGER ALL;  -- for FK-backed triggers
-- Or use SET session_replication_role = replica; (bypasses FK checks)
-- WARNING: only do this for trusted bulk loads with pre-validated data
```

## SQL view
```sql
-- NOT NULL
ALTER TABLE customers ALTER COLUMN email SET NOT NULL;

-- UNIQUE
ALTER TABLE customers ADD CONSTRAINT customers_email_unique UNIQUE (email);

-- CHECK with expression
ALTER TABLE order_items ADD CONSTRAINT qty_positive CHECK (qty > 0);

-- EXCLUDE: overlapping reservations (requires btree_gist)
CREATE EXTENSION IF NOT EXISTS btree_gist;
ALTER TABLE reservations
    ADD CONSTRAINT no_overlap
    EXCLUDE USING GIST (room_id WITH =, during WITH &&);

-- Deferred FK
ALTER TABLE order_items
    ADD CONSTRAINT fk_order FOREIGN KEY (order_id) REFERENCES orders(id)
    DEFERRABLE INITIALLY DEFERRED;

-- Partial unique index
CREATE UNIQUE INDEX ON customers(email) WHERE deleted_at IS NULL;
```

## Non-SQL or hybrid view
- **MongoDB**: No native CHECK/EXCLUDE constraints. JSON Schema validation (`$jsonSchema`) is the nearest equivalent but is application-side. FK integrity does not exist.
- **Application-level constraints** (e.g., ActiveRecord validations, Pydantic models): checked only when going through the ORM/model layer. Direct DB access bypasses them.
- **Event-driven systems**: constraints enforce at the event-processing layer, often with saga compensating transactions. No true "atomic" enforcement across services.

## Design principle
**Make illegal states unrepresentable.** If a price can never be negative, the schema should make it impossible to store a negative price — not just unlikely. Each constraint removes an entire class of bugs from every current and future application that touches the database.

## Critical thinking
- `NOT NULL` is the most underused constraint. Many columns that conceptually always have a value are left nullable by default. The cost of making them NOT NULL later (rewriting rows or providing a default) is real — do it at design time.
- `CHECK` constraints cannot reference other tables (use triggers for cross-table rules). They also cannot call non-immutable functions (e.g., `now()` comparisons on static data).
- `EXCLUDE` constraints create a GiST index automatically. This adds write overhead; reserve them for tables where the business rule is critical (reservations, scheduling).

## Creative thinking
- What if you wrote your business rules document in SQL as named CHECK constraints? Then your `git diff` on migration files would literally show "business rule added" or "business rule changed."
- Constraints as CI tests: your integration test suite can insert known-bad rows and assert that the database rejects them. No application logic change can break a DB-level constraint.

## Systems thinking
Constraints form a distributed coordination layer: across read replicas, analytics pipelines, and data lakes, the primary database's constraint log is the authoritative record of what data is valid. Systems downstream can trust the data because the source enforces it.

As systems scale to multiple microservices, constraints become a coordination problem: you can't enforce a FK across service boundaries. This is the real cost of microservice decomposition — you trade DB-level integrity for service autonomy, and you pay with eventual consistency.

## MCP and agent perspective
For AI agents with database write access, constraints are the last line of defense. An agent may generate syntactically correct but semantically invalid SQL (negative price, duplicate email, overlapping reservation). DB-level constraints catch these errors and return a structured error that the agent can inspect, correct, and retry. Without constraints, the agent's bad write succeeds silently.

## Ontology perspective
Constraints are ontological axioms: statements that must be universally true within the system. `NOT NULL` is an existential assertion ("this property always exists"). `UNIQUE` is a uniqueness axiom ("this property identifies"). `FOREIGN KEY` is a referential axiom ("this entity references another that must exist"). Together they define the ontology's integrity conditions.

## Practice session
See `practice/intermediate/01-constraint-driven-design/` for exercises adding and testing each constraint type.

## References
- PostgreSQL docs — Constraints: https://www.postgresql.org/docs/16/ddl-constraints.html
- PostgreSQL docs — EXCLUDE constraint: https://www.postgresql.org/docs/16/sql-createtable.html#SQL-CREATETABLE-EXCLUDE
- PostgreSQL docs — Deferrable constraints: https://www.postgresql.org/docs/16/sql-set-constraints.html
- PostgreSQL docs — btree_gist extension: https://www.postgresql.org/docs/16/btree-gist.html
- "Make Illegal States Unrepresentable" — Yaron Minsky (2011): https://blog.janestreet.com/effective-ml-revisited/
