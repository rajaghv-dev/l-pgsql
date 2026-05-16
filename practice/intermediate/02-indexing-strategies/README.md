# Practice: Indexing Strategies

Level: Intermediate
Stage: 8
Concept files: `concepts/intermediate/04-index-selection.md`, `05-composite-partial-expression-indexes.md`

## Goal
Generate a realistic data set (~100k rows) and compare query plans with and without different index types. You will observe:
- The transition from Seq Scan to Index Scan to Index Only Scan
- How GIN indexes enable JSONB containment queries
- How partial indexes reduce index size and improve targeted queries
- How EXPLAIN (ANALYZE, BUFFERS) reveals buffer hits vs. disk reads

## Domain
An `events` table (click-stream / audit log style) with:
- A timestamp column (BRIN candidate)
- A JSONB payload column (GIN candidate)
- A status column with low cardinality (partial index candidate)
- An email column (expression index candidate for LOWER)

## Setup
```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < setup.sql
```
Generation of 100k rows uses `generate_series` — may take a few seconds.

## Files
| File | Purpose |
|---|---|
| `README.md` | This file |
| `setup.sql` | Schema + 100k row seed using generate_series |
| `00-setup-validation.md` | Row counts and index inspection queries |
| `exercises.md` | EXPLAIN ANALYZE comparison exercises |
| `solutions.md` | Reference EXPLAIN output and index recommendations |
| `reflection.md` | Design discussion prompts |
| `ontology-notes.md` | Access-path ontology |
| `troubleshooting.md` | Common indexing errors and diagnostics |
| `references.md` | Further reading |
