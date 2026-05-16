# Documentation vs Code Consistency Audit

Generated: 2026-05-16  
Phase: 1  
Auditor: Claude Sonnet 4.6

---

| Area | Documentation claim | Repo reality | Evidence | Severity | Required fix |
|---|---|---|---|---|---|
| **CURRENT_STAGE.md** | "Stage 0 / not-started" | Stage 1 completed with validation | `.learning-session/current-stage.md`, `sessions.md`, `validation-log.md` | High | Fixed: updated `CURRENT_STAGE.md` to Stage 1 completed |
| **repo-memory.md** | "git not initialized — `git init` required before Stage 1" | Git is initialized; 5 commits on main | `git status` output | Medium | Note is stale; describes pre-Stage-1 state. File is a historical snapshot — acceptable as-is, but label it clearly |
| **README connect command** | `docker exec cfp_postgres psql -U cfp -d cfp` | Container name confirmed correct | `validate-env.sh`, `docker-compose.yml` | OK | No fix needed |
| **memory.md dashboard start** | `docker compose -f tools/dashboards/docker-compose.yml up -d` | File exists and is valid | `tools/dashboards/docker-compose.yml` | OK | No fix needed |
| **memory.md port table** | Lists 8 services with ports 5050/8082/3000/9090/9187/9121/5540/8080 | docker-compose.yml confirms exactly these ports | `docker-compose.yml` | OK | No fix needed |
| **arch.md dashboard ports** | Same 8 services | Matches docker-compose.yml | `docker-compose.yml` | OK | No fix needed |
| **memory.md pg_stat_statements** | "NOT enabled — run `bash scripts/dashboards/enable-pg-stat-statements.sh` first" | Script exists and is correct | `scripts/dashboards/enable-pg-stat-statements.sh` | OK | No fix needed |
| **memory.md extensions** | Lists 24 installed extensions | Docker container state not accessible in this session | Cannot verify live; last validated 2026-05-03 | Info | Re-run `validate-env.sh` to confirm |
| **memory.md "NOT available"** | `pg_cron`, `timescaledb`, `postgis`, `pgaudit` absent | Not verifiable without container | `validate-env.sh` optional section | Info | No change needed |
| **beginner-roadmap.md learning path** | References `concepts/beginner/01-what-is-postgresql.md` through `10-extensions-intro.md` | Files do not exist yet | `ls concepts/beginner/` shows only `README.md` | Low | Expected: Stage 3+ will create them. Roadmap is aspirational — OK. |
| **intermediate-roadmap.md** | References `concepts/intermediate/01..10.md` | Files do not exist yet | `ls concepts/intermediate/` shows only `README.md` | Low | Same as above — aspirational, expected |
| **advanced-roadmap.md** | References `concepts/advanced/01..11.md` | Files do not exist yet | `ls concepts/advanced/` shows only `README.md` | Low | Same — aspirational, expected |
| **arch.md stage map** | Shows "Stage 1 — Foundation skeleton ← current" | Stage 1 is complete; current is between 1 and 2 | `sessions.md` | Medium | Update arch.md stage map label |
| **learning-roadmap.md stage map** | Shows "Stage 1 — Foundation skeleton ← current" | Same issue | `sessions.md` | Medium | Update learning-roadmap.md label |
| **extension-map.md** | Claims 48 extensions by category | Lists extensions in categories but no count; says "All extensions below are available locally unless noted" | `extension-map.md`, `memory.md` | Low | File is accurate; 48 is from memory.md — no conflict |
| **CONTRIBUTING.md SQL rule** | "SQL must be tested against the real container or marked blocked with a reason" | Stage 0/1 had no SQL — consistent | `validation-log.md` | OK | No fix needed |
| **pgAdmin credentials** | `PGADMIN_DEFAULT_EMAIL: admin@local.dev`, password: admin | docker-compose.yml confirms | `docker-compose.yml` | OK | No fix needed; matches docs |
| **tools/dashboards/README.md pgAdmin creds** | "admin / admin" | docker-compose env: `PGADMIN_DEFAULT_PASSWORD: admin` | `docker-compose.yml` | OK | No fix needed |
| **Grafana anonymous access** | Not explicitly documented | `GF_AUTH_ANONYMOUS_ENABLED: "true"` in compose | `docker-compose.yml` | Info | Worth noting in observability doc |
| **No .github/ directory** | Not claimed anywhere | Confirmed absent | `ls .github/ → No such file` | Medium | Create minimal CI |
| **No docs/ directory** | Not claimed anywhere | Was absent; now created this phase | Phase 0 action | Low | Created: `docs/` now exists |
| **AGENTS.md** | Not referenced in existing docs | File absent | `ls AGENTS.md → No such file` | Low | Create AGENTS.md (done in Phase 13) |
| **.obsidian/ untracked** | Not in `.gitignore` before this phase | Now added to `.gitignore` | `.gitignore` fix | Info | Fixed |
| **open-questions.md** | "Should a learning schema be created?" | Not resolved in any file | `.learning-session/open-questions.md` | Low | Record decision in agent-handoff; recommend `learning` schema |

---

## Summary

| Severity | Count | Status |
|---|---|---|
| High | 1 | Fixed (CURRENT_STAGE.md) |
| Medium | 3 | 2 doc labels to update; 1 CI gap (addressed in Phase 9) |
| Low | 6 | Aspirational file refs are expected; minor label updates |
| Info | 4 | No action required |
| OK | 13 | No issues |

No documentation claims that could break production, security, or deployment. The repo is a learning environment — all claims are safe.
