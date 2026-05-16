# Practice: JSONB Basics

Level: Beginner
Estimated time: 30–45 minutes
Concept file: `concepts/beginner/14-jsonb-as-flexible-data.md`

## Goals

By the end of this session you will be able to:

1. Insert JSONB data and query values using `->` and `->>` operators.
2. Filter rows using the `@>` containment operator.
3. Update a nested JSONB key using `jsonb_set()`.
4. Create a GIN index on a JSONB column and verify it is used by EXPLAIN.

## Prerequisites

- [ ] Completed: `concepts/beginner/14-jsonb-as-flexible-data.md`
- [ ] Completed: `concepts/beginner/12-indexes-as-shortcuts.md`
- [ ] PostgreSQL container is running: `docker ps | grep cfp_postgres`
- [ ] Database is accessible: `docker exec cfp_postgres psql -U cfp -d cfp -c "SELECT 1"`

## Files in this folder

| File | Purpose |
|------|---------|
| `setup.sql` | Creates user_profiles table with JSONB metadata column |
| `00-setup-validation.md` | Validates that setup ran correctly |
| `exercises.md` | Step-by-step exercises |
| `solutions.md` | Full solutions with explanations |
| `reflection.md` | Thinking questions after the exercises |
| `ontology-notes.md` | Concept map for JSONB |
| `troubleshooting.md` | Common errors and fixes |
| `references.md` | Topic-specific references |

## Quick start

```bash
# 1. Run setup
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/07-jsonb-basics/setup.sql

# 2. Validate setup
# See 00-setup-validation.md

# 3. Open exercises.md and begin
```

## Schema overview

```
user_profiles (id, username, metadata JSONB)
  5 rows of synthetic seed data with varying JSONB structures
  metadata keys: age, plan, tags (array), location (nested), preferences (nested)
```
