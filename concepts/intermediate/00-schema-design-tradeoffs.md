# Schema Design Tradeoffs
Level: Intermediate

## One-line intuition
The "right" schema is the one that makes your most frequent queries fast and your most critical writes safe — there is no universal answer.

## Why this exists
Relational databases let you represent the same domain in many structurally valid ways. Each choice shifts where the cost lands: on reads, on writes, on migration complexity, or on application logic. Understanding tradeoffs lets you choose deliberately instead of by accident.

## First-principles explanation
A schema is a contract between your data model and your access patterns. Every normalization decision redistributes work:
- **Normalize** → eliminate redundancy, enforce integrity via the schema, pay at read time (JOINs).
- **Denormalize** → accept controlled redundancy, pay at write time (keeping copies in sync), gain at read time (fewer JOINs, simpler queries).

No schema survives contact with evolving requirements unchanged. The secondary question is therefore: how expensive is it to migrate this schema later?

## Micro-concepts
| Concept | Short definition |
|---|---|
| Normalization | Decompose tables to remove redundancy |
| Denormalization | Merge or duplicate data for read performance |
| Access pattern | Which queries run most often and at what volume |
| Schema evolution | ALTER TABLE cost and downtime risk over time |
| JSONB column | PostgreSQL's escape hatch: structured but schemaless within a column |
| Array column | Storing a set of values in one column without a join table |

## Beginner view
Think of normalization as "don't repeat yourself" applied to a database. If a customer's name appears in 10,000 order rows, you're repeating yourself. Extract it to a `customers` table and JOIN when you need it.

## Intermediate view
The decision is about where you pay:
- **Write-heavy systems** (audit logs, event streams) → normalize aggressively. Writes are cheap and rows are small.
- **Read-heavy systems** (reporting, dashboards) → selectively denormalize. Pre-join data once at write time; read it many times cheaply.
- **Mixed systems** → normalize the source-of-truth schema; materialize denormalized views for reads (see `MATERIALIZED VIEW`).

JSONB is not a shortcut around schema design — it is a deliberate choice for semi-structured, variable-shape data (product attributes, event payloads). It trades schema enforcement for flexibility.

## Advanced view
Large systems often layer both approaches:
1. **Normalized OLTP schema** — for transactional writes (INSERT/UPDATE/DELETE with FK integrity).
2. **Denormalized read models** — materialized views, summary tables, or a separate OLAP store (e.g., Redshift, BigQuery) fed by CDC (Change Data Capture).

PostgreSQL's `MATERIALIZED VIEW` with a scheduled `REFRESH` is a lightweight version of this pattern inside one database.

Schema evolution cost is underestimated by beginners:
- Adding a NOT NULL column with no default to a large table requires a rewrite in PostgreSQL < 11.
- PostgreSQL 11+ allows `ADD COLUMN ... DEFAULT <constant>` without a table rewrite.
- Zero-downtime migrations use the expand-contract pattern: add a nullable column → backfill → add NOT NULL → drop old column.

## Mental model
Imagine a filing system. Normalization is one authoritative folder per document — never a copy. Denormalization is a photocopy placed in every drawer that might need it. You choose based on how often each drawer is opened vs. how often documents change.

## PostgreSQL view
PostgreSQL gives you tools at multiple layers of this tradeoff:
- `FOREIGN KEY` → enforces normalization invariants at the DB level.
- `GENERATED ALWAYS AS (expr) STORED` → computed column; automatic denormalization maintained by the engine.
- `JSONB` + GIN index → semi-structured denormalization with queryability.
- `MATERIALIZED VIEW` → explicit denormalized read model, refreshed on demand.
- Table partitioning → splits large tables by range/list/hash; complements denormalized time-series schemas.

## SQL view
```sql
-- Normalized: join at read time
SELECT o.id, c.name, p.title, oi.qty
FROM orders o
JOIN customers c ON c.id = o.customer_id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON p.id = oi.product_id;

-- Denormalized: pre-joined at write time (summary table)
SELECT customer_name, product_title, qty
FROM order_summary;  -- maintained by trigger or application

-- JSONB semi-structured (product attributes vary by category)
SELECT id, attrs->>'color' AS color
FROM products
WHERE attrs @> '{"material": "leather"}';
```

## Non-SQL or hybrid view
- **Document stores** (MongoDB) denormalize by default — the entire order goes in one document. You gain read simplicity; you lose multi-document transactional integrity.
- **Event sourcing** normalizes into append-only events; application logic reconstructs state. The schema is minimal; the complexity moves to the read-side projections.
- **CQRS** separates write model (normalized) from read model (denormalized projections), making the tradeoff explicit at the architecture level.

## Design principle
**Design for your writes; tune for your reads.** Start with a normalized schema that enforces your business rules. Add denormalization only when you have measured a read bottleneck, not before.

## Critical thinking
- A fully normalized schema is not automatically correct — over-normalization can produce schemas where even a simple screen requires 8 JOINs.
- Denormalization is not laziness — it is a deliberate performance contract. Document which columns are derived and how they stay in sync.
- JSONB is not a free lunch: you lose column-level type safety, FK references, and statistics-based planning for individual keys.

## Creative thinking
- What if you treated your schema as an API? Each table is a stable interface. Breaking changes (dropping columns, changing types) require versioning strategies just like REST APIs.
- "Schema-less" is not schema-free — it is schema-in-the-application. JSONB pushes the enforcement burden to application code or triggers.

## Systems thinking
Schema choices compound over time. A denormalized column added for performance becomes a consistency liability when the data it copies changes. Systems without a migration discipline accumulate these liabilities until a major refactor is unavoidable.

Read/write ratios change with scale. A startup's write-heavy phase (few users, frequent updates) may flip to read-heavy at scale (many users, mostly reads). Schema designed only for one phase will struggle in the other.

## MCP and agent perspective
AI agents that generate SQL against a normalized schema are safer: if an agent writes an incorrect `customer_name` into an order row, a FK constraint would block it. With a denormalized copy, the error silently persists. Constraints are guardrails for agent-generated writes.

## Ontology perspective
A schema is an ontology: it declares what entities exist, what properties they have, and how they relate. Normalization aligns the schema with the domain ontology (one entity = one table). Denormalization is a deliberate departure from the ontology for operational reasons.

## Practice session
See `practice/intermediate/00-schema-design/` for hands-on exercises designing an e-commerce schema.

## References
- PostgreSQL docs — DDL: https://www.postgresql.org/docs/16/ddl.html
- PostgreSQL docs — JSONB: https://www.postgresql.org/docs/16/datatype-json.html
- PostgreSQL docs — Materialized Views: https://www.postgresql.org/docs/16/rules-materializedviews.html
- Martin Fowler — Patterns of Enterprise Application Architecture (Fowler, 2002), Chapter 12
- Use The Index, Luke — Schema design: https://use-the-index-luke.com/sql/table-design
