# Stage 10 — Intermediate Extensions and Non-SQL

Priority: P1

## Goal

Add practical extension-based and non-SQL capabilities.

## Files/directories in scope

- `concepts/intermediate/10-jsonb-modeling-tradeoffs.md`
- `concepts/intermediate/11-full-text-search-design.md`
- `concepts/intermediate/12-fuzzy-search-with-pg-trgm.md`
- `concepts/intermediate/13-hierarchical-data-with-ltree-and-recursive-cte.md`
- `concepts/intermediate/14-geospatial-intro-with-postgis.md`
- `concepts/intermediate/15-vector-search-with-pgvector.md`
- `practice/intermediate/06-jsonb-modeling/`
- `practice/intermediate/07-full-text-and-fuzzy-search/`
- `practice/intermediate/08-geospatial-intro/`
- `practice/intermediate/09-pgvector-retrieval/`

## Explicitly out of scope

- Future-stage files
- Unrequested full repo content

## Tasks

1. Create lessons and practices
2. Include fallback if extensions unavailable
3. Add agent retrieval and permission notes
4. Add references

## Validation / self-tests

- Extension availability validation
- SQL validation where possible
- Ontology notes include capability/entity/access path

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

After Stage 10, stop and ask permission to continue.
