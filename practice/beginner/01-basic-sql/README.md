# Practice 01: Basic SQL

Level: Beginner

---

## Goal

Write the four fundamental SQL statements — SELECT, INSERT, UPDATE, DELETE — against a simple library books table. Each exercise builds on the previous.

---

## Prerequisites

- Completed Practice 00 (environment verified)
- Read concepts: `02-sql-as-a-language-of-questions.md`

---

## How to Connect

```bash
docker exec -it cfp_postgres psql -U cfp -d cfp
```

Run setup.sql first to create and seed the table:
```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < practice/beginner/01-basic-sql/setup.sql
```

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Domain model

A small library catalog:

```
books
┌─────────────────────────────────────────────────────────────┐
│ id │ title            │ author        │ year │ available    │
├────┼──────────────────┼───────────────┼──────┼──────────────┤
│  1 │ Dune             │ Frank Herbert │ 1965 │ true         │
│  2 │ Neuromancer      │ Wm. Gibson    │ 1984 │ true         │
│  3 │ Foundation       │ Isaac Asimov  │ 1951 │ false        │
│  4 │ 1984             │ George Orwell │ 1949 │ true         │
│  5 │ Brave New World  │ A. Huxley     │ 1932 │ false        │
└────┴──────────────────┴───────────────┴──────┴──────────────┘
```

---

## What this practice covers

1. SELECT with WHERE, ORDER BY, LIMIT
2. Filtering with AND, OR, NOT
3. INSERT single and multiple rows
4. UPDATE single and multiple rows
5. DELETE with a WHERE clause
6. Aggregate functions: COUNT, MIN, MAX, AVG
7. LIKE pattern matching
8. Combining filters

---

## Files in this folder

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `setup.sql` | Idempotent table creation + seed data |
| `00-setup-validation.md` | Check the table was created correctly |
| `exercises.md` | 8 exercises on basic SQL |
| `solutions.md` | Full solutions with explanations |
| `reflection.md` | Thinking questions |
| `ontology-notes.md` | Concept map |
| `troubleshooting.md` | Common SQL errors and fixes |
| `references.md` | Docs and resources |
