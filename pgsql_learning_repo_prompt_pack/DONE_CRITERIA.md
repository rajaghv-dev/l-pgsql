# DONE_CRITERIA

A stage is done only when all required checks for that stage are completed.

## Required completion checks

1. Required files exist.
2. Required directories exist.
3. Required templates, lessons, or examples follow the expected format.
4. Required practice folders contain validation files.
5. SQL files are either tested or marked as blocked with a reason.
6. Self-tests are run.
7. Validation result is recorded.
8. `.learning-session/current-stage.md` is updated.
9. `.learning-session/stage-history.md` is updated.
10. `.learning-session/validation-log.md` is updated.
11. `.learning-session/generated-files.md` is updated.
12. `.learning-session/agent-handoff.md` is updated.
13. `TODO.md` captures remaining gaps.
14. Git status is reported.

## Completion language

Never say `completed` unless validation is done.

Use one of:

- `completed with validation`
- `partially completed; validation blocked because...`
- `incomplete; requires repair`

## Practice completion

A practice session is done only when:

- all required files exist
- setup SQL exists
- validation notes exist
- exercises exist
- solutions exist
- ontology notes exist
- MCP/agent angle exists where relevant
- references exist or TODO references are marked
- SQL is tested or blocked with reason

## Example completion

An example is done only when:

- schema exists
- seed data exists
- queries exist
- validation queries exist
- ontology notes exist
- practice tasks exist
- references exist or TODO references are marked
- synthetic data is used
- unsafe professional advice logic is absent
