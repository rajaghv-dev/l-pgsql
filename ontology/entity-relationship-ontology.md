# Entity-Relationship Ontology

Level: Beginner → Intermediate
Domain: SQL / Schema Design

## Definition
The entity-relationship (ER) model describes data in terms of entities (things), attributes (properties), and relationships (associations between entities), providing a conceptual blueprint that maps directly to a relational schema.

## Why this concept matters
ER modeling bridges the gap between a business domain and a database schema. A correct ER model catches cardinality errors before any table is created, preventing data anomalies, redundant joins, and broken foreign key constraints that are expensive to fix later.

## Related concepts
- [[schema-design-ontology]] — child (ER maps to tables, columns, constraints)
- [[sql-ontology]] — related (JOIN semantics reflect ER relationships)
- [[domain-ontology-examples]] — related (practical ER applied to domains)
- [[transaction-ontology]] — related (referential integrity is enforced per transaction)

---

## Core ER Concepts

### Entity
One-line definition: A distinct, independently existing thing in the domain that has attributes and can be uniquely identified.

PostgreSQL mapping: Each entity becomes a **table**. The unique identifier becomes the **primary key**.

```sql
-- blocked: Docker not accessible
CREATE TABLE customer (
    id          BIGSERIAL PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

### Attribute
One-line definition: A named property of an entity that holds a value of a specific data type.

PostgreSQL mapping: Each attribute becomes a **column** with a type and optional constraints.

| ER attribute type | PostgreSQL equivalent |
|------------------|-----------------------|
| Simple | `TEXT`, `INTEGER`, `DATE`, etc. |
| Composite | Multiple columns (e.g., `addr_street`, `addr_city`) |
| Multi-valued | Separate child table (1:N) or `ARRAY` or `JSONB` |
| Derived | Computed column or view |
| Key attribute | Column with `PRIMARY KEY` or `UNIQUE NOT NULL` |

---

### Relationship
One-line definition: An association between two or more entities that captures how they interact in the domain.

ER relationships become joins in SQL. The cardinality of the relationship determines the foreign key placement and whether a junction table is needed.

---

### Cardinality

#### One-to-One (1:1)
One row in A relates to at most one row in B.

PostgreSQL pattern: Add a foreign key on either side with a UNIQUE constraint.

```sql
-- blocked: Docker not accessible
CREATE TABLE user_profile (
    user_id BIGINT PRIMARY KEY REFERENCES users(id),
    bio     TEXT
);
```

#### One-to-Many (1:N)
One row in A relates to many rows in B.

PostgreSQL pattern: Foreign key on the "many" side pointing to the "one" side.

```sql
-- blocked: Docker not accessible
CREATE TABLE order_item (
    id       BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id),
    sku      TEXT   NOT NULL
);
```

#### Many-to-Many (M:N)
Many rows in A relate to many rows in B.

PostgreSQL pattern: Junction (associative) table with two foreign keys. The combination of both columns is typically the composite primary key.

```sql
-- blocked: Docker not accessible
CREATE TABLE product_tag (
    product_id BIGINT NOT NULL REFERENCES products(id),
    tag_id     BIGINT NOT NULL REFERENCES tags(id),
    PRIMARY KEY (product_id, tag_id)
);
```

---

### Foreign Key
One-line definition: A column (or group of columns) in a child table whose value must match an existing row in the referenced parent table, enforcing referential integrity.

```sql
-- blocked: Docker not accessible
-- Inspect all FK constraints in the database
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY';
```

ON DELETE behaviors: `RESTRICT`, `CASCADE`, `SET NULL`, `SET DEFAULT`, `NO ACTION`.

Related: [[schema-design-ontology]], [[transaction-ontology]]

---

### Junction Table (Associative Entity)
One-line definition: A table that resolves a M:N relationship by holding foreign keys to both parent entities, often with its own attributes describing the association.

Pattern: When the M:N relationship has attributes (e.g., quantity in order-product), the junction table becomes an entity in its own right.

Related: [[sql-ontology]] (JOINs through junction tables), [[schema-design-ontology]]

---

## ER to PostgreSQL mapping summary

| ER concept | PostgreSQL artifact |
|-----------|---------------------|
| Entity | Table |
| Attribute | Column |
| Key attribute | PRIMARY KEY or UNIQUE NOT NULL |
| Composite attribute | Multiple columns |
| Multi-valued attribute | Child table or ARRAY/JSONB |
| Derived attribute | Generated column or view |
| 1:1 relationship | FK + UNIQUE on one side |
| 1:N relationship | FK on the "N" (child) side |
| M:N relationship | Junction table with two FKs |
| Weak entity | Table with composite PK including parent FK |

---

## System catalog reference
- `pg_constraint` — all constraints including FKs (`contype = 'f'`)
- `information_schema.referential_constraints` — FK metadata
- `information_schema.table_constraints` — all constraint types per table

---

## Beginner mental model
Think of entities as nouns (Customer, Order, Product), attributes as adjectives/facts (name, price, date), and relationships as verbs (Customer places Order, Order contains Product). Draw boxes and lines before writing any CREATE TABLE.

## Intermediate mental model
Cardinality drives schema decisions: 1:1 and 1:N use foreign keys, M:N require a junction table. Always place the FK on the "many" side (child). Identify weak entities (those that depend on a parent for identity) and use composite primary keys with the parent FK included.

## Advanced mental model
ER modeling is a lossy abstraction — the physical schema must account for performance (index strategy per FK), integrity (ON DELETE behavior), and normalization level. Denormalization (embedding child data in JSONB) trades referential integrity for query simplicity. EAV (Entity-Attribute-Value) anti-patterns emerge when developers model dynamic attributes as rows instead of columns; prefer JSONB or separate tables.

## MCP and agent perspective
An AI agent traversing a schema via `information_schema` can reconstruct the ER graph at runtime. The FK graph (`pg_constraint` where `contype = 'f'`) serves as a machine-readable ER diagram. Agents generating SQL for new entities must check FK targets exist and that ON DELETE behavior matches the domain (CASCADE deletes can cause large cascades).

## Practical implication
| Situation | Implication |
|-----------|-------------|
| M:N modeled as two FKs in one table | Breaks normalization; inflexible — use junction table |
| 1:N FK missing index | JOIN scans child table without index; add index on FK column |
| ON DELETE CASCADE on a large table | One parent delete can cascade to millions of child rows |
| Multi-valued attribute in single column (CSV) | Cannot use FK, index, or join — use child table |
| No surrogate key (natural key only) | Natural key changes require cascading updates |

## Obsidian connections
[[schema-design-ontology]] [[sql-ontology]] [[transaction-ontology]] [[domain-ontology-examples]] [[index-ontology]]

## References
- Chen, P.P. (1976). The Entity-Relationship Model: Toward a Unified View of Data.
- PostgreSQL constraints: https://www.postgresql.org/docs/16/ddl-constraints.html
