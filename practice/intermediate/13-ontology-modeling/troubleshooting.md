# Troubleshooting — Ontology-Driven Schema Design

## ERROR: type "ltree" does not exist
**Cause:** `ltree` extension not installed.
**Fix:** `CREATE EXTENSION IF NOT EXISTS ltree;`

## ERROR: type "vector" does not exist
**Cause:** `pgvector` extension not installed.
**Fix:** `CREATE EXTENSION IF NOT EXISTS vector;`
Note: vector IS available in cfp_postgres.

## ltree <@ operator returns no results
**Cause 1:** Path format incorrect — labels must be alphanumeric or underscore only (no dots within a label).
**Cause 2:** Parent path does not match exactly.
```sql
-- Check actual paths:
SELECT name, path::text FROM topics ORDER BY path;
```
**Fix:** Ensure paths follow the `label.label.label` format with no spaces.

## search_vector column is NULL
**Cause:** GENERATED ALWAYS AS STORED requires that the expression evaluates successfully. If `to_tsvector` receives NULL, the result is NULL (not an error).
**Fix:** Use `COALESCE(abstract, '')` in the generation expression:
```sql
setweight(to_tsvector('english', COALESCE(abstract, '')), 'B')
```
The setup.sql already handles this.

## JSONB array containment doesn't find elements
**Error/symptom:** `WHERE bio_data @> '{"specialties": ["PostgreSQL"]}'` returns 0 rows.
**Diagnosis:** Check the actual JSONB array:
```sql
SELECT bio_data -> 'specialties' FROM speakers;
```
**Fix:** JSONB array containment `@>` requires the query value to be a JSONB array too. Ensure the literal is valid JSON: `'["PostgreSQL"]'::jsonb` (within the object: `'{"specialties":["PostgreSQL"]}'::jsonb`).

## FK violation on seed data
**Error:** `ERROR: insert or update on table "talks" violates foreign key constraint`
**Cause:** Seed data inserts in wrong order — child before parent.
**Fix:** Run setup.sql in a single transaction; seed data order matters. Conference and Speaker must exist before Talk, etc.

## Ontology consistency queries return unexpected results
**Symptom:** "accepted talks with no accepted submission" query returns rows even after correct setup.
**Cause:** In the seed data, talks with status 'accepted' all have corresponding accepted submissions. If rows are missing, re-run setup.sql.
**Note:** This query is a data quality check — it is expected to return 0 rows for a consistent dataset.
