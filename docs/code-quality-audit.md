# Code Quality Audit

Generated: 2026-05-16  
Phase: 2  
Auditor: Claude Sonnet 4.6

Note: This repo contains no application code. "Code" here means Bash scripts, SQL scripts, YAML configs, and Markdown documentation.

---

| Area | Finding | Evidence | Risk | Suggested refactor | Priority |
|---|---|---|---|---|---|
| **CURRENT_STAGE.md stale** | Root control file showed wrong stage | `CURRENT_STAGE.md` vs `.learning-session/current-stage.md` | High: agents reading wrong file proceed on wrong stage | Fixed: updated to Stage 1 completed | P0 — Done |
| **repo-memory.md pre-init language** | Says "git not initialized"; describes pre-Stage-0 state | `.learning-session/repo-memory.md` line: "Git: not initialized — git init required" | Low: agent might think git is missing | Add note that this is a historical snapshot; do not repair actual text (it's a log) | P3 |
| **validate-env.sh `set -euo pipefail`** | Script exits on first error; if Docker is down, many checks are skipped | `validate-env.sh` lines 8 | Low: WARN sections already guard this with `docker inspect` checks | Acceptable — guards are in place | P3 |
| **.obsidian/ untracked** | Not in .gitignore; appears as untracked in git status | `git status` output | Low: contributors confused; Obsidian prefs pollute PRs | Fixed: added to .gitignore | P1 — Done |
| **No .github/** | No CI, no PR template, no issue templates | `ls .github/ → absent` | Medium: no automated validation on contributions | Create minimal .github/ (Phase 9) | P1 |
| **No AGENTS.md** | Agent bootstrap instructions in AGENT_GUIDE.md but no AGENTS.md | `ls AGENTS.md → absent` | Low: agents using AGENTS.md convention find nothing | Create AGENTS.md (Phase 13) | P2 |
| **docker-compose.yml: default credentials** | `admin/admin` for Grafana and pgAdmin; `cfp/cfp` for PostgreSQL | `tools/dashboards/docker-compose.yml` | Info: local dev only — acceptable; would be critical in production | Document explicitly in security-audit.md | P3 |
| **enable-pg-stat-statements.sh: no idempotency guard** | Calls `ALTER SYSTEM SET` without checking if already set | `scripts/dashboards/enable-pg-stat-statements.sh` | Low: running twice is harmless (ALTER SYSTEM is idempotent) | Acceptable as-is | P3 |
| **validate-extensions.sql: installs extensions in cfp DB** | Creates extensions in the main `cfp` database | `scripts/stage-00/validate-extensions.sql` | Low: local dev only; vector/pgcrypto etc are safe to install | Acceptable for learning environment | P3 |
| **Placeholder READMEs** | All content dirs have only `README.md` with "Placeholder — content generated in a future stage" | `concepts/`, `practice/`, `examples/`, `extensions/`, `ontology/`, `reflections/`, `design-principles/`, `diagrams/`, `tools/templates/` | Info: expected — Stages 3–25 will fill these | No action needed | P3 |
| **arch.md / learning-roadmap.md: "← current" label** | Both show Stage 1 as current; Stage 1 is complete | `arch.md` stage map, `learning-roadmap.md` | Low: confusing to next agent | Update both to remove "← current" label and note Stage 2 pending | P2 |
| **pgsql_learning_repo_prompt_pack.zip** | Binary archive committed to repo root | `ls *.zip` — two .zip files present | Info: .gitignore blocks *.zip, so these were committed before the rule; they remain | Verify if .zip files are tracked in git or only on disk | P2 |
| **No docs/ directory (before Phase 0)** | No cross-cutting documentation directory | `ls docs/ → absent` | Medium: hard to locate architecture/audit docs at scale | Created docs/ this phase | P1 — Done |
| **tools/dashboards/docker-compose.yml: `open-webui:main` tag** | Uses `:main` (floating) tag for Open WebUI image | `docker-compose.yml` line: `image: ghcr.io/open-webui/open-webui:main` | Low: breaks reproducibility; `:main` is mutable | Pin to a specific version tag when possible | P2 |

---

## Priority summary

| Priority | Count | Items |
|---|---|---|
| P0 (blocking) | 1 | CURRENT_STAGE.md — Fixed |
| P1 (important) | 3 | .gitignore (fixed), .github/ (Phase 9), docs/ (done) |
| P2 (useful) | 3 | AGENTS.md, arch.md label, open-webui tag |
| P3 (optional) | 7 | Minor; acceptable for local learning environment |

No circular imports, no dead code, no large files, no hardcoded secrets (beyond expected local dev defaults), no unsafe shell commands found.
