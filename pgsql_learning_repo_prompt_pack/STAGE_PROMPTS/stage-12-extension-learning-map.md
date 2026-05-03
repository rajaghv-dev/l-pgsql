# Stage 12 — Extension Learning Map

Priority: P1

## Goal

Create structured extension learning system.

## Files/directories in scope

- `extensions/README.md`
- `extensions/vector/pgvector.md`
- `extensions/search/pg-trgm.md`
- `extensions/geospatial/postgis.md`
- `extensions/security/pgcrypto.md`
- `extensions/observability/pg-stat-statements.md`
- `extensions/data-types/ltree.md`
- `extensions/foreign-data/postgres-fdw.md`

## Explicitly out of scope

- Future-stage files
- Unrequested full repo content

## Tasks

1. Create concise extension lessons
2. Include beginner/intermediate/advanced views
3. Include setup, validation, use/not-use, ontology, references

## Validation / self-tests

- Extension files exist
- Each has setup and validation
- validate-extension-availability.sql covers these
- References included or TODO marked

## Required session updates

Update:

- `.learning-session/current-stage.md`
- `.learning-session/stage-history.md`
- `.learning-session/repo-memory.md`
- `.learning-session/validation-log.md`
- `.learning-session/generated-files.md`
- `.learning-session/next-actions.md`
- `.learning-session/agent-handoff.md`

## MCP/agent rule

Where relevant, include MCP/agent perspective, permission boundary, audit event, human approval, failure mode, recovery/rollback, and ontology connection.

For beginner stages, keep this simple.

For regulated-domain examples, use synthetic data only and avoid professional advice logic.

## Done criteria

Follow `DONE_CRITERIA.md`.

Do not mark this stage complete unless validation passed or blockers are clearly documented.

## Stop condition

After Stage 12, stop and ask permission to continue.
