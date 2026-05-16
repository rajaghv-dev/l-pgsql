# Security Audit

Generated: 2026-05-16  
Phase: 10

---

## Summary

This is a local development learning repo. No production secrets, API keys, or sensitive data were found. All credentials are intentional local dev defaults.

---

## Findings

| Item | File | Type | Risk | Status |
|---|---|---|---|---|
| PostgreSQL credentials (`cfp/cfp`) | `tools/dashboards/docker-compose.yml`, `scripts/`, `memory.md` | Local dev default | **Low** — local container only, not internet-exposed | Acceptable; documented |
| pgAdmin credentials (`admin/admin`) | `tools/dashboards/docker-compose.yml` | Local dev default | **Low** — local only | Acceptable |
| Grafana credentials (`admin/admin`) | `tools/dashboards/docker-compose.yml` | Local dev default | **Low** — local only | Acceptable |
| pgAdmin pgpass file | `tools/dashboards/pgadmin/pgpass` | Password file on disk | **Info** — contains `cfp` password; local dev file | Not in .gitignore; acceptable (same cred as docker-compose) |
| `GF_AUTH_ANONYMOUS_ENABLED: "true"` | `tools/dashboards/docker-compose.yml` | Anonymous Grafana access | **Info** — local dev convenience | Acceptable; note in docs |
| `DATA_SOURCE_NAME: "postgresql://cfp:cfp@..."` | `tools/dashboards/docker-compose.yml` | Postgres creds in env var | **Low** — local dev standard pattern | Acceptable |
| Python venv `.l-pgsql/` | `.gitignore` | Not committed | **None** | In .gitignore — safe |

---

## Hardcoded secrets scan result

No API keys, tokens, private URLs, or production secrets found.

All credentials are:
1. Local development defaults (`cfp/cfp`, `admin/admin`)
2. Documented explicitly in `memory.md` and `tools/dashboards/README.md`
3. Not intended for production

---

## .gitignore coverage

| Pattern | Purpose | Status |
|---|---|---|
| `*.zip`, `*.tar.gz`, `*.tgz` | Binary archives | Covered |
| `.l-pgsql/`, `venv/`, `.venv/` | Python venv | Covered |
| `__pycache__/`, `*.pyc` | Python bytecode | Covered |
| `.DS_Store`, `Thumbs.db` | OS files | Covered |
| `.vscode/`, `*.swp`, `*~` | Editor files | Covered |
| `.obsidian/` | Obsidian vault settings | Added in this refactor |

No `.env` file exists (not needed — all config is in docker-compose.yml or shell scripts). No `.env.example` needed.

---

## GitHub Actions permissions

No `.github/` directory exists yet. New workflow added in Phase 9 uses least-privilege:

```yaml
permissions:
  contents: read
```

---

## Subject matter vs repo security

This repo teaches security-relevant PostgreSQL features (RLS, pgcrypto, audit tables, tenant isolation) as lesson content. The teaching examples use synthetic data and safe patterns. No real production schemas or data are present.

---

## Recommendations

1. Pin the `open-webui:main` Docker image tag to a specific version (reduces supply-chain risk for the image, not the repo).
2. When Stage 11 (security, audit, observability) runs, ensure all pgcrypto examples use synthetic data.
3. If this repo is ever made public (it may already be), confirm no real PII appears in any committed file.
