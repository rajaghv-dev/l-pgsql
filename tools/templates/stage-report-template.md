# Stage Completion Report

> **How to use this template:**
> Fill in this report at the end of every stage before stopping.
> Save it to `.learning-session/agent-handoff.md` and update `.learning-session/validation-log.md`.
> Do not claim a stage is "completed" unless all validation checks pass or blockers are explicitly documented.
>
> Valid status values: `completed with validation` | `partially completed; validation blocked because...` | `incomplete; requires repair`

---

## Stage name

`Stage <!-- N --> — <!-- Stage Title, e.g., "Templates and Validation Scripts" -->`

## Date

<!-- YYYY-MM-DD -->

## Status

<!-- completed with validation / partially completed; validation blocked because... / incomplete; requires repair -->

---

## Files created

List every file created this stage. Use absolute paths.

| File path | Purpose |
|-----------|---------|
| `/mnt/d/wsl/l-pgsql/<!-- path/to/file -->` | <!-- one-line description --> |
| `/mnt/d/wsl/l-pgsql/<!-- path/to/file -->` | <!-- one-line description --> |

**File count:** <!-- N files created -->

---

## Files modified

List every file modified (not created) this stage.

| File path | What changed |
|-----------|-------------|
| `/mnt/d/wsl/l-pgsql/<!-- path/to/file -->` | <!-- what was changed and why --> |

---

## Validation results

Every stage must validate its own outputs. Run the checks and record results here.

| Check | Command | Result | Notes |
|-------|---------|--------|-------|
| <!-- check description --> | `<!-- command or "manual" -->` | PASS / FAIL / BLOCKED | <!-- notes, error message, or blocker reason --> |
| All required files exist | `find /mnt/d/wsl/l-pgsql/<!-- path --> -type f \| sort` | PASS / FAIL / BLOCKED | <!-- N files found --> |
| SQL runs without error | `docker exec cfp_postgres psql -U cfp -d cfp -c "<!-- SQL -->"` | PASS / FAIL / BLOCKED | <!-- output or error --> |
| <!-- specific validation for this stage --> | `<!-- command -->` | PASS / FAIL / BLOCKED | <!-- notes --> |

**Summary:** <!-- N/M checks passed -->

---

## SQL validation log

For any SQL created or referenced this stage, record the test results:

```bash
# Test command run
docker exec cfp_postgres psql -U cfp -d cfp -c "<!-- SQL -->"
```

```
# Output
<!-- paste actual output -->
```

Status: PASS / FAIL / BLOCKED — <!-- reason if not PASS -->

---

## Blockers

Document any check that could not be completed and why:

| Blocker | Reason | Impact | Proposed resolution |
|---------|--------|--------|---------------------|
| <!-- blocker description --> | <!-- why it is blocked --> | <!-- what it prevents --> | <!-- how to unblock --> |

If no blockers: `None — all checks passed.`

---

## TODOs captured

List any work deferred to a future stage:

| Item | Deferred to stage | Notes |
|------|------------------|-------|
| <!-- TODO description --> | Stage <!-- N --> | <!-- why deferred --> |

---

## Next actions

Ordered list of what the next agent session must do first:

1. <!-- action 1 — specific and actionable -->
2. <!-- action 2 -->
3. <!-- action 3 -->

Files to read at session start:
- `pgsql_learning_repo_prompt_pack/CURRENT_STAGE.md`
- `pgsql_learning_repo_prompt_pack/STAGE_PROMPTS/stage-<!-- N+1 -->.md`
- `.learning-session/agent-handoff.md`

---

## Git status summary

```bash
# Run and paste output here
git -C /mnt/d/wsl/l-pgsql status
```

```
<!-- paste git status output -->
```

Files staged for commit:
```bash
git -C /mnt/d/wsl/l-pgsql diff --cached --name-only
```

```
<!-- paste output -->
```

Commit message used (or proposed):
```
<!-- feat/docs/chore: Stage N — brief description -->
```

---

## Permission request

> Agents must stop here and ask permission before starting the next stage.
> Do not begin Stage N+1 work without an explicit instruction.

```
Stage <!-- N --> is complete.

Status: <!-- completed with validation / partially completed / incomplete -->

Validation: <!-- N/M checks passed -->

Files created: <!-- N -->

Blockers: <!-- None / list blockers -->

Ready to proceed to Stage <!-- N+1 -->: <!-- Stage Title -->

Stage N+1 will: <!-- one-sentence description of what the next stage does -->

Awaiting permission to begin.
```

---

## Session memory update checklist

Before closing this session, confirm these files are updated:

- [ ] `.learning-session/current-stage.md` — updated to Stage <!-- N+1 -->
- [ ] `.learning-session/stage-history.md` — Stage <!-- N --> entry added
- [ ] `.learning-session/validation-log.md` — all checks recorded
- [ ] `.learning-session/generated-files.md` — all new files listed
- [ ] `.learning-session/next-actions.md` — next session's first steps
- [ ] `.learning-session/agent-handoff.md` — this report saved here
- [ ] `.learning-session/open-questions.md` — any unresolved questions captured
