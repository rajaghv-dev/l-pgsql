# Practice: Simple Transactions

Level: Beginner
Estimated time: 30–45 minutes
Concept file: `concepts/beginner/13-transactions-as-safe-change.md`

## Goals

By the end of this session you will be able to:

1. Execute a multi-step bank transfer inside a BEGIN/COMMIT transaction.
2. Use ROLLBACK to undo an in-progress transaction.
3. Use SAVEPOINT to create a partial undo point within a transaction.
4. Explain what happens to uncommitted changes when viewed from another session.

## Prerequisites

- [ ] Completed: `concepts/beginner/13-transactions-as-safe-change.md`
- [ ] Completed: `concepts/beginner/09-insert-update-delete.md`
- [ ] PostgreSQL container is running: `docker ps | grep cfp_postgres`
- [ ] Database is accessible: `docker exec cfp_postgres psql -U cfp -d cfp -c "SELECT 1"`

## Files in this folder

| File | Purpose |
|------|---------|
| `setup.sql` | Creates bank_accounts table with seed data |
| `00-setup-validation.md` | Validates that setup ran correctly |
| `exercises.md` | Step-by-step exercises |
| `solutions.md` | Full solutions with explanations |
| `reflection.md` | Thinking questions after the exercises |
| `ontology-notes.md` | Concept map for transactions |
| `troubleshooting.md` | Common errors and fixes |
| `references.md` | Topic-specific references |

## Quick start

```bash
# 1. Run setup
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/06-simple-transactions/setup.sql

# 2. Validate setup
# See 00-setup-validation.md

# 3. Open exercises.md and begin
```

## Schema overview

```
bank_accounts (id, owner, balance)
  3 accounts (Alice 1000, Bob 500, Charlie 250) — setup.sql also runs demo transfers
```
