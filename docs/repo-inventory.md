# Repo Inventory

Generated: 2026-05-16  
Phase: 0 — Baseline inspection  
Agent: Claude Sonnet 4.6

---

## Repo purpose

A staged, first-principles PostgreSQL learning lab built in 30 stages (0–29).
Teaches PostgreSQL as a database engine AND as an agent-safe state/memory/retrieval/audit substrate.
Intended for developers learning PostgreSQL from beginner to advanced, with an AI/MCP safety angle.

**Remote:** https://github.com/rajaghv-dev/l-pgsql.git  
**Branch:** `main`

---

## Languages and frameworks detected

| Language / Tool | Usage |
|---|---|
| SQL (PostgreSQL dialect) | All database exercises and validation |
| Bash | Validation scripts (`scripts/`) |
| YAML | Dashboard Docker Compose, Grafana/Prometheus config |
| Markdown | All documentation, lessons, roadmaps |
| Python (venv only) | `.l-pgsql/` venv present — no Python source files in repo |
| Mermaid | Planned for `diagrams/` (not yet populated) |
| JSON | Grafana dashboard provisioning, pgAdmin `servers.json` |

No application code. This is a documentation/curriculum/infrastructure repo.

---

## Main entry points

| Entry point | Purpose |
|---|---|
| `README.md` | Quick start and overview |
| `AGENT_GUIDE.md` | Bootstrap sequence for coding agents |
| `memory.md` | Minimum-read env facts for new agent sessions |
| `sessions.md` | Session log and current stage status |
| `arch.md` | Full architecture, infra diagram, extension examples |
| `pgsql_learning_repo_prompt_pack/CURRENT_STAGE.md` | **[STALE — see finding F-01]** |
| `pgsql_learning_repo_prompt_pack/.learning-session/current-stage.md` | Authoritative current stage status |

---

## Build system

None. This repo has no build step.

| Tool | Present? | Notes |
|---|---|---|
| Makefile | No | — |
| pyproject.toml | No | Python venv exists but no source code |
| package.json | No | — |
| Cargo.toml | No | — |
| go.mod | No | — |
| Dockerfile | No (root) | Dashboard stack only (`tools/dashboards/docker-compose.yml`) |
| docker-compose.yml | Yes (in `tools/dashboards/`) | 8 dashboard services |

---

## Runtime dependencies

| Dependency | How used | Provided by |
|---|---|---|
| Docker | Runs PostgreSQL + all dashboards | Host machine |
| PostgreSQL 16.13 | Learning database | Container `cfp_postgres` (image: `pgvector/pgvector:pg16`) |
| Redis 7 | Side service | Container `cfp_redis` |
| Ollama | LLM for AI examples | Container `cfp_ollama` |
| pgAdmin 4 | Schema/EXPLAIN UI | Dashboard stack |
| Adminer | Quick SQL UI | Dashboard stack |
| Grafana | Metrics dashboards | Dashboard stack |
| Prometheus | Metrics collection | Dashboard stack |
| postgres_exporter | PG → Prometheus | Dashboard stack |
| redis_exporter | Redis → Prometheus | Dashboard stack |
| RedisInsight | Redis GUI | Dashboard stack |
| Open WebUI | Ollama chat UI | Dashboard stack |

---

## Test framework

| Type | Location | Notes |
|---|---|---|
| Environment validation (bash) | `scripts/stage-00/validate-env.sh` | Stage 0 self-test |
| Session file validation (bash) | `scripts/stage-00/validate-session-files.sh` | Stage 0 self-test |
| SQL extension validation | `scripts/stage-00/validate-extensions.sql` | Stage 0 self-test |
| Per-stage SQL tests | Planned in `tools/templates/` | Stage 2+ (not yet created) |

No unit test framework (no application code). Validation is bash + SQL.

---

## CI/CD workflows

**None.** No `.github/` directory exists. No GitHub Actions, no Dependabot, no issue templates, no PR template.

This is a known gap — see Findings.

---

## Documentation files

### Root-level docs (living documents)

| File | Purpose | Lines |
|---|---|---|
| `README.md` | Overview and quick start | ~55 |
| `AGENT_GUIDE.md` | Agent bootstrap sequence | ~65 |
| `CONTRIBUTING.md` | Contribution rules | ~45 |
| `arch.md` | Full architecture (authoritative) | ~300 |
| `memory.md` | Env facts for agent sessions | ~65 |
| `sessions.md` | Session log and stage status | ~70 |
| `learning-roadmap.md` | Stage map overview | ~45 |
| `beginner-roadmap.md` | Beginner learning path | short |
| `intermediate-roadmap.md` | Intermediate learning path | short |
| `advanced-roadmap.md` | Advanced learning path | short |
| `references.md` | Curated free references | 73 |
| `extension-map.md` | 48 extensions by category | 89 |
| `capability-map.md` | Capabilities by problem | 91 |

### Prompt pack docs (orchestration layer)

| File | Purpose |
|---|---|
| `pgsql_learning_repo_prompt_pack/MASTER_SPEC.md` | Full lesson/practice template spec |
| `pgsql_learning_repo_prompt_pack/STAGES.md` | 30-stage roadmap definitions |
| `pgsql_learning_repo_prompt_pack/CURRENT_STAGE.md` | **STALE** — see F-01 |
| `pgsql_learning_repo_prompt_pack/DONE_CRITERIA.md` | Completion criteria |
| `pgsql_learning_repo_prompt_pack/AGENT_BOOTSTRAP.md` | Agent-specific bootstrap |
| `pgsql_learning_repo_prompt_pack/CHANGELOG.md` | Change log |
| `pgsql_learning_repo_prompt_pack/TODO.md` | Open TODOs |
| `pgsql_learning_repo_prompt_pack/prompts.md` | Reusable prompts |
| `pgsql_learning_repo_prompt_pack/STAGE_PROMPTS/stage-00..29.md` | 30 stage prompt files |

### Session memory files

All under `pgsql_learning_repo_prompt_pack/.learning-session/`:
`current-stage.md`, `stage-history.md`, `repo-memory.md`, `validation-log.md`, `generated-files.md`, `next-actions.md`, `agent-handoff.md`, `open-questions.md`, `decisions.md`, `prompts-used.md`

### Docs directory

`docs/` **did not exist before Phase 0.** This file (`docs/repo-inventory.md`) is the first file created there.

---

## Public APIs / CLIs / services

None — this is a learning content repo. No public API surface. The "interface" is:
- Lesson files (Markdown)
- SQL scripts (run via `docker exec`)
- Bash validation scripts

---

## Configuration files

| File | Purpose |
|---|---|
| `tools/dashboards/docker-compose.yml` | Dashboard stack (8 services) |
| `tools/dashboards/grafana/provisioning/datasources/postgres.yml` | Grafana → PG datasource |
| `tools/dashboards/grafana/provisioning/datasources/prometheus.yml` | Grafana → Prometheus datasource |
| `tools/dashboards/grafana/provisioning/dashboards/provider.yml` | Grafana dashboard loader |
| `tools/dashboards/grafana/dashboards/pg-learning-overview.json` | Pre-built Grafana dashboard |
| `tools/dashboards/prometheus/prometheus.yml` | Prometheus scrape config |
| `tools/dashboards/pgadmin/servers.json` | Pre-wired pgAdmin connection |
| `tools/dashboards/pgadmin/pgpass` | pgAdmin password file |
| `.gitignore` | Excludes: `*.zip`, `*.tar.gz`, `.l-pgsql/`, `venv/`, `.vscode/`, OS files |
| `.claude/settings.local.json` | Claude Code local settings |

---

## Examples and demos

| Location | Status | Notes |
|---|---|---|
| `examples/beginner/` | Placeholder only (`README.md`) | Stage 15 will populate |
| `examples/intermediate/` | Placeholder only | Stage 16 will populate |
| `examples/advanced/` | Placeholder only | Stage 17 will populate |
| `arch.md` (inline) | 5 extension code examples | pgvector, pg_trgm, pgcrypto, ltree, RLS — runnable |

---

## Deployment artifacts

| Artifact | Purpose |
|---|---|
| `tools/dashboards/docker-compose.yml` | Deploy dashboard stack |
| `scripts/dashboards/enable-pg-stat-statements.sh` | One-time pg_stat_statements setup |

---

## Observability / logging / metrics / tracing

| Component | What | Port |
|---|---|---|
| Grafana `pg-learning-overview` | PG connections, cache hit, extensions, table stats, queries, index usage, locks | 3000 |
| Prometheus | Raw metrics scraping PG + Redis exporters | 9090 |
| postgres_exporter | PG → Prometheus metrics | 9187 |
| redis_exporter | Redis → Prometheus metrics | 9121 |
| pgAdmin 4 | EXPLAIN, schema explorer | 5050 |
| Adminer | Quick SQL | 8082 |
| `pg_stat_statements` | Query stats | Needs one-time setup script |
| `pg_buffercache` | Buffer cache inspection | Extension available, not yet in lessons |

---

## Security-sensitive files

| File | Risk | Status |
|---|---|---|
| `tools/dashboards/pgadmin/pgpass` | Contains PG password (`cfp`) | Low risk (local dev only, not in .gitignore) |
| `tools/dashboards/docker-compose.yml` | Contains plaintext creds (cfp/cfp, admin/admin) | Low risk (local dev defaults, well-understood) |
| `.claude/settings.local.json` | Claude Code local permissions | Not sensitive |
| `.l-pgsql/` (venv) | In .gitignore — never committed | Safe |

No secrets, API keys, or production credentials detected.

---

## Known gaps

| Gap | Severity | Notes |
|---|---|---|
| **F-01**: `CURRENT_STAGE.md` in prompt pack root is stale | High | Says "Stage 0 / not-started" — reality is Stage 1 completed |
| No `.github/` directory | Medium | No CI, no issue templates, no PR template, no Dependabot |
| `docs/` directory absent | Medium | All cross-cutting docs live at root; hard to navigate at scale |
| Content directories are all placeholders | Low | Correct — Stages 3–29 have not run yet |
| `AGENTS.md` not present at root | Low | `AGENT_GUIDE.md` exists but `AGENTS.md` (new format) does not |
| Python venv `.l-pgsql/` on disk | Info | In .gitignore; no Python source in repo — venv is unused |
| `.obsidian/` untracked | Info | Intentionally not tracked (in .gitignore omitted — but currently untracked rather than ignored) |

---

## Initial git state

| Item | Value |
|---|---|
| Branch | `main` |
| Remote | `origin` → `https://github.com/rajaghv-dev/l-pgsql.git` |
| Uncommitted changes | None |
| Untracked files | `.obsidian/` only |
| Recent commits | `bfc18e9`, `a8b186f`, `4b30162`, `1447bac`, `641a5bc` |
| Stage 0 commits | `641a5bc` (stage-00), `1447bac` (stage-01) |
| Stage 1 commits | `4b30162` (foundation skeleton) |
| Post-stage commits | `a8b186f` (dashboard stack + arch.md), `bfc18e9` (memory.md + sessions.md) |
