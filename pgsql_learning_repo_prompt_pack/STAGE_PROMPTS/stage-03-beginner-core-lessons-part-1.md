# Stage 3 — Beginner Core Lessons, Part 1

Priority: P1

## Goal

Create first beginner lessons and practices only.

## Files/directories in scope

- `concepts/beginner/00-what-is-a-database.md`
- `concepts/beginner/01-what-is-postgresql.md`
- `concepts/beginner/02-sql-as-a-language-of-questions.md`
- `practice/beginner/00-environment-setup/`
- `practice/beginner/01-basic-sql/`

## Explicitly out of scope

- Future-stage files
- Unrequested full repo content

## Tasks

1. Create beginner lessons
2. Create environment setup practice
3. Create basic SQL practice
4. Include validation for every setup step
5. Include ontology notes for every practice
6. Add simple MCP/agent notes
7. Run self-tests

## Validation / self-tests

- Required beginner concept files exist
- Practice folders contain all required files
- SQL is syntactically reasonable
- Run setup.sql if PostgreSQL is available
- Document blocked validation if needed

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

After Stage 3, stop and ask permission to continue.
