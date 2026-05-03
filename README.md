# PostgreSQL Learning Repository

A practical, first-principles PostgreSQL learning lab built in stages.

## What this is

A structured learning repo covering PostgreSQL from beginner to advanced, including:

- SQL and schema design
- Indexing, query planning, transactions, MVCC
- JSONB, full-text search, fuzzy search, vector search
- Extensions (pgvector, pg_trgm, pgcrypto, ltree, and more)
- AI-agent memory, Model Context Protocol (MCP) perspectives
- Multi-tenant SaaS, observability, compliance, and audit

## How it is built

This repo is generated stage by stage. Each stage is validated before the next begins.

See `STAGES.md` in `pgsql_learning_repo_prompt_pack/` for the full roadmap.

## Directory structure

```
concepts/         — short lessons (beginner / intermediate / advanced)
practice/         — micro-practice sessions
examples/         — runnable domain examples
extensions/       — one file per extension
ontology/         — concept maps and ontology notes
diagrams/         — Mermaid and ASCII diagrams
design-principles/ — schema and system design principles
reflections/      — question banks and reflection prompts
scripts/          — validation and utility scripts
tools/            — templates and generators
references.md     — curated reference list
extension-map.md  — extension overview
capability-map.md — capability overview
learning-roadmap.md
```

## Environment

- PostgreSQL 16.13 via Docker container `cfp_postgres` (image: `pgvector/pgvector:pg16`)
- Connect: `docker exec cfp_postgres psql -U cfp -d cfp`
- psql is not on host PATH — all SQL runs inside the container

## Staged workflow

Stages are defined in `pgsql_learning_repo_prompt_pack/STAGES.md`.

Work one stage at a time. After each stage:
1. Validate required files and SQL.
2. Update `.learning-session/`.
3. Record pass/fail/blocked.
4. Stop and ask permission before the next stage.

## Resuming with a coding agent

See `AGENT_GUIDE.md`.
