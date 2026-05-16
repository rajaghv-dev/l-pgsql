# Normalization and Denormalization
Level: Intermediate

## One-line intuition
Normalization means "each fact is stored exactly once"; denormalization means "store a fact more than once to serve reads faster."

## Why this exists
E.F. Codd formalized normal forms in 1970 to eliminate a class of data anomalies: update anomalies (changing one fact in one row but not others), insertion anomalies (can't record a fact without another fact), and deletion anomalies (deleting a row accidentally destroys unrelated facts). Normal forms are the solution.

Denormalization exists because normal forms optimize for write integrity, not read performance. Real systems almost always need both, applied to different parts of the schema.

## First-principles explanation
A **functional dependency** is "if you know X, you can determine Y." Normal forms are rules about where functional dependencies may live within a table:

- **1NF**: Every column holds atomic (indivisible) values. No repeating groups. Each row is uniquely identifiable.
- **2NF**: All non-key columns depend on the *whole* primary key (eliminates partial dependency — relevant only when PK is composite).
- **3NF**: All non-key columns depend *directly* on the primary key and not on other non-key columns (eliminates transitive dependency).

BCNF, 4NF, 5NF exist but 3NF is the practical target for most OLTP schemas.

## Micro-concepts
| Concept | Short definition |
|---|---|
| Functional dependency | X → Y: knowing X determines Y |
| Partial dependency | Non-key column depends on part of a composite PK (violates 2NF) |
| Transitive dependency | Non-key column A depends on non-key column B → PK (violates 3NF) |
| Update anomaly | Same fact stored in multiple rows; updating one row leaves others stale |
| Insertion anomaly | Can't record a fact without a required unrelated fact |
| Deletion anomaly | Deleting a row removes facts about unrelated entities |
| JSONB | PostgreSQL semi-structured column; controlled, schema-aware denormalization |
| Array column | PostgreSQL `INTEGER[]` / `TEXT[]`; avoids a join table for simple 1:N |

## Beginner view
**1NF rule in plain language**: No cell should contain multiple values (no comma-separated lists in a column). Each row should have a unique identifier.

```sql
-- Violates 1NF: multiple values in one column
orders(id, customer_name, product_ids)  -- "1,2,3" in product_ids

-- 1NF compliant: split to order_items
order_items(order_id, product_id, qty)
```

**3NF rule in plain language**: "If you're updating the same data in two places, normalize it."

```sql
-- Violates 3NF: zip_code → city (transitive: zip determines city, not customer PK)
customers(id, name, zip_code, city)

-- 3NF compliant: extract zip→city to its own table
zip_codes(zip_code, city, state)
customers(id, name, zip_code)  -- FK → zip_codes
```

## Intermediate view
**When 1NF matters**: Always. Atomic values enable WHERE filtering, indexing, and JOINs. Storing CSV in a column forces application-side parsing and blocks SQL predicates.

**When 2NF matters**: When you have composite primary keys (common in junction tables). A junction table `order_items(order_id, product_id, qty, product_name)` violates 2NF because `product_name` depends only on `product_id`, not the composite PK.

**When 3NF matters**: When non-key data can drift. In an `employees` table with `(id, dept_id, dept_name)`, updating a department name requires updating every employee row for that department. Extract `departments(id, name)` and reference by FK.

**JSONB as controlled denormalization**: When product attributes vary by category (a book has ISBN; a shirt has size), use a JSONB column instead of hundreds of nullable columns. You trade schema enforcement for flexibility, knowingly.

```sql
CREATE TABLE products (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    price       NUMERIC(10,2) NOT NULL,
    attrs       JSONB          -- flexible per-category attributes
);
-- Index specific JSONB key for query performance:
CREATE INDEX ON products USING GIN (attrs);
```

**Array column as lightweight denormalization**:
```sql
-- Instead of a tags junction table, for simple read-mostly tags:
CREATE TABLE articles (
    id    SERIAL PRIMARY KEY,
    title TEXT,
    tags  TEXT[]
);
CREATE INDEX ON articles USING GIN (tags);
-- Query: WHERE 'postgres' = ANY(tags)
```

## Advanced view
**Denormalization strategies**:
1. **Duplicate a column** — copy `customer_name` into `orders` for fast display without JOIN. Maintain via trigger or application.
2. **Summary/aggregate table** — precompute totals. Maintained by trigger or scheduled job.
3. **Materialized view** — PostgreSQL-native. `REFRESH MATERIALIZED VIEW CONCURRENTLY` for near-zero locking.
4. **Partial denormalization via GENERATED column** — `total NUMERIC GENERATED ALWAYS AS (qty * unit_price) STORED`. Engine keeps it in sync.

```sql
-- Generated column: automatic, zero maintenance
ALTER TABLE order_items
    ADD COLUMN line_total NUMERIC(12,2)
        GENERATED ALWAYS AS (qty * unit_price) STORED;
```

**When to stop normalizing**: BCNF eliminates all anomalies but can produce schemas so fragmented that queries are hard to reason about and maintain. 3NF is the practical stopping point for most schemas.

## Mental model
Imagine a news organization's style book: each style rule is written once, centrally. That's normalization. A reporter's cheat sheet duplicates the 20 most-used rules — that's denormalization for a specific access pattern (quick reference while writing).

## PostgreSQL view
PostgreSQL features that support both sides:
- `FOREIGN KEY` — enforces normalization at DB level (referential integrity).
- `GENERATED ALWAYS AS (...) STORED` — computed column, engine-maintained denormalization.
- `JSONB` + GIN index — queryable semi-structured denormalization.
- `ARRAY` type + GIN index — lightweight denormalization for set-like data.
- `MATERIALIZED VIEW` — explicit read-model; `REFRESH MATERIALIZED VIEW CONCURRENTLY` avoids lock.
- `pg_stat_user_tables` — shows `seq_scan` vs `idx_scan` counts; use to measure read access patterns.

## SQL view
```sql
-- 1NF violation → fix
-- BAD:
CREATE TABLE orders_bad (
    id INT, customer_name TEXT, product_list TEXT  -- "Pen,Notebook"
);
-- GOOD:
CREATE TABLE order_items (
    order_id INT REFERENCES orders(id),
    product_id INT REFERENCES products(id),
    qty INT NOT NULL,
    PRIMARY KEY (order_id, product_id)
);

-- 3NF violation → fix
-- BAD: city depends on zip, not on customer id
CREATE TABLE customers_bad (
    id INT PRIMARY KEY, name TEXT, zip TEXT, city TEXT
);
-- GOOD:
CREATE TABLE zip_codes (zip TEXT PRIMARY KEY, city TEXT, state CHAR(2));
CREATE TABLE customers (
    id INT PRIMARY KEY, name TEXT, zip TEXT REFERENCES zip_codes(zip)
);

-- JSONB controlled denormalization
CREATE TABLE products (
    id    SERIAL PRIMARY KEY,
    name  TEXT NOT NULL,
    attrs JSONB
);
-- validation: Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled
```

## Non-SQL or hybrid view
- **MongoDB** encourages embedding (1NF violations by relational standards). Works well for hierarchical documents with a single access pattern. Multi-document transactions are an afterthought.
- **Column stores** (Redshift, BigQuery) are inherently denormalized and optimized for aggregate scans. They are the natural destination for data that has already gone through normalization in OLTP.
- **Event sourcing** avoids normal forms entirely — events are immutable, append-only facts. The "current state" is a read-side projection: an explicit denormalization.

## Design principle
**Normalize for writes, denormalize for reads — and make the denormalization explicit.** Every duplicated column should have a comment or a migration note explaining which source of truth it copies and how it stays in sync.

## Critical thinking
- Normal forms are mathematical, but schema design is a trade-off exercise. A 3NF schema for a heavily read-aggregated report may still perform poorly without a separate materialized model.
- JSONB is not a cure for poor schema design — it is appropriate for genuinely variable-shape data. Using it to avoid schema design work accumulates technical debt.
- Arrays in PostgreSQL bypass relational integrity: `tags TEXT[]` cannot have a FK relationship. Use them only when the values are safe to be orphaned (e.g., display labels, not FK references).

## Creative thinking
- What if you expressed your normal form violations as tests? A CI pipeline could run `SELECT` queries that detect repeating groups or transitive dependencies and fail if they return rows.
- "Normalize the schema, denormalize the questions." Write queries against a fully normalized schema first; then measure; then introduce denormalization only where measurement shows it's needed.

## Systems thinking
Normalization and denormalization interact with your deployment lifecycle:
- Highly normalized schemas require more JOIN-heavy migrations when adding features.
- Denormalized columns require keeping copies in sync — a coordination problem that grows with team size.
- At large scale (read replicas, sharding) denormalization reduces cross-shard joins but complicates consistency.

## MCP and agent perspective
Agents writing SQL benefit from normalization: a constraint violation from a well-normalized schema tells the agent precisely what invariant was broken, enabling self-correction. Denormalized schemas silently accept partial updates that leave the database in an inconsistent state.

## Ontology perspective
Normal forms are an ontology discipline: each concept (entity) lives in exactly one place, with a single identity. Denormalization introduces aliases — a concept with two representations. Managing aliases requires synchronization protocols (triggers, events, ETL) that are themselves ontological commitments.

## Practice session
See `practice/intermediate/00-schema-design/` for exercises identifying and fixing 2NF/3NF violations in an e-commerce schema.

## References
- Codd, E.F. (1970). "A Relational Model of Data for Large Shared Data Banks." *Communications of the ACM*.
- PostgreSQL docs — Array types: https://www.postgresql.org/docs/16/arrays.html
- PostgreSQL docs — JSONB: https://www.postgresql.org/docs/16/datatype-json.html
- PostgreSQL docs — Generated Columns: https://www.postgresql.org/docs/16/ddl-generated-columns.html
- Fundamentals of Database Systems, Elmasri & Navathe, Ch. 14-15
- Use The Index, Luke — Indexes and normalization: https://use-the-index-luke.com/sql/table-design/indexes-finally-explained
