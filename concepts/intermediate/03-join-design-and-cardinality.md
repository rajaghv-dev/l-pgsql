# Join Design and Cardinality
Level: Intermediate

## One-line intuition
Cardinality (1:1, 1:N, M:N) determines which table holds the FK, whether you need a junction table, and whether a JOIN will explode or stay flat.

## Why this exists
Every relationship between entities in your domain has a cardinality. Getting it wrong — putting the FK on the wrong side, or skipping a junction table for M:N — creates schemas that either can't represent the data or produce unexpected row multiplication in JOINs.

## First-principles explanation
**Cardinality** is the maximum number of instances of one entity that can be associated with one instance of another:
- **1:1** — Each row in A relates to at most one row in B. Rare; usually means you could merge the tables.
- **1:N** — One row in A relates to many rows in B. The FK lives on the "many" side (B).
- **M:N** — Many rows in A relate to many rows in B. Requires a junction (bridge) table with two FKs.

The FK always lives on the "many" side. This is the single most important rule in relational schema design.

## Micro-concepts
| Concept | Short definition |
|---|---|
| Cardinality | How many instances of one entity can relate to instances of another |
| Junction table | A table whose PK is a composite of two FKs; implements M:N |
| FK directionality | FK always goes on the child (many) side |
| Row multiplication | JOIN of 1:N without GROUP BY returns N rows per parent |
| Covering JOIN | A JOIN that adds columns without multiplying rows |
| Fan-out | One parent row "fans out" to many child rows in a JOIN |
| JSONB array | Alternative to junction table for read-heavy, non-relational M:N |

## Beginner view
```
customers (1) ──── (N) orders        → FK order.customer_id → customers.id
orders    (1) ──── (N) order_items   → FK order_items.order_id → orders.id
products  (M) ──── (N) tags          → junction: product_tags(product_id, tag_id)
```

The "crow's foot" on the N side is where the FK lives.

## Intermediate view
**1:N — the standard case**:
```sql
-- customers has no FK. orders holds the FK to customers.
CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    ordered_at  TIMESTAMPTZ DEFAULT now()
);
```

**M:N — junction table**:
```sql
CREATE TABLE product_tags (
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    tag_id     INT NOT NULL REFERENCES tags(id)     ON DELETE CASCADE,
    PRIMARY KEY (product_id, tag_id)
);
-- The composite PK prevents duplicate associations.
```

**1:1 — unusual; use when splitting a wide table**:
```sql
-- Rarely needed. Example: sensitive data isolated to separate table.
CREATE TABLE customer_profiles (
    customer_id INT PRIMARY KEY REFERENCES customers(id),
    bio         TEXT,
    avatar_url  TEXT
);
-- The PK is also the FK — that's the 1:1 pattern.
```

**JOIN fan-out awareness**:
```sql
-- This returns one row per order_item, not one per order.
SELECT o.id, oi.product_id, oi.qty
FROM orders o
JOIN order_items oi ON oi.order_id = o.id;
-- If order 1 has 5 items, it appears 5 times. Always expected; always intentional.
```

## Advanced view
**When to denormalize M:N into JSONB arrays**:
```sql
-- Instead of product_tags junction table:
ALTER TABLE products ADD COLUMN tag_ids INT[];
-- Pros: no JOIN, simpler queries, good for read-heavy tag filtering.
-- Cons: no FK integrity on tag_ids, no ON DELETE CASCADE, harder aggregate queries.
CREATE INDEX ON products USING GIN (tag_ids);
```
Use JSONB/array only when: (a) the relationship is read-mostly, (b) tag deletion doesn't need cascading, and (c) you don't need to query "all products for a tag" at high frequency.

**FK directionality and ON DELETE behavior** — the design question is: "When the parent is deleted, what should happen to children?"
- `RESTRICT` / `NO ACTION` — default; block parent deletion if children exist.
- `CASCADE` — delete children automatically (use for owned/dependent entities).
- `SET NULL` — unlink children (use for soft references where the child can exist independently).

**Join order and the PostgreSQL planner**: PostgreSQL's query planner chooses join order based on cost estimates derived from table statistics. You cannot directly hint the join order (unlike Oracle). Influencing strategies:
- `ANALYZE` the tables to update statistics.
- `SET join_collapse_limit = 1` to force the explicit join order you wrote (last resort).
- Break a complex query into CTEs — each CTE is a fence; the planner optimizes within but not across (in pre-PG12 behavior; PG12+ can inline CTEs).
- `enable_hashjoin`, `enable_nestloop` GUCs — turn off specific strategies for a session to diagnose planner choices.

**Cardinality estimation errors** are the root cause of most bad query plans:
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders o JOIN order_items oi ON oi.order_id = o.id;
-- Compare "rows=X" (estimate) to "actual rows=Y".
-- Large discrepancy → run ANALYZE, or increase statistics target:
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500;
```

## Mental model
Think of JOIN as a zipper: it merges two sorted sequences by key. 1:N is a zipper where one left tooth connects to multiple right teeth — the result row count is the right-side count. M:N without a junction table would require one column to store multiple values, which breaks 1NF.

## PostgreSQL view
```sql
-- See FK relationships on a table
SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table,
    ccu.column_name AS foreign_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_name = ccu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'orders';

-- Join order forcing (diagnostic use only)
SET join_collapse_limit = 1;
```

## SQL view
```sql
-- Standard 1:N
SELECT c.name, COUNT(o.id) AS order_count
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
GROUP BY c.id, c.name;

-- M:N via junction table
SELECT p.name, t.label
FROM products p
JOIN product_tags pt ON pt.product_id = p.id
JOIN tags t           ON t.id = pt.tag_id
WHERE p.id = 42;

-- M:N via JSONB array (denormalized)
SELECT p.name, t.label
FROM products p
JOIN tags t ON t.id = ANY(p.tag_ids)
WHERE p.id = 42;

-- validation: blocked — Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled
```

## Non-SQL or hybrid view
- **Document databases**: 1:N is expressed by embedding the N documents inside the parent (no JOIN needed). M:N requires application-side resolution or manual cross-document references.
- **Graph databases**: cardinality is expressed as edge types, with properties on edges (equivalent to junction table attributes). M:N is native.
- **ORM layer**: Rails `has_many :through`, Django `ManyToManyField`, SQLAlchemy `relationship(secondary=...)` — all implement the junction table pattern in code.

## Design principle
**Let cardinality drive structure, not convenience.** If you represent a genuine M:N as a denormalized array to avoid a junction table, you have made a deliberate trade: simplicity now, integrity never. Make that trade explicitly and document it.

## Critical thinking
- A junction table with only two FK columns is minimal. Add payload columns (e.g., `quantity`, `added_at`) when the relationship itself has attributes — the junction becomes a first-class entity.
- `LEFT JOIN` vs `INNER JOIN` is a cardinality decision: use LEFT when the parent can exist without children. Mistakenly using INNER JOIN silently drops parent rows with no children — a common data quality bug.
- Circular FK references (A → B → A) require deferred constraints or careful insert ordering. They are a schema smell — reconsider the design.

## Creative thinking
- What if you modeled your entity relationship diagram in SQL itself? Named FK constraints with clear names (`orders_customer_fk`) are a machine-readable ERD embedded in the schema.
- Junction tables can carry temporal data: `product_tags(product_id, tag_id, applied_at, removed_at)` — a full history of M:N relationships without losing data.

## Systems thinking
Cardinality shapes query performance at scale. A 1:N JOIN where N is large (e.g., 10,000 order items per order) can produce massive intermediate result sets. Pagination, keyset pagination, and aggregate pushdown all become essential at scale.

Cross-service M:N relationships (e.g., products in one service, tags in another) cannot be enforced with FK constraints. The junction table becomes an eventually consistent mapping maintained by events — a fundamental distributed systems challenge.

## MCP and agent perspective
When an agent generates INSERT statements for M:N relationships, it must correctly identify the junction table and insert there — not add a column to either parent table. A well-designed schema with clear junction table names and FK constraints makes the structure self-documenting for agents reading the schema.

## Ontology perspective
Cardinality is an ontological multiplicity constraint. In OWL ontology, these are called `owl:FunctionalProperty` (1:1), `owl:ObjectProperty` (1:N), and associations with multiplicity bounds. Relational schemas implement these as structural constraints. The junction table is an n-ary relation reified as an entity — a standard ontological pattern.

## Practice session
See `practice/intermediate/00-schema-design/` for exercises mapping a domain model's cardinality to a schema.

## References
- PostgreSQL docs — Foreign Keys: https://www.postgresql.org/docs/16/ddl-constraints.html#DDL-CONSTRAINTS-FK
- PostgreSQL docs — Planner Configuration: https://www.postgresql.org/docs/16/runtime-config-query.html
- PostgreSQL docs — EXPLAIN: https://www.postgresql.org/docs/16/sql-explain.html
- Use The Index, Luke — Joins: https://use-the-index-luke.com/sql/join
- Elmasri & Navathe, Fundamentals of Database Systems, Ch. 7 (ER-to-Relational mapping)
