# Practice: Views and Functions Basics

Level: Beginner
Estimated time: 30–45 minutes
Concept file: `concepts/beginner/15-views-as-saved-questions.md`

## Goals

By the end of this session you will be able to:

1. Create a VIEW for available books and query it like a table.
2. Add an additional filter on top of a view (views are composable).
3. Write a simple SQL function with arguments and use it in a SELECT.
4. Explain when to use a view vs a materialized view.

## Prerequisites

- [ ] Completed: `concepts/beginner/15-views-as-saved-questions.md`
- [ ] Completed: `practice/beginner/04-joins-and-aggregation/` (uses same library schema)
- [ ] PostgreSQL container is running: `docker ps | grep cfp_postgres`
- [ ] Database is accessible: `docker exec cfp_postgres psql -U cfp -d cfp -c "SELECT 1"`

## Files in this folder

| File | Purpose |
|------|---------|
| `setup.sql` | Library schema + seed data + demo views and function |
| `00-setup-validation.md` | Validates that setup ran correctly |
| `exercises.md` | Step-by-step exercises |
| `solutions.md` | Full solutions with explanations |
| `reflection.md` | Thinking questions after the exercises |
| `ontology-notes.md` | Concept map for views and functions |
| `troubleshooting.md` | Common errors and fixes |
| `references.md` | Topic-specific references |

## Quick start

```bash
# 1. Run setup
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/08-views-and-functions-basics/setup.sql

# 2. Validate setup
# See 00-setup-validation.md

# 3. Open exercises.md and begin
```

## Schema overview

```
books (id, title, author, genre, year, total_copies)
checkouts (id, book_id FK, patron_name, checked_out, due_date, returned_at)

Pre-created by setup.sql:
  VIEW: available_books  — books with no active checkout
  VIEW: active_checkouts — current checkouts with book title
  FUNCTION: days_overdue(due DATE) → INT — days past due_date
```
