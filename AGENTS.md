# AGENTS.md

## Repo purpose

Staged, first-principles PostgreSQL learning lab (30 stages, 0–29).
Teaches PostgreSQL as a database engine AND as an agent-safe state/memory/retrieval/audit substrate.
No application code. Content is Markdown, SQL, Bash, YAML, and JSON.

## Safe files to edit

- `docs/*.md` — cross-cutting audit and architecture docs (Phase 0–16 outputs)
- `arch.md`, `learning-roadmap.md` — stage labels only (keep "← current" accurate)
- `.gitignore` — add entries only; never remove
- `README.md`, `CONTRIBUTING.md`, `references.md`
- `memory.md`, `sessions.md` — session resumption files at repo root

## Files requiring human approval before editing

- `pgsql_learning_repo_prompt_pack/CURRENT_STAGE.md` — authoritative stage gate
- `pgsql_learning_repo_prompt_pack/MASTER_SPEC.md` — defines lesson structure
- `pgsql_learning_repo_prompt_pack/STAGES.md` — stage definitions
- `pgsql_learning_repo_prompt_pack/STAGE_PROMPTS/*.md` — per-stage prompts
- `pgsql_learning_repo_prompt_pack/.learning-session/` — resumable session state
- `scripts/` — validated shell and SQL scripts
- `tools/dashboards/docker-compose.yml` — live infrastructure
- Any file under `concepts/`, `practice/`, `examples/` — content created only at Stage 3+

## Build command

N/A — no build step. Infrastructure: `docker compose -f tools/dashboards/docker-compose.yml up -d`

## Test command

```bash
bash scripts/stage-00/validate-env.sh
bash scripts/stage-00/validate-session-files.sh
docker exec cfp_postgres psql -U cfp -d cfp -f scripts/stage-00/validate-extensions.sql
```

## Validation command

Same as test command. All three scripts must pass before marking any stage done.

## Coding style

- SQL: uppercase keywords, snake_case identifiers, explicit column lists in SELECT
- Bash: `set -e` at top, quote all variables, no silent failures
- Markdown: ATX headings (#), blank line after headings, fenced code blocks with language tag
- YAML: 2-space indent, no tabs

## Refactor rules

- Documentation and config only — no SQL, no Bash, no behavior changes
- Do not rename files used by agents: `AGENT_GUIDE.md`, `STAGES.md`, `CURRENT_STAGE.md`
- Do not start Stage 2+ content without explicit human permission
- Never add application code — this is a curriculum repo

## Security rules

- All credentials are local dev defaults (`cfp/cfp`, `admin/admin`) — never promote to production
- No API keys, tokens, or production secrets belong in this repo
- `tools/dashboards/pgadmin/pgpass` stays local; acceptable in git for this dev repo
- Grafana anonymous access is intentional for local dev only

## Known risks

- `pgsql_learning_repo_prompt_pack/CURRENT_STAGE.md` was stale (Stage 0 not-started) — fixed 2026-05-16
- Markdown lint and YAML lint not run locally — CI (`validate.yml`) will surface issues on next push
- `open-webui:main` Docker image uses a floating tag — reproducibility risk for future pulls

## Current TODOs

- Await human permission to start Stage 2 (Templates and Validation Scripts)
- Enable `pg_stat_statements`: run `bash scripts/dashboards/enable-pg-stat-statements.sh`

## Next recommended tasks

1. Human approves Stage 2 → run `pgsql_learning_repo_prompt_pack/STAGE_PROMPTS/stage-02-templates-and-validation-scripts.md`
2. After Stage 2: ask permission before Stage 3
3. Do not generate lesson content (concepts/, practice/, examples/) until Stage 3 is permitted
