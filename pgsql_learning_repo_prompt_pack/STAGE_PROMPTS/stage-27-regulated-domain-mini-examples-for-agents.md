# Stage 27 — Regulated Domain Mini Examples for Agents

Priority: P2

## Goal

Create small-scale regulated-domain examples for agents.

## Files/directories in scope

- `examples/intermediate/legal-case-notes-agent/`
- `examples/intermediate/finance-invoice-approval-agent/`
- `examples/intermediate/medical-record-retrieval-agent/`
- `examples/intermediate/pharma-quality-check-agent/`
- `examples/intermediate/office-team-task-agent/`
- `examples/intermediate/compliance-evidence-agent/`

## Explicitly out of scope

- Future-stage files
- Unrequested full repo content

## Tasks

1. Create synthetic examples with MCP tools, approval, audit, security, ontology, practice
2. Avoid professional advice logic

## Validation / self-tests

- Required files exist
- SQL validates where possible
- No real sensitive data
- No diagnosis/treatment/legal/financial advice logic
- Approval and audit models exist

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

After Stage 27, stop and ask permission to continue.
