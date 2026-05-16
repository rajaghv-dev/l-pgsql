# Online Migrations and Reliability

Level: Advanced

## One-line intuition
Every schema migration that takes a table lock in production is a potential outage — understanding which operations are safe, which require workarounds, and how to decompose dangerous migrations into safe multi-step sequences is the difference between a 2-minute deploy and a 2-hour incident.

## Why this exists
PostgreSQL schema changes are SQL DDL operations. Many of them take an `AccessExclusiveLock` on the affected table — blocking all reads and writes for the duration. For large tables, "the duration" can be minutes to hours. Online migration patterns allow schema changes to be applied without service interruption, by trading simplicity for a multi-step process that avoids full-table locks.

## First-principles explanation

### Lock modes for common DDL

| Operation | Lock mode | Safe in production? |
|---|---|---|
| `ADD COLUMN` (nullable, no default) | `AccessExclusiveLock` (brief) | Yes — only updates pg_attribute |
| `ADD COLUMN DEFAULT` (non-volatile, PG 11+) | `AccessExclusiveLock` (brief) | Yes — metadata-only in PG 11+ |
| `ADD COLUMN DEFAULT` (pre-PG 11) | `AccessExclusiveLock` (full rewrite) | No — rewrites entire table |
| `DROP COLUMN` | `AccessExclusiveLock` (brief) | Yes — metadata-only |
| `ALTER COLUMN TYPE` | `AccessExclusiveLock` (full rewrite) | No — rewrites entire table |
| `ADD CONSTRAINT` (CHECK) | `AccessExclusiveLock` | No — validates all rows |
| `ADD CONSTRAINT NOT VALID` | `ShareUpdateExclusiveLock` | Yes — doesn't validate |
| `VALIDATE CONSTRAINT` | `ShareUpdateExclusiveLock` | Yes — validates concurrent DML |
| `CREATE INDEX` | `ShareLock` | No — blocks writes |
| `CREATE INDEX CONCURRENTLY` | `ShareUpdateExclusiveLock` | Yes — allows DML |
| `DROP INDEX` | `AccessExclusiveLock` (brief) | Yes — usually brief |
| `DROP INDEX CONCURRENTLY` | `ShareUpdateExclusiveLock` | Yes |
| `TRUNCATE` | `AccessExclusiveLock` | No |
| `ALTER TABLE RENAME` | `AccessExclusiveLock` (brief) | Yes — brief |

### Safe patterns for common migrations

#### Pattern 1: ADD COLUMN with default (PG 11+)
```sql
-- blocked: Docker not accessible
-- PG 11+: stored defaults are metadata-only (no rewrite)
ALTER TABLE orders ADD COLUMN processed_at timestamptz DEFAULT now();
-- Existing rows get the default stored in pg_attribute, not written physically
-- SAFE in PG 11+ — takes AccessExclusiveLock briefly for catalog update only

-- Pre-PG11 workaround (if needed):
ALTER TABLE orders ADD COLUMN processed_at timestamptz;          -- fast (nullable)
ALTER TABLE orders ALTER COLUMN processed_at SET DEFAULT now();  -- set default
UPDATE orders SET processed_at = now() WHERE processed_at IS NULL;  -- backfill in batches
ALTER TABLE orders ALTER COLUMN processed_at SET NOT NULL;       -- NOT NULL last (uses NOT VALID)
```

#### Pattern 2: NOT VALID + VALIDATE CONSTRAINT
Adding a NOT NULL or CHECK constraint on a large table validates all rows — potentially hours.
```sql
-- blocked: Docker not accessible
-- Step 1: Add constraint without validation (immediate, ShareUpdateExclusiveLock)
ALTER TABLE orders ADD CONSTRAINT orders_status_valid
    CHECK (status IN ('pending', 'shipped', 'cancelled')) NOT VALID;
-- Existing rows not checked; new rows are checked immediately

-- Step 2: Validate (slow but safe — allows concurrent DML)
ALTER TABLE orders VALIDATE CONSTRAINT orders_status_valid;
-- Uses ShareUpdateExclusiveLock, compatible with SELECT and DML
```

#### Pattern 3: CREATE INDEX CONCURRENTLY
```sql
-- blocked: Docker not accessible
-- Standard CREATE INDEX blocks all writes
-- CREATE INDEX idx_orders_customer ON orders (customer_id);  -- BAD in production

-- CONCURRENTLY: allows DML during build (3 passes over the table)
CREATE INDEX CONCURRENTLY idx_orders_customer ON orders (customer_id);
-- Cannot be run inside a transaction block
-- If it fails, leaves an INVALID index: DROP INDEX CONCURRENTLY idx_orders_customer; then retry

-- Drop old index safely
DROP INDEX CONCURRENTLY old_idx_orders_customer;
```

#### Pattern 4: Rename table with view alias
```sql
-- blocked: Docker not accessible
-- Step 1: Create view with old name pointing to new table
CREATE VIEW orders AS SELECT * FROM purchase_orders;  -- view with old name

-- Step 2: Deploy application changes pointing to purchase_orders
-- Step 3: Remove the view alias
DROP VIEW orders;
```

#### Pattern 5: ALTER COLUMN TYPE (zero-downtime)
```sql
-- blocked: Docker not accessible
-- Step 1: Add new column
ALTER TABLE orders ADD COLUMN id_new bigint;

-- Step 2: Dual-write in application (write to both id and id_new)
-- Step 3: Backfill in chunks
UPDATE orders SET id_new = id WHERE id BETWEEN 1 AND 100000;
-- Repeat for each range

-- Step 4: Add NOT NULL (NOT VALID + VALIDATE)
ALTER TABLE orders ADD CONSTRAINT id_new_notnull CHECK (id_new IS NOT NULL) NOT VALID;
ALTER TABLE orders VALIDATE CONSTRAINT id_new_notnull;

-- Step 5: Swap column names (brief AccessExclusiveLock)
ALTER TABLE orders RENAME COLUMN id TO id_old;
ALTER TABLE orders RENAME COLUMN id_new TO id;

-- Step 6: Drop old column after application no longer writes it
ALTER TABLE orders DROP COLUMN id_old;
```

#### Pattern 6: lock_timeout for DDL safety
```sql
-- blocked: Docker not accessible
SET lock_timeout = '3s';
SET statement_timeout = '30s';
ALTER TABLE orders ADD COLUMN notes text;
-- If it can't get the lock in 3s, it fails fast instead of queuing
```

### pg_repack — online table rebuilding
`pg_repack` rebuilds a table and its indexes without taking a long lock:
- Adds a shadow table, copies data, applies delta changes, swaps tables
- Ideal for reclaiming bloat (alternative to VACUUM FULL) without the full lock

```bash
# Shell command (requires pg_repack extension installed)
pg_repack -h localhost -U postgres -d mydb -t orders
```

### Expand-contract pattern
For large teams with rolling deploys:
1. **Expand**: add new columns/tables alongside old ones (backward compatible)
2. **Migrate**: backfill data, dual-write in application
3. **Contract**: remove old columns after all code is updated

This distributes migration risk across multiple deployments with rollback windows at each step.

## Micro-concepts
- **AccessExclusiveLock**: the most exclusive lock. Prevents all other access. DDL default.
- **ShareUpdateExclusiveLock**: allows reads and DML; prevents concurrent schema changes.
- **CONCURRENTLY modifier**: available for CREATE INDEX and DROP INDEX. Multiple passes; cannot be in a transaction.
- **NOT VALID**: constraint created but not verified for existing rows. New rows are checked immediately.
- **VALIDATE CONSTRAINT**: validates existing rows against a NOT VALID constraint. Safe concurrent with DML.
- **`lock_timeout`**: session parameter. Raises error if lock cannot be acquired within N ms. Essential for production DDL.
- **INVALID index**: created by a failed CONCURRENTLY operation. Must be dropped before recreating.
- **pg_stat_progress_create_index**: shows progress of CREATE INDEX CONCURRENTLY.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: ALTER TABLE changes the schema. Some changes are slow for big tables.

**Intermediate view**: Use CREATE INDEX CONCURRENTLY. Use NOT VALID + VALIDATE CONSTRAINT. Set lock_timeout on DDL.

**Advanced view**: Every zero-downtime migration is a multi-step process that accepts temporary inconsistency (dual-write period, partial backfill) in exchange for availability. The expand-contract pattern is the architectural foundation. CREATE INDEX CONCURRENTLY requires two passes; if write rate is very high, the index may fail to converge — monitor pg_stat_progress_create_index. For ALTER COLUMN TYPE on billion-row tables, a full shadow table migration (pg_repack or ghost pattern) may take weeks. Always check for INVALID indexes after concurrent operations. In rolling deploys, the migration window must account for the time for all application instances to update.

## Mental model
Schema migration is like renovating a store while it's open:
- **Metadata-only changes** (add nullable column): rearranging the sign — takes seconds, no disruption
- **CREATE INDEX CONCURRENTLY**: installing new shelving while customers shop — takes time, but they can still browse
- **NOT VALID + VALIDATE**: putting up new policy signage — new customers follow new rules, old merchandise inspected later
- **Column type change**: replacing all cash registers — need a ghost register running in parallel during switchover
- **pg_repack**: rebuilding the store floor with customers still inside

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_indexes` (find INVALID indexes), `pg_stat_progress_create_index` (build progress), `pg_locks` (DDL lock monitoring).

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Find INVALID indexes (failed CONCURRENTLY builds)
SELECT schemaname, tablename, indexname FROM pg_indexes
WHERE indexname NOT IN (
    SELECT indexrelid::regclass::text FROM pg_index WHERE indisvalid
);

-- Monitor index build progress
SELECT relid::regclass AS table, phase, blocks_done, blocks_total,
       round(blocks_done::numeric / nullif(blocks_total, 0) * 100, 1) AS pct
FROM pg_stat_progress_create_index;

-- Current DDL lock pending
SELECT pid, locktype, mode, granted, relation::regclass
FROM pg_locks WHERE granted = false AND locktype = 'relation';
```

**Non-SQL / hybrid view**: pgroll (https://github.com/xataio/pgroll), reshape (https://github.com/fabianlindfors/reshape), Flyway/Liquibase (migration frameworks). Strong Migrations (Rails gem) is an excellent reference for which operations are safe — applicable beyond Rails.

## Design principle
**Every migration in production must have a rollback plan**: Before running a migration, know how to undo it. For additive changes (add column, add index), rollback is DROP. For destructive changes (drop column, drop table), rollback requires restoring from backup — which is why destructive changes should be deferred until you're certain (expand-contract).

## Critical thinking / Creative thinking / Systems thinking

**Critical**: `CREATE INDEX CONCURRENTLY` requires two passes over the table. If the table is large (100GB), the first pass takes 30 minutes. During those 30 minutes, writes continue — the second pass must catch up. If the write rate is very high, the index may fail to converge. Monitor `pg_stat_progress_create_index` for stalling. For very high-write-rate tables, run index creation during a low-traffic window.

**Creative**: Use a pre-migration checklist script that runs before every migration:
```sql
-- blocked: Docker not accessible
-- Check for long-running transactions that might block DDL
SELECT count(*) FROM pg_stat_activity
WHERE state != 'idle' AND query_start < now() - interval '5 minutes';
-- If count > 0, delay migration and investigate
```

**Systems**: In a multi-instance deployment (load-balanced application servers), schema changes propagate from the database immediately, but application code changes deploy progressively. A migration that adds a NOT NULL column without a default breaks old application code still running on other instances. The migration window must account for the rolling deploy time.

## MCP and agent perspective
AI agents may trigger schema migrations as part of self-modification or tool creation. Agent-triggered DDL must use the same safety patterns: `lock_timeout`, `CREATE INDEX CONCURRENTLY`, `NOT VALID` constraints. Never give agents direct DDL execution rights without a human approval step in a `pending_schema_changes` table that an operator reviews and executes.

## Ontology perspective
Schema migration is a temporal discontinuity in the database's ontology: before the migration, type X has attributes A, B, C; after, it has A, B, C, D. Zero-downtime migration manages this ontological transition so it appears continuous from the outside. The expand-contract pattern creates an overlap period where both old and new ontology coexist simultaneously, allowing all observers to transition at their own pace.

## Practice session

**Exercise 1 — Safe column addition (PG 11+)**:
```sql
-- blocked: Docker not accessible
ALTER TABLE orders ADD COLUMN notes text;        -- nullable, instant
ALTER TABLE orders ADD COLUMN priority int DEFAULT 5;  -- with stored default, instant PG11+
```

**Exercise 2 — NOT VALID constraint pattern**:
```sql
-- blocked: Docker not accessible
ALTER TABLE orders ADD CONSTRAINT chk_priority
    CHECK (priority BETWEEN 1 AND 10) NOT VALID;
-- Later (can run during production):
ALTER TABLE orders VALIDATE CONSTRAINT chk_priority;
```

**Exercise 3 — CREATE INDEX CONCURRENTLY**:
```sql
-- blocked: Docker not accessible
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_status ON orders (status);
-- Check progress:
SELECT phase, blocks_done, blocks_total FROM pg_stat_progress_create_index;
```

**Exercise 4 — lock_timeout for DDL**:
```sql
-- blocked: Docker not accessible
SET lock_timeout = '5s';
ALTER TABLE orders ADD COLUMN delivery_date date;
RESET lock_timeout;
```

**Exercise 5 — Find INVALID indexes**:
```sql
-- blocked: Docker not accessible
SELECT schemaname, tablename, indexname
FROM pg_indexes
WHERE indexname NOT IN (
    SELECT indexrelid::regclass::text FROM pg_index WHERE indisvalid
);
```

## References
- PostgreSQL Documentation: [ALTER TABLE](https://www.postgresql.org/docs/16/sql-altertable.html)
- PostgreSQL Documentation: [CREATE INDEX CONCURRENTLY](https://www.postgresql.org/docs/16/sql-createindex.html#SQL-CREATEINDEX-CONCURRENTLY)
- PostgreSQL Documentation: [pg_stat_progress_create_index](https://www.postgresql.org/docs/16/progress-reporting.html#CREATE-INDEX-PROGRESS-REPORTING)
- Braintree: [Safe Operations for High Volume PostgreSQL](https://www.braintreepayments.com/blog/safe-operations-for-high-volume-postgresql/)
- pgroll: https://github.com/xataio/pgroll
- pg_repack: https://github.com/reorg/pg_repack
- Strong Migrations gem (Rails): https://github.com/ankane/strong_migrations
