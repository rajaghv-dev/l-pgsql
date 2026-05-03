# Stage 11 — Intermediate Security, Audit, Observability

Priority: P1

## Goal

Add practical security, audit, observability, and migration patterns.

## Files/directories in scope

- `concepts/intermediate/16-materialized-views-and-refresh-patterns.md`
- `concepts/intermediate/17-functions-triggers-and-audit-patterns.md`
- `concepts/intermediate/18-row-level-security-and-tenant-isolation.md`
- `concepts/intermediate/19-observability-with-pg-stat-statements.md`
- `concepts/intermediate/20-migrations-and-schema-evolution.md`
- `concepts/intermediate/21-ontology-driven-schema-design.md`
- `practice/intermediate/10-rls-and-multi-tenancy/`
- `practice/intermediate/11-audit-triggers/`
- `practice/intermediate/12-observability/`
- `practice/intermediate/13-ontology-modeling/`

## Explicitly out of scope

- Future-stage files
- Unrequested full repo content

## Tasks

1. Create security/audit/observability lessons
2. Create practices
3. Validate RLS tenant isolation
4. Validate audit rows
5. Add agent safety sections

## Validation / self-tests

- RLS practice validates tenant isolation
- Audit trigger practice validates audit row creation
- Observability practice validates or documents fallback

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

After Stage 11, stop and ask permission to continue.
