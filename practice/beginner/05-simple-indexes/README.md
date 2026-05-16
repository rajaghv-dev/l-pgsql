# Practice: Simple Indexes

Level: Beginner
Estimated time: 30–45 minutes
Concept file: `concepts/beginner/12-indexes-as-shortcuts.md`

## Goals

By the end of this session you will be able to:

1. Explain the difference between a sequential scan and an index scan by reading EXPLAIN output.
2. Create a B-tree index on a column and observe the plan change.
3. Identify when an index is used and when it is not.
4. Create a partial index for a filtered query.

## Prerequisites

- [ ] Completed: `concepts/beginner/12-indexes-as-shortcuts.md`
- [ ] Completed: `practice/beginner/04-joins-and-aggregation/` (uses the same query patterns)
- [ ] PostgreSQL container is running: `docker ps | grep cfp_postgres`
- [ ] Database is accessible: `docker exec cfp_postgres psql -U cfp -d cfp -c "SELECT 1"`

## Files in this folder

| File | Purpose |
|------|---------|
| `setup.sql` | Creates a products table with 50,000 generated rows |
| `00-setup-validation.md` | Validates that setup ran correctly |
| `exercises.md` | Step-by-step exercises |
| `solutions.md` | Full solutions with explanations |
| `reflection.md` | Thinking questions after the exercises |
| `ontology-notes.md` | Concept map for indexes |
| `troubleshooting.md` | Common errors and fixes |
| `references.md` | Topic-specific references |

## Quick start

```bash
# 1. Run setup (generates 50,000 rows — takes a few seconds)
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/05-simple-indexes/setup.sql

# 2. Validate setup
# See 00-setup-validation.md

# 3. Open exercises.md and begin
```

## Schema overview

```
products (id, sku, name, category, price, in_stock, created_at)
  50,000 rows generated with generate_series
  No indexes initially (added during exercises)
```
