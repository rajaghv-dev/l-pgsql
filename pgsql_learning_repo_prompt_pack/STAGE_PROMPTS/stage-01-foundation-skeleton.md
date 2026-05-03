# Stage 1 — Foundation Skeleton

Priority: P0

## Goal

Create the top-level structure and minimal repo foundation.

## Files/directories in scope

- `README.md`
- `prompts.md`
- `learning-roadmap.md`
- `beginner-roadmap.md`
- `intermediate-roadmap.md`
- `advanced-roadmap.md`
- `AGENT_GUIDE.md`
- `CONTRIBUTING.md`
- `references.md`
- `extension-map.md`
- `capability-map.md`
- `concepts/`
- `practice/`
- `examples/`
- `diagrams/`
- `ontology/`
- `extensions/`
- `design-principles/`
- `reflections/`
- `scripts/`
- `tools/`

## Explicitly out of scope

- Full lessons
- Full examples
- Advanced content dumps

## Tasks

1. Create minimal but useful top-level files
2. Add placeholders for future stages
3. Explain staged workflow in README.md
4. Explain agent resume workflow in AGENT_GUIDE.md
5. Save reusable prompts in prompts.md
6. Create references.md with a small curated starter list
7. Create extension-map.md skeleton
8. Create capability-map.md skeleton
9. Update session memory

## Validation / self-tests

- Required top-level files exist
- Required directories exist
- README.md explains staged workflow
- AGENT_GUIDE.md explains session memory
- prompts.md contains reusable stage prompts
- references.md exists
- extension-map.md exists
- capability-map.md exists

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

After Stage 1, stop and ask permission to continue to Stage 2.
