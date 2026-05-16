# GitHub Readiness

Generated: 2026-05-16  
Phase: 9

---

## Current state

| Item | Status | Notes |
|---|---|---|
| `.github/` directory | Created this phase | Previously absent |
| GitHub Actions workflows | Added `validate.yml` | Lints YAML and checks Markdown |
| PR template | Added | `.github/PULL_REQUEST_TEMPLATE.md` |
| Issue templates | Not added | Not needed for a 1-person learning repo |
| Dependabot | Not added | No package dependencies to update |
| CODEOWNERS | Not added | Single owner |
| Code scanning (CodeQL) | Not added | No application code |
| Branch protection | Not configured | Recommendation below |

---

## Workflow: validate.yml

Added at `.github/workflows/validate.yml`.

What it does:
- Triggers on push and PR to `main`
- Lints all YAML files (`yamllint`)
- Checks Markdown files with `markdownlint-cli2`
- Validates `docker-compose.yml` syntax with `docker compose config`

Permissions: `contents: read` (least privilege).

---

## Branch protection recommendations

For GitHub repository settings:
- Require PR reviews before merge: optional (single-person repo)
- Require status checks: enable `validate` workflow as required check
- Protect `main` branch from force push

---

## PR template

Added at `.github/PULL_REQUEST_TEMPLATE.md`. Template includes:
- Stage being completed
- Validation results
- Files changed
- Checklist (validation run, session files updated, no secrets, synthetic data only)

---

## Release workflow

Not needed at this time. This is a learning content repo without versioned releases.

---

## GitHub Pages

Not configured. Could be added later to render lessons as a static site.

---

## Remaining gaps

| Gap | Priority | Notes |
|---|---|---|
| Issue templates | Low | Not needed for 1-person repo |
| Dependabot | Low | No `package.json`, no `pyproject.toml` |
| GitHub Pages | Low | Future enhancement |
| CodeQL | N/A | No application code |
