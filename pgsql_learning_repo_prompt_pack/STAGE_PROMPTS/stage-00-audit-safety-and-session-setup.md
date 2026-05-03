# Stage 0 — Audit, Safety, and Session Setup

Priority: P0

## Goal

Inspect the repo safely and create the session/memory system.

## Files/directories in scope

- `STAGES.md`
- `.learning-session/README.md`
- `.learning-session/current-stage.md`
- `.learning-session/stage-history.md`
- `.learning-session/repo-memory.md`
- `.learning-session/decisions.md`
- `.learning-session/open-questions.md`
- `.learning-session/validation-log.md`
- `.learning-session/generated-files.md`
- `.learning-session/next-actions.md`
- `.learning-session/agent-handoff.md`
- `.learning-session/prompts-used.md`
- `TODO.md`
- `CHANGELOG.md`

## Explicitly out of scope

- Beginner lessons
- Examples
- Advanced content
- Practice content

## Tasks

1. Inspect current directory
2. Check whether git is initialized
3. Check current git status
4. Check whether Docker is available
5. Check whether psql is available
6. Create session/memory files
7. Create or update STAGES.md
8. Record assumptions
9. Do not create full learning content yet

## Validation / self-tests

- Verify .learning-session/ exists
- Verify all session files exist
- Verify STAGES.md exists
- Verify current-stage.md says Stage 0
- Verify TODO.md and CHANGELOG.md exist

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

After Stage 0, stop and ask permission to continue to Stage 1.
