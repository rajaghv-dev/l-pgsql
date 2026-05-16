# CHANGELOG

## Unreleased

- Added staged prompt pack for PostgreSQL learning repository generation.

## Repo refactor — 2026-05-16 (Session 2, not a learning stage)

- Fixed stale `CURRENT_STAGE.md` (was "Stage 0 not-started"; now correctly "Stage 1 completed with validation").
- Added `docs/` directory with 14 cross-cutting audit and reference documents.
- Added `AGENTS.md` agent bootstrap at repo root.
- Added `.github/workflows/validate.yml` (YAML + Markdown lint CI).
- Added `.github/PULL_REQUEST_TEMPLATE.md`.
- Fixed `.gitignore`: added `.obsidian/`.
- Updated stage map labels in `arch.md` and `learning-roadmap.md`.
- Fixed `scripts/stage-00/validate-session-files.sh`: removed hardcoded `Stage: 0` check.

## Stage 1 — 2026-05-03

- Created foundation skeleton: README.md, learning-roadmap.md, beginner/intermediate/advanced roadmaps, AGENT_GUIDE.md, CONTRIBUTING.md, references.md, extension-map.md, capability-map.md.
- Created all required directories: concepts/, practice/, examples/, diagrams/, ontology/, extensions/, design-principles/, reflections/, tools/templates/.
- Validation: 25/25 PASS (10 files, 15 directories). No SQL in this stage.

## Stage 0 — 2026-05-03

- Completed audit, safety, and session setup.
- Recorded environment: Docker 29.4.1, PostgreSQL 16.13 (cfp_postgres container, pgvector image), 48 extensions available including vector/pgvector.
- Recorded blockers: git not initialized, psql not on host PATH.
- Updated all `.learning-session/` files.
