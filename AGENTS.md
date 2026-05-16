# AGENTS.md

## Repo purpose

Staged, first-principles PostgreSQL learning lab (30 stages, 0–29) — COMPLETE.
Teaches PostgreSQL as a database engine AND as an agent-safe state/memory/retrieval/audit substrate.
No application code. Content: Markdown lessons, SQL exercises, Bash scripts, YAML configs, Mermaid diagrams.

## Current state

All 30 stages have been generated. SQL validation is deferred (Docker not accessible during generation).
Next task: validate SQL against cfp_postgres and fix any broken examples.

## Safe files to edit

- docs/*.md — cross-cutting docs
- concepts/*/[any lesson].md — lesson files (follow MASTER_SPEC format)
- practice/*/[any folder]/*.sql — SQL exercises (validate after editing)
- examples/*/*.md — domain example files
- extensions/*.md — extension deep-dives
- ontology/*.md — ontology maps
- diagrams/*.md — Mermaid diagram files
- design-principles/*.md — design principle files
- reflections/*.md — question bank files
- arch.md, learning-roadmap.md — architecture and navigation docs
- .gitignore, README.md, CONTRIBUTING.md, PROGRESS.md, memory.md, sessions.md

## Files requiring human approval before editing

- pgsql_learning_repo_prompt_pack/CURRENT_STAGE.md
- pgsql_learning_repo_prompt_pack/MASTER_SPEC.md
- pgsql_learning_repo_prompt_pack/STAGES.md
- pgsql_learning_repo_prompt_pack/STAGE_PROMPTS/*.md
- pgsql_learning_repo_prompt_pack/.learning-session/ (historical logs)
- scripts/stage-00/*.sh and *.sql (validated scripts)
- tools/dashboards/docker-compose.yml (live infrastructure)

## Build command

N/A — no build step.
Infrastructure: `docker compose -f tools/dashboards/docker-compose.yml up -d`

## Test command

```bash
# Non-Docker (always works):
bash scripts/stage-00/validate-session-files.sh
bash scripts/check-required-files.sh --stage N
bash scripts/validate-sql-files.sh

# Requires Docker:
bash scripts/stage-00/validate-env.sh
bash scripts/validate-stage.sh --stage N
bash scripts/validate-all-stages.sh
```

## Validation command (Docker required)

```bash
docker exec cfp_postgres psql -U cfp -d cfp -f practice/beginner/01-basic-sql/setup.sql
```

## Coding style

- SQL: uppercase keywords, snake_case identifiers
- Bash: set -euo pipefail, quote all variables, pass()/fail()/warn() pattern
- Markdown: ATX headings, blank line after headings, fenced code blocks with language tag
- YAML: 2-space indent, no tabs
- Mermaid: use flowchart TD or sequenceDiagram for diagrams

## Refactor rules

- Follow MASTER_SPEC.md for lesson structure
- Use templates in tools/templates/ when adding new lessons or practices
- Do not rename files without updating all cross-references
- SQL must be PostgreSQL 16 compatible

## Security rules

- All credentials are local dev defaults (cfp/cfp, admin/admin) — never use in production
- Regulated domain examples use synthetic data only — no real PII
- No professional advice logic (legal, medical, financial, pharma)
- No real API keys or production secrets in any file

## Known risks and blockers

- SQL validation blocked — Docker not accessible in generation session
  Fix: enable Docker Desktop → WSL2 Integration → enable for this distro
- PostGIS not available in cfp_postgres image — PostGIS content is reference-only
- TimescaleDB not available — content is reference-only
- pg_stat_statements needs setup: `bash scripts/dashboards/enable-pg-stat-statements.sh`

## Current TODOs

1. Enable Docker WSL2 integration
2. Run SQL validation for all stages (bash scripts/validate-all-stages.sh)
3. Fix any broken SQL in practice sessions
4. Enable pg_stat_statements
5. Commit all generated content

## Next recommended tasks

1. Validate SQL: enable Docker → run `bash scripts/validate-all-stages.sh`
2. Commit: `git add . && git commit -m "feat: complete 30-stage PostgreSQL learning repo build"`
3. Push: `git push origin main`
4. Optional: Pin open-webui:main Docker image to a versioned tag
5. Optional: Pull Ollama model: `docker exec cfp_ollama ollama pull llama3.2:3b`
