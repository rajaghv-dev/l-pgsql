# CHANGELOG

## Unreleased

- Added staged prompt pack for PostgreSQL learning repository generation.

## Full build Stages 3–29 — 2026-05-16

- Stages 3–29 content generated via parallel agents
- Created: 21 beginner lessons, 25 intermediate lessons, 29 advanced lessons
- Created: 10 beginner practice sessions, 16 intermediate practice sessions
- Created: 4 beginner examples, 13 intermediate examples, 7 advanced examples
- Created: 8 extension deep-dives + 6 placeholder files
- Created: 16 ontology concept map files
- Created: 11 Mermaid diagrams
- Created: 11 design principle files
- Created: 12 reflection question bank files
- Created: curated references.md
- SQL validation: blocked — Docker not accessible in generation session; re-validate against cfp_postgres when Docker Desktop WSL2 integration is enabled
- PostGIS content: reference-only (not available in cfp_postgres image)
- TimescaleDB content: reference-only (not available in cfp_postgres image)

## Stage 2 — 2026-05-16

- Created 11 lesson and practice templates in `tools/templates/`
- Created 7 validation scripts in `scripts/`: check-required-files.sh, validate-practice-structure.sh, validate-stage.sh, validate-sql-files.sh, validate-extension-availability.sql, run-example.sh, README.md
- Validation: 17/17 PASS (file check), SQL blocked (Docker not accessible)

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
