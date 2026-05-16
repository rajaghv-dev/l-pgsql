# Testing

Generated: 2026-05-16  
Phase: 8

---

## Test types

| Type | Description | Location |
|---|---|---|
| Environment validation | Checks Docker, containers, extensions, session files | `scripts/stage-00/validate-env.sh` |
| Session file validation | Checks all .learning-session/ files exist and are non-empty | `scripts/stage-00/validate-session-files.sh` |
| SQL extension validation | Installs and queries required extensions | `scripts/stage-00/validate-extensions.sql` |
| Stage completion checks | Per-stage pass/fail/blocked results | `DONE_CRITERIA.md` + `validation-log.md` |
| Per-lesson SQL tests | Planned — will be in each practice folder | `practice/<level>/<topic>/setup.sql`, `00-setup-validation.md` |

---

## How to run all tests

```bash
# Environment and session checks
bash scripts/stage-00/validate-env.sh
bash scripts/stage-00/validate-session-files.sh

# Extension SQL validation
docker exec -i cfp_postgres psql -U cfp -d cfp < scripts/stage-00/validate-extensions.sql
```

Expected results (as of Stage 1 complete):
- `validate-env.sh`: 45 PASS, 5 WARN, 0 FAIL
- `validate-session-files.sh`: 26 PASS, 0 FAIL
- `validate-extensions.sql`: all required extensions available

---

## How to run unit tests

No unit test framework. This repo has no application code.

---

## How to run integration tests

SQL-level integration tests: run `validate-extensions.sql` against the live container.

Stage-level integration: run all three scripts above after completing a stage.

---

## How to run examples

No runnable examples yet (Stages 15–17 will create them). Current examples exist only as inline SQL in `arch.md`.

Inline examples from `arch.md` can be run manually:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
CREATE EXTENSION IF NOT EXISTS vector;
SELECT '[1,2,3]'::vector <-> '[4,5,6]'::vector AS l2_distance;
"
```

---

## Test data

No test data fixtures exist yet. Practice sessions (Stages 3+) will each include `setup.sql` with seed data. All data in regulated-domain examples must be synthetic.

---

## Known missing tests

| Gap | Severity | Planned in |
|---|---|---|
| Per-stage SQL validation scripts | Medium | Stage 2 (templates + validation scripts) |
| Practice session setup validation | Medium | Stage 3+ |
| Markdown link-checking CI | Low | Phase 9 (this refactor) |
| YAML lint CI | Low | Phase 9 (this refactor) |
| docker-compose syntax validation | Low | Phase 9 (this refactor) |

---

## CI validation

See `docs/github-readiness.md`. A GitHub Actions workflow will be added to lint YAML and check Markdown on every push.
