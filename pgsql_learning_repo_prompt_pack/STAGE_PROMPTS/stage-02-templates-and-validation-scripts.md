# Stage 2 — Templates and Validation Scripts

Priority: P0

## Goal

Create reusable templates and basic self-test scripts.

## Files/directories in scope

- `tools/templates/lesson-template.md`
- `tools/templates/beginner-lesson-template.md`
- `tools/templates/intermediate-lesson-template.md`
- `tools/templates/advanced-lesson-template.md`
- `tools/templates/extension-lesson-template.md`
- `tools/templates/practice-template.md`
- `tools/templates/example-template.md`
- `tools/templates/ontology-template.md`
- `tools/templates/reference-template.md`
- `tools/templates/design-principle-template.md`
- `tools/templates/stage-report-template.md`
- `scripts/README.md`
- `scripts/check-required-files.sh`
- `scripts/validate-practice-structure.sh`
- `scripts/validate-stage.sh`
- `scripts/validate-sql-files.sh`
- `scripts/validate-extension-availability.sql`
- `scripts/run-example.sh`

## Explicitly out of scope

- Actual beginner lessons
- Full examples

## Tasks

1. Create concise templates
2. Create basic validation scripts
3. Ensure scripts are simple and readable
4. Make scripts executable if possible
5. Update session memory

## Validation / self-tests

- All template files exist
- All scripts exist
- Scripts are executable if possible
- validate-stage.sh can check Stage 1 and Stage 2 required files
- validate-extension-availability.sql exists
- practice template contains ontology notes and MCP/agent sections

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

After Stage 2, stop and ask permission to continue to Stage 3.
