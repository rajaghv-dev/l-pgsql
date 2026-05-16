# Practice: Constraint-Driven Design

Level: Intermediate
Stage: 7
Concept file: `concepts/intermediate/02-constraints-as-business-invariants.md`

## Goal
Apply every major PostgreSQL constraint type to a realistic schema. Learn what each constraint prevents, what error it produces, and when to prefer a partial unique index over a UNIQUE constraint.

## Domain
The same e-commerce schema from `practice/intermediate/00-schema-design/`, extended with:
- A booking/reservation sub-system (rooms and reservations)
- Soft-delete pattern for customers

## Key skills practiced
- NOT NULL, UNIQUE, CHECK, EXCLUDE constraints
- DEFERRABLE INITIALLY DEFERRED foreign keys
- Partial unique index (unique within a subset of rows)
- Named constraints for application-level error handling
- Inspecting constraints via `pg_constraint`

## Setup
```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < setup.sql
```

## Files
| File | Purpose |
|---|---|
| `README.md` | This file |
| `setup.sql` | Schema + seed data |
| `00-setup-validation.md` | Validation queries and expected constraint behavior |
| `exercises.md` | Practice problems |
| `solutions.md` | Reference answers |
| `reflection.md` | Design discussion prompts |
| `ontology-notes.md` | Invariants as ontological axioms |
| `troubleshooting.md` | Common constraint errors and fixes |
| `references.md` | Further reading |
