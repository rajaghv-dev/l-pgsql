# Contributing

This repo is generated stage by stage. Contributions must follow the staged workflow.

## Rules

- Work one stage at a time.
- Read `AGENT_GUIDE.md` before making changes.
- Validate before marking a stage complete.
- Use `completed with validation`, `partially completed; validation blocked because...`, or `incomplete; requires repair`.
- Never generate future stages unless approved.
- Use synthetic data for all regulated-domain examples.
- Never add professional advice logic (legal, medical, financial, pharma).
- Use references instead of long content dumps.
- SQL must be tested against the real container or marked blocked with a reason.

## Adding a lesson

Follow the lesson template in `pgsql_learning_repo_prompt_pack/MASTER_SPEC.md`.

Required sections:
- One-line intuition
- Why this exists
- First-principles explanation
- Micro-concepts with micro-practice
- MCP and agent perspective
- Ontology perspective
- References

## Adding a practice session

Each `practice/<level>/<topic>/` folder must contain:
- `README.md`
- `setup.sql`
- `00-setup-validation.md`
- `exercises.md`
- `solutions.md`
- `reflection.md`
- `ontology-notes.md`
- `troubleshooting.md`
- `references.md`

## Adding a reference

Add to `references.md`. Include: title, URL, type, level, estimated time, why useful.

Prefer official docs, free books, university notes, short videos. No paid courses or SEO blogs.

## Repository structure (as of Stage 2)

The repo now has the following content areas being filled in stages:

| Directory | Content | Stage |
|-----------|---------|-------|
| `concepts/beginner/` | 21 beginner lessons (Stages 3–6) | 3–6 |
| `concepts/intermediate/` | 25 intermediate lessons (Stages 7–11, 26) | 7–11, 26 |
| `concepts/advanced/` | 29 advanced lessons (Stages 18–20, 28) | 18–20, 28 |
| `practice/beginner/` | 10 practice sessions | 3–6 |
| `practice/intermediate/` | 16 practice sessions | 7–11, 26 |
| `examples/beginner/` | 4 domain examples | 15 |
| `examples/intermediate/` | 13 domain examples | 16, 27 |
| `examples/advanced/` | 7 domain examples | 17 |
| `extensions/` | 8 extension deep-dives + placeholders | 12 |
| `ontology/` | 16 ontology concept maps | 13–14, 26, 28 |
| `diagrams/` | 11 Mermaid diagrams | 21 |
| `design-principles/` | 11 principle files | 22, 28 |
| `reflections/` | 12 question bank files | 23, 29 |
| `tools/templates/` | 11 content templates | 2 |
| `scripts/` | 7 validation scripts | 0, 2 |
| `docs/` | 14 cross-cutting docs | refactor |

## Using the validation scripts

```bash
# Check all required files for a stage
bash scripts/check-required-files.sh --stage N

# Validate a practice folder structure
bash scripts/validate-practice-structure.sh practice/beginner/01-basic-sql/

# Validate all SQL files are non-empty
bash scripts/validate-sql-files.sh

# Full stage validation (runs file check + reports blockers)
bash scripts/validate-stage.sh --stage N
```
