# Practice: Query Planning with EXPLAIN

Level: Intermediate
Stage: 8
Concept file: `concepts/intermediate/06-query-planning-with-explain.md`

## Goal
Read EXPLAIN output for 4 different query patterns. Identify seq scans that could be avoided. Add missing indexes and compare before/after plans. Use `pg_stat_user_tables` and `pg_stat_statements` to surface and diagnose slow queries.

## Domain
Uses the same `idx_events` table from `practice/intermediate/02-indexing-strategies/` (100k rows), plus the e-commerce schema from Stage 7 (`customers`, `orders`, `order_items`, `products`).

**Run `02-indexing-strategies/setup.sql` first if this is a fresh session.**

## Setup
```bash
# The setup.sql here adds the e-commerce tables and pg_stat_statements
docker exec -i cfp_postgres psql -U cfp -d cfp < setup.sql
```

## Files
| File | Purpose |
|---|---|
| `README.md` | This file |
| `setup.sql` | pg_stat_statements setup + e-commerce schema (if not already present) |
| `00-setup-validation.md` | Confirm pg_stat_statements is active and tables exist |
| `exercises.md` | EXPLAIN reading + plan improvement exercises |
| `solutions.md` | Annotated EXPLAIN output + fix recommendations |
| `reflection.md` | Design discussion prompts |
| `ontology-notes.md` | Query plan as proof structure |
| `troubleshooting.md` | Common EXPLAIN misreadings and fixes |
| `references.md` | Further reading |
