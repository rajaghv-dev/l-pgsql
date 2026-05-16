# Domain Ontology Examples

Level: Intermediate → Advanced
Domain: PostgreSQL / Schema Design / Applied Ontology

## Definition
Domain ontology examples demonstrate how to apply the PostgreSQL ontology to real-world business domains — deriving schema, constraints, indexes, and security policies systematically from a conceptual model.

## Why this concept matters
Ontology thinking is not just classification — it is a design methodology. Walking through three well-understood domains (e-commerce, content management, financial ledger) shows how the same underlying concepts (entity, relationship, cardinality, constraint, RLS) produce different but principled schemas.

## Related concepts
- [[entity-relationship-ontology]] — parent (ER model is the source)
- [[schema-design-ontology]] — parent (schema artifacts produced)
- [[security-ontology]] — related (RLS applied per domain)
- [[ai-agent-memory-ontology]] — related (agent applied to domain data)
- [[performance-ontology]] — related (domain-specific index choices)

---

## Domain 1: E-Commerce

### Ontology model

**Entities**: Customer, Address, Product, Category, Order, OrderItem, Payment, Shipment

**Relationships**:
- Customer `1:N` Address (a customer has many addresses)
- Customer `1:N` Order (a customer places many orders)
- Order `1:N` OrderItem (an order contains many items)
- Product `M:N` Category (a product belongs to many categories — junction: `product_category`)
- Order `1:1` Payment (an order has one payment)
- Order `1:1` Shipment (a fulfilled order has one shipment)
- OrderItem `N:1` Product (each order line references one product)

**Cardinalities drive foreign key placement**:
- FK `orders.customer_id → customers.id`
- FK `order_items.order_id → orders.id`
- FK `order_items.product_id → products.id`
- Junction `product_category(product_id, category_id)`

### Derived schema

```sql
-- blocked: Docker not accessible
CREATE TABLE customers (
    id         BIGSERIAL PRIMARY KEY,
    email      TEXT NOT NULL UNIQUE,
    name       TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE products (
    id          BIGSERIAL PRIMARY KEY,
    sku         TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    price       NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    stock_qty   INTEGER NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    is_active   BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE orders (
    id          BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES customers(id),
    status      TEXT NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','confirmed','shipped','delivered','cancelled')),
    total       NUMERIC(12,2) NOT NULL CHECK (total >= 0),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
    id         BIGSERIAL PRIMARY KEY,
    order_id   BIGINT        NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id BIGINT        NOT NULL REFERENCES products(id),
    quantity   INTEGER       NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE product_category (
    product_id  BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    category_id BIGINT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    PRIMARY KEY (product_id, category_id)
);
```

### Index strategy

```sql
-- blocked: Docker not accessible
-- FK indexes (avoid seq scans on child tables)
CREATE INDEX idx_orders_customer    ON orders (customer_id);
CREATE INDEX idx_order_items_order  ON order_items (order_id);
CREATE INDEX idx_order_items_product ON order_items (product_id);

-- Query patterns
CREATE INDEX idx_orders_status_created ON orders (status, created_at DESC);
CREATE INDEX idx_products_active_sku ON products (is_active, sku) WHERE is_active;
```

### RLS for multi-tenant e-commerce

```sql
-- blocked: Docker not accessible
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders FORCE ROW LEVEL SECURITY;
CREATE POLICY orders_by_tenant ON orders
    USING (customer_id IN (
        SELECT id FROM customers WHERE tenant_id = current_setting('app.tenant_id')::BIGINT
    ));
```

### Key ontology decisions
- `price` is `NUMERIC` not `FLOAT` — exact arithmetic for currency.
- `stock_qty` has a CHECK constraint — prevents negative inventory at the DB level.
- `order_items.unit_price` is denormalized from `products.price` — preserves historical price at time of order.
- `ON DELETE CASCADE` on order_items — child rows deleted when order is deleted.

---

## Domain 2: Content Management System (CMS)

### Ontology model

**Entities**: User, Role, Content, Tag, Category, Media, Comment, Revision

**Relationships**:
- User `M:N` Role (junction: `user_role`)
- Content `N:1` User (content is authored by one user)
- Content `M:N` Tag (junction: `content_tag`)
- Content `N:1` Category (content belongs to one category)
- Content `1:N` Revision (content has many revisions — audit trail)
- Content `1:N` Comment (content receives many comments)
- Comment `N:1` User (comment written by one user)

**Key design decisions from ontology**:
- Revisions are a 1:N child of Content — append-only history.
- Tags are reusable entities in their own table (not stored as arrays) to enable tag-based filtering with full SQL.
- Slugs (URL-safe names) need a UNIQUE constraint per scope.

### Derived schema

```sql
-- blocked: Docker not accessible
CREATE TABLE users (
    id          BIGSERIAL PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    username    TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE content (
    id           BIGSERIAL PRIMARY KEY,
    author_id    BIGINT NOT NULL REFERENCES users(id),
    category_id  BIGINT REFERENCES categories(id),
    title        TEXT NOT NULL,
    slug         TEXT NOT NULL,
    body         TEXT,
    status       TEXT NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft','review','published','archived')),
    published_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ DEFAULT now(),
    UNIQUE (category_id, slug)  -- slug unique per category
);

CREATE TABLE revisions (
    id          BIGSERIAL PRIMARY KEY,
    content_id  BIGINT NOT NULL REFERENCES content(id) ON DELETE CASCADE,
    author_id   BIGINT NOT NULL REFERENCES users(id),
    body        TEXT NOT NULL,
    saved_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE tags (
    id   BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE
);

CREATE TABLE content_tag (
    content_id BIGINT NOT NULL REFERENCES content(id) ON DELETE CASCADE,
    tag_id     BIGINT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (content_id, tag_id)
);
```

### Full-text search

```sql
-- blocked: Docker not accessible
-- Add tsvector column for full-text search
ALTER TABLE content ADD COLUMN tsv TSVECTOR
    GENERATED ALWAYS AS (
        to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))
    ) STORED;

CREATE INDEX idx_content_tsv ON content USING GIN (tsv);

-- Search
SELECT id, title FROM content WHERE tsv @@ to_tsquery('english', 'postgresql & index');
```

### RLS: published content is public; drafts visible only to author

```sql
-- blocked: Docker not accessible
ALTER TABLE content ENABLE ROW LEVEL SECURITY;

CREATE POLICY published_public ON content
    FOR SELECT
    USING (status = 'published');

CREATE POLICY author_sees_own ON content
    FOR SELECT
    USING (author_id = current_setting('app.user_id')::BIGINT);
```

### Key ontology decisions
- Revisions are append-only — no UPDATE on revisions table.
- `slug` is UNIQUE per (category_id, slug) — same slug allowed in different categories.
- Full-text search via `tsvector` generated column — computed and indexed automatically.
- Tags are a separate table (not ARRAY column) — enables `JOIN` filtering and tag statistics.

---

## Domain 3: Financial Ledger

### Ontology model

**Entities**: Account, Transaction, Entry (ledger line), Currency, ExchangeRate, AuditEvent

**Relationships**:
- Account `1:N` Entry (an account has many ledger entries)
- Transaction `1:N` Entry (a transaction produces 2+ entries — double-entry bookkeeping)
- Entry `N:1` Currency (each entry is in a specific currency)

**Invariants derived from domain ontology**:
- Double-entry: every transaction's entries must sum to zero (debits = credits).
- Immutability: entries are never updated or deleted — corrections are new reversing entries.
- Atomicity: all entries for a transaction are committed together.

### Derived schema

```sql
-- blocked: Docker not accessible
CREATE TABLE accounts (
    id          BIGSERIAL PRIMARY KEY,
    code        TEXT NOT NULL UNIQUE,  -- e.g., '1000', 'ASSETS:CASH'
    name        TEXT NOT NULL,
    type        TEXT NOT NULL CHECK (type IN ('asset','liability','equity','income','expense')),
    currency    CHAR(3) NOT NULL DEFAULT 'USD',
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE ledger_transactions (
    id           BIGSERIAL PRIMARY KEY,
    reference    TEXT NOT NULL UNIQUE,  -- external reference / idempotency key
    description  TEXT,
    transacted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    posted_by    TEXT NOT NULL DEFAULT current_user
);

CREATE TABLE ledger_entries (
    id             BIGSERIAL PRIMARY KEY,
    transaction_id BIGINT        NOT NULL REFERENCES ledger_transactions(id),
    account_id     BIGINT        NOT NULL REFERENCES accounts(id),
    amount         NUMERIC(19,4) NOT NULL,  -- positive=debit, negative=credit
    currency       CHAR(3)       NOT NULL,
    entered_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Enforce double-entry: sum of entries per transaction must be 0
-- (implemented as application-level check or constraint trigger)
```

### Double-entry enforcement via constraint

```sql
-- blocked: Docker not accessible
-- Check constraint trigger: entries for a transaction must sum to zero
CREATE OR REPLACE FUNCTION check_double_entry()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    balance NUMERIC;
BEGIN
    SELECT SUM(amount) INTO balance
    FROM ledger_entries
    WHERE transaction_id = NEW.transaction_id;

    IF balance != 0 THEN
        RAISE EXCEPTION 'Transaction % is unbalanced: sum = %', NEW.transaction_id, balance;
    END IF;
    RETURN NEW;
END;
$$;

-- Deferred constraint trigger (checked at COMMIT, not per-row)
CREATE CONSTRAINT TRIGGER check_balance
    AFTER INSERT OR UPDATE ON ledger_entries
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION check_double_entry();
```

### Immutability

```sql
-- blocked: Docker not accessible
-- Prevent modification of posted entries
CREATE OR REPLACE FUNCTION prevent_ledger_modification()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Ledger entries are immutable. Create a reversing entry instead.';
END;
$$;

CREATE TRIGGER no_modify_entries
    BEFORE UPDATE OR DELETE ON ledger_entries
    FOR EACH ROW EXECUTE FUNCTION prevent_ledger_modification();
```

### Account balance query (point-in-time)

```sql
-- blocked: Docker not accessible
SELECT
    a.code,
    a.name,
    SUM(e.amount) AS balance
FROM accounts a
JOIN ledger_entries e ON e.account_id = a.id
WHERE e.entered_at <= $as_of_timestamp
GROUP BY a.id, a.code, a.name;
```

### Key ontology decisions
- `NUMERIC(19,4)` — no floating-point rounding for money.
- `reference` on transactions — idempotency key prevents duplicate posts.
- Entries are immutable — corrections use reversing entries (new rows with opposite sign).
- Deferred constraint trigger — allows inserting all entries before validating the sum.
- Separate `ledger_transactions` from entries — supports linking multiple entries to one business event.

---

## Summary: Ontology to Schema Mapping Checklist

| Ontology step | Schema artifact |
|--------------|----------------|
| Identify entities | One table per entity |
| Identify key attributes | PRIMARY KEY (surrogate or natural) |
| Identify required attributes | NOT NULL constraints |
| Identify unique attributes | UNIQUE constraints |
| Identify valid value ranges | CHECK constraints |
| Identify 1:N relationships | FK on the N side |
| Identify M:N relationships | Junction table with composite PK |
| Identify immutable history | Append-only table + trigger |
| Identify text search need | GIN index on tsvector |
| Identify range/filter queries | B-tree or partial index |
| Identify multi-tenant scope | RLS + tenant_id column |
| Identify monetary values | NUMERIC(p, s), never FLOAT |

---

## Obsidian connections
[[entity-relationship-ontology]] [[schema-design-ontology]] [[security-ontology]] [[sql-ontology]] [[index-ontology]] [[transaction-ontology]] [[ai-agent-memory-ontology]] [[performance-ontology]]

## References
- Double-entry bookkeeping: https://en.wikipedia.org/wiki/Double-entry_bookkeeping
- PostgreSQL triggers: https://www.postgresql.org/docs/16/plpgsql-trigger.html
- Generated columns: https://www.postgresql.org/docs/16/ddl-generated-columns.html
