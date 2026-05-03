# Advanced Roadmap

For learners who want systems-level PostgreSQL mastery.

## Goals

- Understand PostgreSQL storage internals (heap, TOAST, WAL)
- Tune autovacuum and bloat management
- Use partitioning and parallel query
- Build observable systems: pg_stat_statements, pg_buffercache, auto_explain
- Design agent-safe architectures: narrow MCP tools, RLS, immutable audit
- Implement cross-tenant isolation
- Use queue patterns with SKIP LOCKED
- Understand replication concepts
- Know when NOT to use PostgreSQL

## Learning path

1. `concepts/advanced/01-storage-internals-heap-toast.md`
2. `concepts/advanced/02-wal-and-checkpoints.md`
3. `concepts/advanced/03-autovacuum-and-bloat.md`
4. `concepts/advanced/04-partitioning.md`
5. `concepts/advanced/05-parallel-query.md`
6. `concepts/advanced/06-observability-pg-stat-statements.md`
7. `concepts/advanced/07-agent-safe-architecture.md`
8. `concepts/advanced/08-cross-tenant-isolation.md`
9. `concepts/advanced/09-queue-patterns-skip-locked.md`
10. `concepts/advanced/10-replication-concepts.md`
11. `concepts/advanced/11-when-not-to-use-postgresql.md`

## Practice sessions

Each topic above has a matching session under `practice/advanced/`.

## MCP/agent angle (advanced level)

At advanced level, focus on:
- MCP gateway design: narrow tools with strict input validation
- Immutable evidence tables (append-only, no DELETE, no UPDATE)
- Rollback and compensation patterns
- Cross-tenant RLS policies
- Performance impact of agent write patterns

## Final

After advanced lessons → see `diagrams/`, `reflections/`, `design-principles/`.
