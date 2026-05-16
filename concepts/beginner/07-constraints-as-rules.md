# Constraints as Rules

Level: Beginner

---

## One-line intuition

Constraints are rules written once in the database that PostgreSQL enforces on every write — so the application never has to.

---

## Why this exists

Every application enforces rules: "email must not be blank," "price must be positive," "user must exist." The problem is application code:
- Can have bugs
- Can be bypassed (scripts, admin tools, other services)
- Must be duplicated across every language/service that writes to the database

Constraints live at the database layer. They run on every INSERT and UPDATE, regardless of how the data arrives. They never have bugs in the enforcement logic — either the constraint is satisfied or the write is rejected.

---

## First-principles explanation

A constraint is a **predicate** — a true/false condition — that must be satisfied by every row in a table (or by the table as a whole). PostgreSQL evaluates the predicate on every change and raises an error if it fails. Constraints are declarative: you state the rule, PostgreSQL handles the checking.

---

## Micro-concepts: The Five Constraint Types

| Constraint | What it enforces |
|------------|-----------------|
| `NOT NULL` | A column must have a value; NULL is rejected |
| `UNIQUE` | No two rows may have the same value in this column (or column set) |
| `CHECK` | A custom boolean expression that every row must satisfy |
| `PRIMARY KEY` | NOT NULL + UNIQUE combined; uniquely identifies each row |
| `FOREIGN KEY` | Column value must exist as a PK in the referenced table |

---

## Beginner view

Think of constraints as form validation at the database level:

| Web form rule | Database equivalent |
|--------------|---------------------|
| "Email is required" | `email TEXT NOT NULL` |
| "Username must be unique" | `username TEXT UNIQUE` |
| "Age must be 0–120" | `age INTEGER CHECK (age >= 0 AND age <= 120)` |
| "Every row needs an ID" | `id BIGSERIAL PRIMARY KEY` |
| "Order must reference real customer" | `customer_id BIGINT REFERENCES customers(id)` |

The difference: form validation runs in JavaScript (can be bypassed). Database constraints run in PostgreSQL (cannot be bypassed).

---

## Intermediate view

### NOT NULL

```sql
-- Column-level NOT NULL
CREATE TABLE employees (
    id         BIGSERIAL PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name  TEXT NOT NULL,
    email      TEXT NOT NULL
);
```

NULL means "unknown" or "not applicable" — it is not the same as empty string `''` or zero. A NOT NULL constraint says "this value must always be known."

### UNIQUE

```sql
-- Single-column unique
email TEXT NOT NULL UNIQUE

-- Multi-column unique (combination must be unique)
CONSTRAINT uq_user_month UNIQUE (user_id, month_year)
```

A UNIQUE constraint automatically creates an index on the constrained column(s).

### CHECK

```sql
-- Price must be positive
price NUMERIC(10,2) CHECK (price > 0)

-- Status must be one of a set of values
status TEXT CHECK (status IN ('draft', 'published', 'archived'))

-- Named constraint (shows in error messages)
CONSTRAINT chk_price_positive CHECK (price > 0)

-- Multi-column check
CONSTRAINT chk_dates CHECK (end_date >= start_date)
```

CHECK expressions can reference any column in the same row. They cannot reference other tables (use a trigger for that).

### Naming conventions

Always name constraints explicitly. When a violation occurs, PostgreSQL shows the constraint name in the error message — a named constraint makes debugging immediate:

```
ERROR: new row violates check constraint "chk_price_positive"
```

vs

```
ERROR: new row violates check constraint "products_price_check"  -- auto-generated, less clear
```

---

## Advanced view

### Constraint deferral

By default, constraints are checked at the end of each statement. Some can be deferred to end-of-transaction:

```sql
CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
DEFERRABLE INITIALLY DEFERRED
```

Useful when inserting two rows that reference each other (e.g. a chicken-and-egg scenario across tables).

### Exclusion constraints

PostgreSQL supports exclusion constraints beyond UNIQUE — enforcing that no two rows satisfy a given predicate with respect to each other:

```sql
-- No two reservations for the same room may overlap in time
EXCLUDE USING gist (room_id WITH =, during WITH &&)
```

Requires the `btree_gist` extension.

### Partial UNIQUE constraints

A UNIQUE constraint can be conditional:

```sql
-- At most one active subscription per user
CREATE UNIQUE INDEX uq_user_active_subscription
  ON subscriptions (user_id)
  WHERE status = 'active';
```

---

## Mental model

```
INSERT INTO products (name, price, status)
VALUES ('Widget', -5.00, 'unknown');

PostgreSQL evaluation order:
1. NOT NULL check:  name = 'Widget' ✓, price = -5.00 ✓, status = 'unknown' ✓
2. Type check:      all match declared types ✓
3. CHECK (price > 0): -5.00 > 0 = FALSE → ERROR raised
4. Row is NEVER written to disk

Transaction is rolled back automatically.
```

Constraints form a **gate**: the row only reaches disk if it passes every check.

---

## PostgreSQL view

```sql
-- List all constraints on a table
SELECT
    conname        AS constraint_name,
    contype        AS type,
    pg_get_constraintdef(oid) AS definition
FROM   pg_constraint
WHERE  conrelid = 'products'::regclass
ORDER  BY contype;

-- contype values: c=check, f=foreign key, p=primary key, u=unique, n=not null
```

> blocked: Docker not accessible; validate against cfp_postgres when available

In psql: `\d tablename` shows all constraints in the table description.

---

## SQL view

```sql
CREATE TABLE IF NOT EXISTS products (
    id         BIGSERIAL     PRIMARY KEY,
    name       TEXT          NOT NULL,
    sku        VARCHAR(20)   NOT NULL,
    price      NUMERIC(10,2) NOT NULL,
    status     TEXT          NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ   NOT NULL DEFAULT now(),

    -- Named constraints
    CONSTRAINT uq_products_sku           UNIQUE (sku),
    CONSTRAINT chk_products_price_pos    CHECK (price > 0),
    CONSTRAINT chk_products_status_valid CHECK (status IN ('active', 'discontinued', 'draft'))
);

-- Adding a constraint after table creation
ALTER TABLE products
  ADD CONSTRAINT chk_products_name_nonempty CHECK (length(trim(name)) > 0);

-- Dropping a constraint
ALTER TABLE products
  DROP CONSTRAINT chk_products_name_nonempty;

-- Attempt that will fail (demonstrates constraint enforcement)
-- INSERT INTO products (name, sku, price) VALUES ('Widget', 'W-001', -10);
-- ERROR: new row violates check constraint "chk_products_price_pos"
```

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Non-SQL or hybrid view

In application frameworks (Rails, Django, Laravel), validations run in application code before the database write. This is a second layer — useful for user-facing error messages, but not a substitute for database constraints. Both layers together are best practice: the application gives friendly errors, the database is the backstop.

MongoDB has schema validation (JSON Schema rules on collections), but it is optional and less integrated than PostgreSQL's constraint system.

---

## Design principle

**Constraints are the database's API contract.** When you define a constraint, you are documenting and enforcing the invariants of your data model. Every future developer (human or agent) who reads the schema sees what is always true about the data. This is cheaper than documentation alone because the database proves the invariants hold on every write.

---

## Critical thinking

- A web form validates that an email is not empty before sending to the server. Why add `NOT NULL` in the database too? (The form can be bypassed — direct API calls, scripts, migrations, other services. The database constraint is the only guarantee that runs on every write.)
- A CHECK constraint for `status IN ('active', 'inactive')` is later changed to include `'pending'`. How do you do this without downtime? (ADD the new CHECK constraint, DROP the old one — atomic in one transaction; with VALIDATE CONSTRAINT for large tables, use `NOT VALID` first then validate in a separate transaction.)
- Can a constraint enforce a rule across two different tables? (A FK constraint links two tables, but a CHECK constraint only sees the current row. For cross-table rules, use a trigger — but prefer redesigning the schema to avoid the need.)

---

## Creative thinking

Constraints are like the rules of a board game printed on the box. Once defined, every player (write operation) must follow them. The game referee (PostgreSQL) enforces them automatically — you do not need to trust players to follow rules voluntarily. New players (new services, agents, migrations) are subject to the same rules from their first move.

---

## Systems thinking

Constraints interact with the rest of the system:

- **Performance**: NOT NULL and CHECK have near-zero overhead. UNIQUE creates an index (read overhead during inserts, query speed benefit on lookups). FK checks require a lookup in the parent table (index on parent PK — already exists).
- **Migrations**: Adding constraints to large tables can lock them. Use `NOT VALID` + separate `VALIDATE CONSTRAINT` for zero-downtime migrations.
- **Replication**: Constraints are enforced on the primary. Logical replicas do not re-check constraints on the replica side — replication is trusted.
- **ORMs**: SQLAlchemy, Prisma, ActiveRecord can reflect constraints back into model definitions. Constraints in the database stay authoritative even when ORM models are out of date.

---

## MCP and agent perspective

Constraints are the database's **rejection policy** for agent writes. An agent can attempt bold inserts without pre-validating every field — PostgreSQL will reject anything that violates a constraint and return a structured error. The agent can parse the error (`pg_constraint.conname`) to understand which rule was violated and retry with a corrected value. This makes constraint-rich schemas more robust for agentic workloads than loosely typed schemas.

---

## Ontology perspective

Constraints are **axioms** in the ontological sense:
- `NOT NULL` → "every instance must have this property" (mandatory property)
- `UNIQUE` → "no two instances share this value" (functional property with uniqueness)
- `CHECK (status IN (...))` → "this property's range is restricted to this value set" (datatype restriction)
- `PRIMARY KEY` → "this property uniquely identifies every instance" (inverse functional property)
- `FOREIGN KEY` → "this property's value must be an instance of that class" (object property range restriction)

A well-constrained schema is a self-enforcing formal ontology.

---

## Practice session

See `practice/beginner/03-keys-and-constraints/` for exercises that create constraints, observe violations, and recover from errors.

---

## References

| Resource | URL |
|----------|-----|
| PostgreSQL 16 — Constraints | https://www.postgresql.org/docs/16/ddl-constraints.html |
| PostgreSQL 16 — ALTER TABLE | https://www.postgresql.org/docs/16/sql-altertable.html |
| PostgreSQL 16 — NOT VALID constraints | https://www.postgresql.org/docs/16/sql-altertable.html#SQL-ALTERTABLE-DESC-ADD-TABLE-CONSTRAINT |
| PostgreSQL 16 — Exclusion Constraints | https://www.postgresql.org/docs/16/ddl-constraints.html#DDL-CONSTRAINTS-EXCLUSION |
| Zero-downtime constraint add — Braintree | https://github.com/braintree/pg_ha_migrations |
