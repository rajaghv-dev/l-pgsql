# Intermediate Roadmap

For learners comfortable with basic SQL who want deeper PostgreSQL mastery.

## Goals

- Design normalized schemas with trade-off awareness
- Use EXPLAIN ANALYZE and understand query plans
- Choose the right index type (B-tree, GIN, GiST, BRIN)
- Use transactions safely: isolation levels, deadlocks
- Understand MVCC
- Apply Row Level Security (RLS)
- Build an audit table
- Use pg_trgm, pgvector, pgcrypto, ltree, hstore
- Write PL/pgSQL functions and triggers

## Learning path

1. `concepts/intermediate/01-schema-design-tradeoffs.md`
2. `concepts/intermediate/02-explain-analyze.md`
3. `concepts/intermediate/03-index-types.md`
4. `concepts/intermediate/04-transactions-isolation-deadlocks.md`
5. `concepts/intermediate/05-mvcc.md`
6. `concepts/intermediate/06-rls.md`
7. `concepts/intermediate/07-audit-tables.md`
8. `concepts/intermediate/08-extensions-pg-trgm-pgcrypto.md`
9. `concepts/intermediate/09-pgvector-vector-search.md`
10. `concepts/intermediate/10-plpgsql-basics.md`

## Practice sessions

Each topic above has a matching session under `practice/intermediate/`.

## MCP/agent angle (intermediate level)

At intermediate level, focus on:
- RLS isolating tenant data from agent access
- Audit tables recording every agent write
- Approval workflows before destructive operations
- Transactions bounding agent multi-step operations
- Vector retrieval for semantic memory

## Next

After completing all intermediate lessons → see `advanced-roadmap.md`.
