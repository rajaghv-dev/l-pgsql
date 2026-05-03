# Beginner Roadmap

Start here if you are new to PostgreSQL or relational databases.

## Goals

- Connect to PostgreSQL
- Understand tables, rows, columns, and types
- Write basic SELECT, INSERT, UPDATE, DELETE
- Understand constraints: NOT NULL, UNIQUE, PRIMARY KEY, FOREIGN KEY, CHECK
- Understand basic indexes
- Understand simple transactions
- Use JSONB for flexible data
- Run a full-text search query
- Install and test an extension

## Learning path

1. `concepts/beginner/01-what-is-postgresql.md`
2. `concepts/beginner/02-connecting-and-first-query.md`
3. `concepts/beginner/03-tables-columns-types.md`
4. `concepts/beginner/04-insert-select-update-delete.md`
5. `concepts/beginner/05-constraints.md`
6. `concepts/beginner/06-indexes-basics.md`
7. `concepts/beginner/07-transactions-basics.md`
8. `concepts/beginner/08-jsonb-basics.md`
9. `concepts/beginner/09-full-text-search-intro.md`
10. `concepts/beginner/10-extensions-intro.md`

## Practice sessions

Each topic above has a matching session under `practice/beginner/`.

## MCP/agent angle (beginner level)

At beginner level, focus on:
- What state an agent might read (SELECT)
- What state an agent might write (INSERT, UPDATE)
- Why constraints protect agent writes
- Simple audit: log every agent action

## Next

After completing all beginner lessons → see `intermediate-roadmap.md`.
