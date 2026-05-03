# Stage 28 — Advanced Agent Safety, RLS, Audit, and Human Approval

Priority: P2

## Goal

Teach advanced agent-safe architecture using PostgreSQL.

## Files/directories in scope

- `concepts/advanced/25-agent-permission-boundaries-with-rls.md`
- `concepts/advanced/26-human-in-the-loop-database-workflows.md`
- `concepts/advanced/27-agent-auditability-and-evidence-logs.md`
- `concepts/advanced/28-safe-agent-transactions-and-rollbacks.md`
- `ontology/agent-permission-ontology.md`
- `ontology/human-approval-ontology.md`
- `design-principles/mcp-tool-design-principles.md`
- `design-principles/agent-memory-design-principles.md`
- `design-principles/agent-permission-design-principles.md`
- `design-principles/human-in-the-loop-design-principles.md`
- `design-principles/agent-auditability-design-principles.md`
- `design-principles/agent-safe-transaction-design-principles.md`

## Explicitly out of scope

- Future-stage files
- Unrequested full repo content

## Tasks

1. Create advanced agent safety content
2. Include enforcement points, failure modes, human approval, rollback

## Validation / self-tests

- Required files exist
- Each concept includes MCP/agent perspective
- Ontology includes enforcement/failure modes

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

After Stage 28, stop and ask permission to continue.
