# Practice: JOINs and Aggregation

Level: Beginner
Estimated time: 45–60 minutes
Concept files: `concepts/beginner/10-joins-intuition.md`, `concepts/beginner/11-aggregation-intuition.md`

## Goals

By the end of this session you will be able to:

1. Write an INNER JOIN to combine books and authors into a single result set.
2. Write a LEFT JOIN to find books that have never been checked out.
3. Use GROUP BY + COUNT to count checkouts per author.
4. Use HAVING to filter groups, and AVG to compute average checkout duration.

## Prerequisites

- [ ] Completed: `concepts/beginner/10-joins-intuition.md`
- [ ] Completed: `concepts/beginner/11-aggregation-intuition.md`
- [ ] Completed: `concepts/beginner/08-select-filter-sort-limit.md`
- [ ] PostgreSQL container is running: `docker ps | grep cfp_postgres`
- [ ] Database is accessible: `docker exec cfp_postgres psql -U cfp -d cfp -c "SELECT 1"`

## Files in this folder

| File | Purpose |
|------|---------|
| `setup.sql` | Creates library tables and inserts seed data |
| `00-setup-validation.md` | Validates that setup ran correctly |
| `exercises.md` | Step-by-step exercises |
| `solutions.md` | Full solutions with explanations |
| `reflection.md` | Thinking questions after the exercises |
| `ontology-notes.md` | Concept map for JOINs and aggregation |
| `troubleshooting.md` | Common errors and fixes |
| `references.md` | Topic-specific references |

## Quick start

```bash
# 1. Run setup
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/04-joins-and-aggregation/setup.sql

# 2. Validate setup
# See 00-setup-validation.md

# 3. Open exercises.md and begin
```

## Schema overview

```
authors (id, name, birth_year)
    └── books (id, title, author_id FK, published_year, pages)
              └── checkouts (id, book_id FK, patron_id, checked_out_at, returned_at)
```

This is the same library catalog used in concept files 08–13.
