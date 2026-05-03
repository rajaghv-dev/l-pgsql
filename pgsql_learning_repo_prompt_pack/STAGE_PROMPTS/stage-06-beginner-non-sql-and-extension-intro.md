# Stage 6 — Beginner Non-SQL and Extension Intro

Priority: P1

## Goal

Introduce PostgreSQL beyond plain SQL.

## Files/directories in scope

- `concepts/beginner/14-jsonb-as-flexible-data.md`
- `concepts/beginner/15-views-as-saved-questions.md`
- `concepts/beginner/16-roles-and-permissions.md`
- `concepts/beginner/17-extensions-as-capability-addons.md`
- `concepts/beginner/18-full-text-search-intuition.md`
- `concepts/beginner/19-vector-search-intuition.md`
- `concepts/beginner/20-ontology-for-database-learning.md`
- `practice/beginner/07-jsonb-basics/`
- `practice/beginner/08-views-and-functions-basics/`
- `practice/beginner/09-roles-basics/`
- `practice/beginner/10-extension-basics/`
- `practice/beginner/11-vector-search-basics/`

## Explicitly out of scope

- Future-stage files
- Unrequested full repo content

## Tasks

1. Create non-SQL beginner lessons
2. Create practices
3. Run extension availability check
4. Document pgvector fallback if unavailable
5. Add agent retrieval examples

## Validation / self-tests

- Practice structure validation
- SQL validation where possible
- Extension availability validation
- Ontology and MCP notes exist

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

After Stage 6, stop and ask permission to continue.
