# Practice: JSONB Modeling

**Stage:** 10 — Non-SQL Capabilities
**Concept file:** `concepts/intermediate/10-jsonb-modeling-tradeoffs.md`
**Level:** Intermediate

## Goal
Build a product catalog with JSONB attributes, practice GIN indexing, containment queries, JSONB updates, and field promotion decisions.

## Schema overview
- `products` — product table with a `attributes JSONB` column for variable per-category attributes
- `jsonb_field_registry` — informal data dictionary for documenting JSONB fields

## Files
| File | Purpose |
|---|---|
| `setup.sql` | Create tables and seed data |
| `00-setup-validation.md` | Confirm setup |
| `exercises.md` | Step-by-step exercises |
| `solutions.md` | Expected outputs |
| `reflection.md` | Deeper questions |
| `ontology-notes.md` | Ontology framing |
| `troubleshooting.md` | Common errors |
| `references.md` | Links |

## Docker note
All SQL is blocked: Docker not accessible in this session.
