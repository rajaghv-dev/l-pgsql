# Practice: Roles Basics

Level: Beginner
Estimated time: 30–45 minutes
Concept file: `concepts/beginner/16-roles-and-permissions.md`

## Goals

By the end of this session you will be able to:

1. Create a read-only role and a login role that inherits from it.
2. GRANT SELECT on specific tables (and views) to the read-only role.
3. Connect as the login role and verify SELECT works.
4. Verify INSERT is rejected by the database.
5. Apply the agent/MCP principle: agents get minimum required permissions.

## Prerequisites

- [ ] Completed: `concepts/beginner/16-roles-and-permissions.md`
- [ ] Completed: `practice/beginner/08-views-and-functions-basics/` (reuses library_books table)
- [ ] PostgreSQL container is running: `docker ps | grep cfp_postgres`
- [ ] Database is accessible: `docker exec cfp_postgres psql -U cfp -d cfp -c "SELECT 1"`

## Files in this folder

| File | Purpose |
|------|---------|
| `setup.sql` | Creates library_books table with seed data |
| `00-setup-validation.md` | Validates that setup ran correctly |
| `exercises.md` | Step-by-step exercises |
| `solutions.md` | Full solutions with explanations |
| `reflection.md` | Thinking questions after the exercises |
| `ontology-notes.md` | Concept map for roles and permissions |
| `troubleshooting.md` | Common errors and fixes |
| `references.md` | Topic-specific references |

## Quick start

```bash
# 1. Run setup
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/09-roles-basics/setup.sql

# 2. Validate setup
# See 00-setup-validation.md

# 3. Open exercises.md and begin
```

## Note on role creation

Role creation (`CREATE ROLE`, `GRANT`) requires SUPERUSER or CREATEROLE privilege. In the cfp_postgres container, the `cfp` user has these privileges. The exercises below run as `cfp`.
