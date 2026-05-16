# Interfaces

Generated: 2026-05-16  
Phase: 6

This repo has no public API, CLI, or service. The "interfaces" are the human- and agent-facing entry points.

---

## Interface: Agent bootstrap sequence

### Purpose
How a coding agent or human resumes work on this repo.

### Input
Reading these files in order:
1. `AGENT_GUIDE.md`
2. `pgsql_learning_repo_prompt_pack/AGENT_BOOTSTRAP.md`
3. `pgsql_learning_repo_prompt_pack/CURRENT_STAGE.md`
4. `pgsql_learning_repo_prompt_pack/STAGES.md`
5. `pgsql_learning_repo_prompt_pack/DONE_CRITERIA.md`
6. `pgsql_learning_repo_prompt_pack/.learning-session/agent-handoff.md`
7. `pgsql_learning_repo_prompt_pack/.learning-session/validation-log.md`
8. Matching `STAGE_PROMPTS/stage-NN-*.md` file

### Output
Agent knows which stage to work on and what validation is required.

### Error behavior
If `CURRENT_STAGE.md` conflicts with `.learning-session/current-stage.md`, trust `.learning-session/current-stage.md` (the session memory is more granular and up-to-date).

### Security considerations
None — read-only file access.

### Tests
`scripts/stage-00/validate-session-files.sh` checks all session files exist and are non-empty.

### Documentation status
Documented in `AGENT_GUIDE.md`, `memory.md`, `AGENTS.md`.

---

## Interface: PostgreSQL connection

### Purpose
Execute SQL for all lessons, practice, and validation.

### Input
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "<SQL statement>"
# or for a file:
docker exec -i cfp_postgres psql -U cfp -d cfp < <sql-file>
```

### Output
SQL query result or error message.

### Side effects
Modifies database state (extensions, tables, data) during lessons.

### Error behavior
Exit code non-zero on SQL error. `psql` prints error to stderr.

### Security considerations
Credentials `cfp/cfp` are local dev only. Container is not exposed beyond localhost port 5432.

### Tests
`scripts/stage-00/validate-env.sh` — validates connection, version, superuser status.
`scripts/stage-00/validate-extensions.sql` — validates extensions can be installed.

### Documentation status
Documented in `memory.md`, `AGENT_GUIDE.md`, `arch.md`.

---

## Interface: Dashboard stack

### Purpose
Observability and management UIs for learning PostgreSQL internals.

### Input
```bash
docker compose -f tools/dashboards/docker-compose.yml up -d
```

### Output
8 services start on the `cfp_default` Docker network.

### Access points

| Service | URL | Credentials |
|---|---|---|
| pgAdmin 4 | http://localhost:5050 | admin / admin |
| Adminer | http://localhost:8082 | server: cfp_postgres, user: cfp, pass: cfp |
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | — |
| RedisInsight | http://localhost:5540 | — (add cfp_redis manually) |
| Open WebUI | http://localhost:8080 | — |

### Error behavior
If `cfp_default` Docker network doesn't exist, services fail to start. The network is created by the main `cfp_postgres` container.

### Security considerations
Default credentials. Anonymous Grafana access is enabled. Local dev only.

### Tests
No automated health checks. Manual verification: `docker compose ps`.

### Documentation status
Documented in `tools/dashboards/README.md`, `memory.md`, `arch.md`.

---

## Interface: Validation scripts

### Purpose
Verify environment and stage completion before proceeding.

### Input
```bash
bash scripts/stage-00/validate-env.sh        # environment check
bash scripts/stage-00/validate-session-files.sh  # session file check
docker exec -i cfp_postgres psql -U cfp -d cfp < scripts/stage-00/validate-extensions.sql
```

### Output
`[PASS]`, `[WARN]`, or `[FAIL]` lines. Exit code 0 (pass/warn) or 1 (fail).

### Error behavior
Script exits with code 1 and prints FAIL count if any check fails.

### Security considerations
No secrets. Reads Docker container state and file system.

### Tests
Self-validating — scripts are the test.

### Documentation status
Documented in `AGENT_GUIDE.md`, `memory.md`, `sessions.md`.

---

## Interface: Stage prompt files

### Purpose
The work order for each stage. Tells the agent exactly what to create, validate, and record.

### Input
Read `pgsql_learning_repo_prompt_pack/STAGE_PROMPTS/stage-NN-<name>.md` for the current stage.

### Output
Agent creates the specified files and runs the specified validation.

### Error behavior
If a stage prompt references tools or containers that are unavailable, mark as "blocked with reason" in `validation-log.md`.

### Security considerations
None — read-only prompt files.

### Tests
`DONE_CRITERIA.md` lists the checks for every stage.

### Documentation status
Documented in `AGENT_GUIDE.md`, `STAGES.md`.

---

## Interface: Lesson and practice files (planned)

### Purpose
The actual learning content — lessons, exercises, solutions, reflection prompts.

### Status
Not yet created. Stages 3–25 will produce content in:
- `concepts/beginner/`, `concepts/intermediate/`, `concepts/advanced/`
- `practice/beginner/`, `practice/intermediate/`, `practice/advanced/`
- `examples/beginner/`, `examples/intermediate/`, `examples/advanced/`
- `extensions/`, `ontology/`, `diagrams/`, `design-principles/`, `reflections/`

### Template
`pgsql_learning_repo_prompt_pack/MASTER_SPEC.md` defines the required sections for every lesson.

### Documentation status
Documented in `MASTER_SPEC.md`, `CONTRIBUTING.md`, roadmap files.
