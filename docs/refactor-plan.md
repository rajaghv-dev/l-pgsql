# Refactor Plan

Generated: 2026-05-16  
Phase: 3

---

## Goals

1. Fix one confirmed stale control file (`CURRENT_STAGE.md`).
2. Add missing `.gitignore` entry for `.obsidian/`.
3. Align two doc labels that say "Stage 1 ← current" after Stage 1 completed.
4. Create the `docs/` directory with cross-cutting audit and architecture docs.
5. Create `AGENTS.md` for agent bootstrap convention.
6. Create minimal `.github/` CI workflows appropriate for a Markdown/SQL learning repo.
7. Document all findings in audit docs.
8. Prepare GitHub update summary.

---

## Non-goals

- Do not start Stage 2 or any stage content.
- Do not rename existing files used by agents (AGENT_GUIDE.md, STAGES.md, etc.).
- Do not change the staged learning workflow.
- Do not add application code.
- Do not change Docker infrastructure.
- Do not change public-facing lesson structure.

---

## Current problems

| ID | Problem | Source |
|---|---|---|
| F-01 | `CURRENT_STAGE.md` showed Stage 0 not-started | Doc-code consistency audit |
| F-02 | `.obsidian/` untracked and not in .gitignore | Code quality audit |
| F-03 | `docs/` absent | Code quality audit |
| F-04 | `AGENTS.md` absent | Code quality audit |
| F-05 | No `.github/` directory | Code quality audit |
| F-06 | "← current" labels stale in arch.md and learning-roadmap.md | Doc-code consistency audit |
| F-07 | Open question about learning schema/DB not recorded as decision | open-questions.md |

---

## Evidence summary

- All findings derived from direct file inspection (Phase 0) and consistency audit (Phase 1).
- No graph/code intelligence tools available (documented in tooling-gaps.md).
- No application code exists — risk of behavioral regression is zero.

---

## Refactor strategy

All changes are documentation and configuration only. No SQL, no Bash, no behavior changes.

---

## Files to change

| File | Change |
|---|---|
| `pgsql_learning_repo_prompt_pack/CURRENT_STAGE.md` | Update to Stage 1 completed ← Done |
| `.gitignore` | Add `.obsidian/` ← Done |
| `arch.md` | Remove "← current" from Stage 1 label; note Stage 2 pending |
| `learning-roadmap.md` | Same label fix |
| `docs/repo-inventory.md` | New — Phase 0 ← Done |
| `docs/doc-code-consistency-audit.md` | New — Phase 1 ← Done |
| `docs/code-quality-audit.md` | New — Phase 2 ← Done |
| `docs/refactor-plan.md` | New — this file |
| `docs/architecture.md` | New — Phase 5 |
| `docs/interfaces.md` | New — Phase 6 |
| `docs/setup-validation.md` | New — Phase 7 |
| `docs/testing.md` | New — Phase 8 |
| `docs/github-readiness.md` | New — Phase 9 |
| `docs/security-audit.md` | New — Phase 10 |
| `docs/examples.md` | New — Phase 11 |
| `docs/observability.md` | New — Phase 12 |
| `docs/tooling-gaps.md` | New — Phase 28 |
| `docs/agent-handoff.md` | New — Phase 13 |
| `docs/github-update-summary.md` | New — Phase 16 |
| `AGENTS.md` | New — Phase 13 |
| `.github/workflows/validate.yml` | New — Phase 9 |
| `.github/PULL_REQUEST_TEMPLATE.md` | New — Phase 9 |
| `reports/final-validation-report.md` | New — Phase 15 |

---

## Files not to touch

- `pgsql_learning_repo_prompt_pack/STAGES.md` — authoritative, no changes needed
- `pgsql_learning_repo_prompt_pack/MASTER_SPEC.md` — constitution, no changes needed
- `pgsql_learning_repo_prompt_pack/DONE_CRITERIA.md` — no changes needed
- `pgsql_learning_repo_prompt_pack/.learning-session/*` — historical logs, do not alter
- `scripts/stage-00/*` — working validation scripts, no changes needed
- `tools/dashboards/*` — working infrastructure, no changes needed
- `references.md`, `extension-map.md`, `capability-map.md` — content is correct

---

## Backward compatibility concerns

None — all changes are additive (new files) or documentation-only corrections (label updates, stale file fix). No scripts or SQL are modified.

---

## Test strategy

- Re-run `bash scripts/stage-00/validate-env.sh` after changes to confirm still passes.
- Manual review of changed files before commit.
- No unit tests needed (no application code).

---

## Rollback plan

All changes tracked in git. `git diff` shows exactly what changed. Rolling back = `git restore <file>`.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| CURRENT_STAGE.md fix confuses an agent that cached the old value | File is now accurate; agent re-read will get correct state |
| New docs/ create navigation confusion | docs/ is additive; root files remain unchanged |
| .github/ CI failing due to wrong commands | Workflows only lint YAML and check Markdown — no SQL or Docker needed |

---

## Phase plan

### Phase 1 — Documentation alignment (Labels)
Fix stale labels in `arch.md` and `learning-roadmap.md`.

### Phase 2 — New docs/
Create all audit, architecture, interface, setup, testing, security, examples, observability docs.

### Phase 3 — Agent files
Create `AGENTS.md` and `docs/agent-handoff.md`.

### Phase 4 — CI/GitHub
Create `.github/workflows/validate.yml` and PR template.

### Phase 5 — Final validation and GitHub summary
Create `reports/final-validation-report.md` and `docs/github-update-summary.md`.
