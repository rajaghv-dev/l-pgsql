# Practice 02: Schema and Table Basics

Level: Beginner

---

## Goal

Create a schema, create tables for a small e-commerce model, inspect the structure using pg_catalog and information_schema, and practice ALTER TABLE and DROP TABLE.

---

## Prerequisites

- Completed Practice 01
- Read concepts: `03-database-schema-table-row-column.md`, `04-data-types-and-values.md`

---

## How to Connect

```bash
docker exec -it cfp_postgres psql -U cfp -d cfp
```

Run setup:
```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < practice/beginner/02-schema-and-table-basics/setup.sql
```

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Domain model: small e-commerce

```
Schema: store

customers                    products
┌────┬────────┬──────────┐   ┌────┬────────────┬──────────────┬──────────┐
│ id │ name   │ email    │   │ id │ name       │ price        │ sku      │
└────┴────────┴──────────┘   └────┴────────────┴──────────────┴──────────┘

orders
┌────┬─────────────┬────────────┬───────────┐
│ id │ customer_id │ ordered_at │ status    │
└────┴─────────────┴────────────┴───────────┘
  │
  FK → customers.id
```

---

## What this practice covers

1. Creating a schema with `CREATE SCHEMA`
2. Creating tables with various column types
3. Using `information_schema` to inspect tables and columns
4. Adding a column with `ALTER TABLE ... ADD COLUMN`
5. Renaming a column with `ALTER TABLE ... RENAME COLUMN`
6. Dropping a table with `DROP TABLE`
7. Understanding `pg_catalog` system tables

---

## Files in this folder

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `setup.sql` | Idempotent schema + table creation + seed |
| `00-setup-validation.md` | Verify schema and tables exist |
| `exercises.md` | 8 exercises on DDL and inspection |
| `solutions.md` | Full solutions |
| `reflection.md` | Thinking questions |
| `ontology-notes.md` | Concept map |
| `troubleshooting.md` | Common DDL errors |
| `references.md` | Docs and resources |
