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
