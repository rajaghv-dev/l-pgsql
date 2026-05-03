# Agent Guide

Instructions for resuming work with a coding agent.

## Bootstrap sequence

Read these files in order before doing anything:

1. `pgsql_learning_repo_prompt_pack/AGENT_BOOTSTRAP.md`
2. `pgsql_learning_repo_prompt_pack/CURRENT_STAGE.md`
3. `pgsql_learning_repo_prompt_pack/STAGES.md`
4. `pgsql_learning_repo_prompt_pack/DONE_CRITERIA.md`
5. `pgsql_learning_repo_prompt_pack/.learning-session/agent-handoff.md`
6. `pgsql_learning_repo_prompt_pack/.learning-session/validation-log.md`
7. The matching file under `pgsql_learning_repo_prompt_pack/STAGE_PROMPTS/`

Then: work only on the current stage. Do not skip ahead.

## Session memory

All session state lives in `pgsql_learning_repo_prompt_pack/.learning-session/`:

| File | Purpose |
|------|---------|
| `current-stage.md` | Active stage name and status |
| `stage-history.md` | What was completed and when |
| `repo-memory.md` | Environment facts, rules, decisions |
| `validation-log.md` | Pass/fail/blocked results per stage |
| `generated-files.md` | Files created or updated per stage |
| `next-actions.md` | What the next agent should do |
| `agent-handoff.md` | Short brief for the next agent |
| `open-questions.md` | Unresolved blockers |
| `decisions.md` | Decisions made and why |
| `prompts-used.md` | Prompts used per stage |

## Environment

- PostgreSQL 16.13 via Docker container `cfp_postgres`
- All psql: `docker exec cfp_postgres psql -U cfp -d cfp -c "..."`
- psql not on host PATH
- Docker 29.4.1

## Rules

- Work stage by stage. Never jump ahead.
- Validate before marking complete.
- Use `completed with validation`, `partially completed; validation blocked because...`, or `incomplete; requires repair`.
- Stop after each stage. Ask permission before continuing.
- Use references instead of long content dumps.
- Use synthetic data for regulated-domain examples.
- Never create professional advice logic.

## Reusable prompts

See `pgsql_learning_repo_prompt_pack/prompts.md`.
