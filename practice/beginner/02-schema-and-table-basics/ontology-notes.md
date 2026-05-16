# Ontology Notes — Practice 02: Schema and Table Basics

---

## Concept Map

```
[[PostgreSQL Database]] (cfp)
    └── [[Schema]] (store)
            ├── [[Table]]: store.customers
            │       ├── [[Column]]: id (BIGSERIAL PK)
            │       ├── [[Column]]: name (TEXT)
            │       ├── [[Column]]: email (TEXT)
            │       └── [[Column]]: created_at (TIMESTAMPTZ)
            │
            ├── [[Table]]: store.products
            │       ├── [[Column]]: id (BIGSERIAL PK)
            │       ├── [[Column]]: name (TEXT)
            │       ├── [[Column]]: sku (VARCHAR)
            │       ├── [[Column]]: price (NUMERIC)
            │       └── [[Column]]: created_at (TIMESTAMPTZ)
            │
            └── [[Table]]: store.orders
                    ├── [[Column]]: id (BIGSERIAL PK)
                    ├── [[Column]]: customer_id (BIGINT FK → customers.id)
                    ├── [[Column]]: status (TEXT)
                    └── [[Column]]: ordered_at (TIMESTAMPTZ)

[[DDL]] (Data Definition Language)
    ├── [[CREATE SCHEMA]]
    ├── [[CREATE TABLE]]
    ├── [[ALTER TABLE]]
    │       ├── ADD COLUMN
    │       ├── RENAME COLUMN
    │       └── ALTER COLUMN TYPE
    └── [[DROP TABLE]]

[[System Catalogs]]
    ├── [[information_schema]] (SQL standard, portable)
    │       ├── schemata
    │       ├── tables
    │       └── columns
    └── [[pg_catalog]] (PostgreSQL-specific, complete)
            ├── [[pg_class]] (all relations)
            ├── [[pg_namespace]] (schemas)
            ├── [[pg_attribute]] (columns)
            └── [[pg_constraint]] (constraints)
```

---

## Key relationships

| Concept | Relation | Concept |
|---------|----------|---------|
| [[Schema]] | contains | [[Table]] |
| [[Table]] | has many | [[Column]] |
| [[Table]] | has many | [[Constraint]] |
| [[BIGSERIAL]] | creates | [[Sequence]] |
| [[pg_class]] | describes | [[Table]], [[Index]], [[Sequence]] |
| [[information_schema]] | mirrors | [[pg_catalog]] (standard view) |

---

## Wikilinks for Obsidian

- [[Schema]]
- [[CREATE SCHEMA]]
- [[CREATE TABLE]]
- [[ALTER TABLE]]
- [[DROP TABLE]]
- [[DDL]]
- [[information_schema]]
- [[pg_catalog]]
- [[pg_class]]
- [[pg_namespace]]
- [[BIGSERIAL]]
- [[NUMERIC]]
- [[VARCHAR]]
- [[TIMESTAMPTZ]]
- [[Foreign Key]]
- [[ON DELETE CASCADE]]
- [[ON DELETE SET NULL]]
- [[search_path]]
