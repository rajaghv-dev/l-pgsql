# Stage 17 — Advanced Examples

Priority: P2

## Goal

Create advanced architecture examples.

## Files/directories in scope

- `examples/advanced/hybrid-search-system/`
- `examples/advanced/finance-ledger/`
- `examples/advanced/support-ticketing/`
- `examples/advanced/event-sourcing-audit/`
- `examples/advanced/time-series-monitoring/`
- `examples/advanced/rls-saas-platform/`
- `examples/advanced/ai-agent-memory-platform/`

## Explicitly out of scope

- Future-stage files
- Unrequested full repo content

## Tasks

1. Create advanced examples
2. Test invariants
3. Add performance/observability checks where appropriate
4. Add agent-safe design notes

## Validation / self-tests

- Required files exist
- SQL validates where possible
- Invariants are tested

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

After Stage 17, stop and ask permission to continue.
