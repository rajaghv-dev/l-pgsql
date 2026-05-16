# Schema Design Principles

Principles for designing PostgreSQL schemas that are correct, maintainable, and hard to misuse.

---

## Principle 1: Make it hard to store bad data

### One-line rule
Encode every business rule you can as a constraint — the schema should reject bad data, not just the application.

### Rationale
Applications change. New engineers join. Direct database access happens. The schema is the last line of defense. If the schema allows invalid data, eventually invalid data will be stored.

### Example (correct)
```sql
CREATE TABLE subscriptions (
    id           bigserial PRIMARY KEY,
    user_id      bigint NOT NULL REFERENCES users(id),
    plan         text NOT NULL CHECK (plan IN ('free', 'pro', 'enterprise')),
    started_at   timestamptz NOT NULL DEFAULT now(),
    expires_at   timestamptz,
    CONSTRAINT expiry_after_start CHECK (expires_at IS NULL OR expires_at > started_at)
);
```

### Counter-example (incorrect)
```sql
CREATE TABLE subscriptions (
    id         bigserial PRIMARY KEY,
    user_id    bigint,    -- Can be NULL, can reference nothing
    plan       text,      -- Any string accepted
    started_at timestamp, -- Wrong type, no default
    expires_at timestamp  -- Can be before started_at
);
```

### When this principle applies
Every table in every schema.

### When to break it (with justification)
Staging/import tables used as a landing zone for untrusted external data before validation and transformation. Explicitly mark these with a `_staging` or `_raw` suffix.

### PostgreSQL implementation
Use named constraints for clear error messages:
```sql
CONSTRAINT valid_plan CHECK (plan IN ('free', 'pro', 'enterprise'))
-- Error: new row for relation "subscriptions" violates check constraint "valid_plan"
```

---

## Principle 2: Standardize naming conventions across all tables

### One-line rule
Use `snake_case` for all identifiers; plural table names; `id` for surrogate PKs; `{table}_id` for foreign keys.

### Rationale
Consistent naming makes queries predictable and eliminates ambiguity. Mixing `userId`, `user_id`, and `UserID` in the same schema forces developers to look up every column name.

### Example (correct)
```sql
-- Table: plural noun, snake_case
CREATE TABLE order_items (
    id         bigserial PRIMARY KEY,    -- surrogate PK: always 'id'
    order_id   bigint NOT NULL REFERENCES orders(id),   -- FK: {table}_id
    product_id bigint NOT NULL REFERENCES products(id),
    quantity   int NOT NULL CHECK (quantity > 0),
    unit_price numeric(10,2) NOT NULL
);
```

### Counter-example (incorrect)
```sql
CREATE TABLE OrderItem (    -- Singular, PascalCase — needs quoting in SQL
    ItemID    serial,       -- Non-standard PK name
    orderID   int,          -- camelCase FK name
    ProductId int           -- Mixed case
);
```

### PostgreSQL implementation
PostgreSQL folds unquoted identifiers to lowercase. Never use mixed-case names that require quoting. Establish a project-wide convention in `CONTRIBUTING.md`.

---

## Principle 3: Add audit columns to every application table

### One-line rule
Include `created_at`, `updated_at`, and optionally `deleted_at` on every table that tracks application entities.

### Rationale
Audit columns answer "when was this created?", "when was it last changed?", and "is it soft-deleted?" without requiring a separate audit table for basic time tracking. They are invaluable for debugging production incidents.

### Example (correct)
```sql
CREATE TABLE users (
    id         bigserial PRIMARY KEY,
    email      text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz  -- NULL = active, not NULL = soft-deleted
);

-- Trigger to auto-update updated_at:
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### Counter-example (incorrect)
```sql
CREATE TABLE users (
    id    bigserial PRIMARY KEY,
    email text NOT NULL UNIQUE
    -- No audit columns: impossible to know when a row was created or changed
);
```

### When to break it (with justification)
Lookup/reference tables (e.g., `countries`, `currencies`) may not need audit columns if they are only changed by migrations. Still add `created_at` as a minimum.

---

## Principle 4: Normalize to at least 3NF before adding relationships

### One-line rule
Ensure each non-key column depends only on the primary key — not on another non-key column.

### Rationale
Transitive dependencies (3NF violations) cause update anomalies: you update a city's country in one row but not others, and now the same city has two different countries in your database.

### Example (correct)
```sql
-- 3NF: city is in a separate table; country comes from city
CREATE TABLE countries (id bigserial PRIMARY KEY, name text NOT NULL);
CREATE TABLE cities (
    id         bigserial PRIMARY KEY,
    name       text NOT NULL,
    country_id bigint NOT NULL REFERENCES countries(id)
);
CREATE TABLE users (
    id      bigserial PRIMARY KEY,
    email   text NOT NULL,
    city_id bigint REFERENCES cities(id)  -- Get country via city JOIN countries
);
```

### Counter-example (incorrect)
```sql
CREATE TABLE users (
    id          bigserial PRIMARY KEY,
    email       text,
    city        text,
    country     text  -- Depends on city, not on user id — 3NF violation
);
```

---

## Principle 5: Use schemas as namespaces — one per bounded context

### One-line rule
Group related tables in named schemas (`auth`, `billing`, `analytics`) rather than putting everything in `public`.

### Rationale
Schemas enable access control at the namespace level (`GRANT USAGE ON SCHEMA billing TO billing_role`), reduce naming collisions, and make the domain model visible in the schema structure itself.

### Example (correct)
```sql
CREATE SCHEMA auth;
CREATE SCHEMA billing;
CREATE SCHEMA analytics;

CREATE TABLE auth.users (...);
CREATE TABLE auth.sessions (...);
CREATE TABLE billing.subscriptions (...);
CREATE TABLE billing.invoices (...);
CREATE TABLE analytics.events (...);
```

### Counter-example (incorrect)
```sql
-- All 50 tables in public — domain boundaries invisible
CREATE TABLE users (...);
CREATE TABLE sessions (...);
CREATE TABLE subscriptions (...);
CREATE TABLE events (...);
```

### When to break it (with justification)
Small projects with fewer than 10 tables where the overhead of schema management outweighs the benefit. Revisit when the table count grows.
