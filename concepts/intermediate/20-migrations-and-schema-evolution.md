# Migrations and Schema Evolution

Level: Intermediate

## One-line intuition
Schema migrations are the version control system for your database structure — applied forward-only, idempotently, and safely in production.

## Why this exists
Databases outlive application versions. As requirements change, tables gain columns, indexes are added, constraints tighten. Without a disciplined migration process, schema changes become risky, undocumented, and unrepeatable across environments. Migrations encode every schema change as a versioned, reviewable, executable script.

## First-principles explanation
A migration is a SQL script that transforms a database from schema version N to version N+1. Migration tools (Flyway, Liquibase, Alembic, golang-migrate, sqitch) maintain a tracking table recording which migrations have been applied. Each migration has a unique version identifier and runs exactly once. The key safety rules: never modify an already-applied migration (it breaks checksums), always write forward-only migrations (rollback scripts are rarely reliable), and keep migrations atomic — each in its own transaction. PostgreSQL supports transactional DDL (most DDL can be rolled back inside a transaction), which is a major advantage for safe migrations.

## Micro-concepts
- **Idempotency**: a migration that can be applied multiple times without changing the result beyond the first application
- **Forward-only**: never modifying applied migrations; rollback means writing a new migration
- **Lock types**: `ALTER TABLE ADD COLUMN` (non-null without default) is safe; `ADD COLUMN NOT NULL` without a default acquires a full table lock
- **Concurrent index creation**: `CREATE INDEX CONCURRENTLY` avoids locking reads/writes during index build
- **Online migration**: a technique to rename columns or change types without locking the table

## Beginner view
Think of migrations like a sequence of numbered recipe cards. Each card changes the dish (database). You always follow them in order. Once a card is in the book, you never change it — you add a new card to fix mistakes.

## Intermediate view
The most dangerous migrations are those that take `ACCESS EXCLUSIVE` locks: `ALTER TABLE ADD COLUMN NOT NULL` (pre-PG 11), changing column types, adding foreign keys with validation, dropping columns. Mitigation strategies: use `ADD COLUMN` with a default (PG 11+ stores it in the catalog, not per-row), use `NOT VALID` + `VALIDATE CONSTRAINT` in separate transactions, use `CREATE INDEX CONCURRENTLY`. Always test migrations on a production-size dataset to measure lock duration before running in production.

## Advanced view
PostgreSQL 11+ made adding a column with a non-volatile default almost instantaneous (metadata-only change). PostgreSQL 12 introduced `generated columns`. Large table type changes require the expand-contract pattern: (1) add new column, (2) dual-write in application, (3) backfill old data, (4) switch reads to new column, (5) drop old column. This pattern runs the migration across multiple deployments with zero downtime. `pg_repack` and `pg_squeeze` can rewrite tables online when `VACUUM FULL` is not an option.

## Mental model
Migrations are like geological strata: each layer was deposited at a specific point in time, in order, and the current state of the database is the sum of all layers applied from bottom to top.

## PostgreSQL view
```sql
-- Common migration tracking table (e.g., Flyway)
SELECT version, description, installed_on, success
FROM flyway_schema_history
ORDER BY installed_rank;

-- Check lock type for an ALTER TABLE (run in a test transaction, then rollback)
BEGIN;
ALTER TABLE orders ADD COLUMN notes TEXT;
-- Check pg_locks in another session
ROLLBACK;
```

## SQL view
```sql
-- Safe: add nullable column (no lock needed)
ALTER TABLE orders ADD COLUMN notes TEXT;

-- Safe in PG 11+: add non-null column with a default (catalog-only change)
ALTER TABLE orders ADD COLUMN status TEXT NOT NULL DEFAULT 'pending';

-- Safe: create index without blocking reads/writes
CREATE INDEX CONCURRENTLY idx_orders_status ON orders (status);

-- Safe: add FK without full table scan holding lock
ALTER TABLE order_items
  ADD CONSTRAINT fk_order FOREIGN KEY (order_id) REFERENCES orders (id)
  NOT VALID;          -- Step 1: structural constraint, no scan

ALTER TABLE order_items VALIDATE CONSTRAINT fk_order;  -- Step 2: validate in bg

-- Idempotent pattern (useful for manual scripts)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'notes'
  ) THEN
    ALTER TABLE orders ADD COLUMN notes TEXT;
  END IF;
END;
$$;

-- blocked: Docker not accessible; validate against cfp_postgres when available
```

## Non-SQL or hybrid view
JSONB columns reduce the migration surface: you can evolve document structure without schema changes. The trade-off is loss of constraint enforcement and query planning quality. A hybrid strategy: use JSONB for rapidly evolving attributes, and migrate to typed columns once a field stabilizes and needs indexing.

## Design principle
Never modify an already-applied migration — write a new one instead. The migration history is a fact of what happened; retroactive edits corrupt it and break all environment consistency checks.

## Critical thinking
If a migration takes an `ACCESS EXCLUSIVE` lock for 10 seconds and you have a connection pool of 20 connections, what happens to the 21st query that arrives during those 10 seconds, and how does this cascade?

## Creative thinking
Could you design a schema evolution system where all changes are append-only (new columns, new tables only) and old columns are never dropped — treating the database like an event log of schema intentions?

## Systems thinking
Migrations interact with connection poolers (long-running migrations hold connections), replication lag (DDL on primary blocks replica apply), autovacuum (newly populated columns need a vacuum pass), and CI/CD pipelines (migration checks must be part of the deploy gate, not an afterthought).

## MCP and agent perspective
An AI agent must never run schema migrations autonomously. DDL changes — even safe-looking ones — can lock tables, cascade to dependent objects, or invalidate cached query plans. Agents should detect when a requested change requires DDL and escalate to a human operator with a proposed migration script for review.

## Ontology perspective
Migrations are the temporal dimension of schema design — they encode not just the current state but the entire history of how you got there. The migration history is an ontological record of the schema's evolution: each migration is an event that transformed the database from one valid ontological state to the next.

The expand-contract pattern is an ontological pattern for safe evolution: first expand the ontology (add new types/properties alongside old ones), allow dual existence during transition, then contract (remove the old form). This mirrors how ontologies evolve without breaking dependent systems — new terms are introduced before old ones are deprecated.

The "make before break" principle: always create the new structure, migrate data, then remove the old structure. Never break the old structure before the new one is ready.

## Practice session
This concept does not have a dedicated practice folder. Exercises appear throughout other practices (especially Stage 11) that require schema modifications. For advanced migration patterns, see the `scripts/` directory and the intermediate roadmap migration notes.

## References
- PostgreSQL docs — ALTER TABLE: https://www.postgresql.org/docs/16/sql-altertable.html
- PostgreSQL docs — CREATE INDEX CONCURRENTLY: https://www.postgresql.org/docs/16/sql-createindex.html#SQL-CREATEINDEX-CONCURRENTLY
- PostgreSQL docs — ADD CONSTRAINT NOT VALID: https://www.postgresql.org/docs/16/sql-altertable.html
- Flyway: https://flywaydb.org/
- Liquibase: https://www.liquibase.org/
- "Zero-Downtime Postgres Schema Changes": https://www.braintreepayments.com/blog/safe-operations-for-high-volume-postgresql/
- "Expand-Contract Pattern": https://martinfowler.com/bliki/ParallelChange.html
