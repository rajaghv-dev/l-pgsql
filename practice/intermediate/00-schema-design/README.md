# Practice: Schema Design for an E-Commerce Order System

Level: Intermediate
Stage: 7
Concept files: `concepts/intermediate/00-schema-design-tradeoffs.md`, `01-normalization-and-denormalization.md`, `03-join-design-and-cardinality.md`

## Goal
Design and query a realistic multi-table schema for an e-commerce system. You will practice:
- Mapping a domain to tables with correct cardinality
- Identifying and fixing normalization violations
- Making explicit tradeoff decisions between normalization and denormalization

## Domain
An online store with:
- **Customers** — people who buy things
- **Products** — items for sale, with variable attributes (by category)
- **Orders** — a customer's purchase event
- **Order items** — individual line items within an order

## Setup
Run `setup.sql` in the `cfp` database to create all tables and seed data.

```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < setup.sql
```

## Validation
See `00-setup-validation.md` for expected row counts and constraint checks.

## Exercises
See `exercises.md`. Solutions are in `solutions.md`.

## Files
| File | Purpose |
|---|---|
| `README.md` | This file |
| `setup.sql` | Schema + seed data |
| `00-setup-validation.md` | Validation queries and expected output |
| `exercises.md` | Practice problems |
| `solutions.md` | Reference answers |
| `reflection.md` | Design discussion prompts |
| `ontology-notes.md` | Entity/relationship analysis |
| `troubleshooting.md` | Common errors and fixes |
| `references.md` | Further reading |
