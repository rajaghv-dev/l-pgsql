# Transaction and MVCC Flow

How PostgreSQL uses Multi-Version Concurrency Control (MVCC) to give each transaction a consistent snapshot without locking readers.

## MVCC Snapshot Isolation

```mermaid
sequenceDiagram
    participant TxA as Transaction A<br/>(xid = 100)
    participant DB as PostgreSQL<br/>(shared heap)
    participant TxB as Transaction B<br/>(xid = 101)
    participant VAC as Autovacuum

    TxA->>DB: BEGIN
    Note over TxA: snapshot: xmin=100, active=[100]
    TxA->>DB: SELECT count(*) FROM orders
    DB-->>TxA: 1000 rows (all visible, xmax=NULL)

    TxB->>DB: BEGIN
    TxB->>DB: INSERT INTO orders (user_id, total) VALUES (99, 150.00)
    Note over DB: New row: xmin=101, xmax=NULL
    TxB->>DB: COMMIT

    TxA->>DB: SELECT count(*) FROM orders
    Note over DB: Row with xmin=101: is 101 in TxA's snapshot?<br/>101 > 100 (TxA's xmin) AND 101 was active when TxA started<br/>→ NOT VISIBLE to TxA
    DB-->>TxA: 1000 rows (same as before — snapshot isolation)

    TxA->>DB: COMMIT

    Note over VAC: Both transactions committed.<br/>No active transactions hold snapshots older than 101.
    VAC->>DB: VACUUM orders
    Note over DB: Dead tuples (xmax != NULL, no live snapshots need them)<br/>are marked free. Pages can be reused.
    DB-->>VAC: Bloat reclaimed
```

## Transaction Control Flow

```mermaid
flowchart TD
    START["Application calls BEGIN"]
    OPS["Execute SQL statements\nSELECT / INSERT / UPDATE / DELETE"]
    CHECK["Application checks for errors\n(constraint violation, deadlock, etc.)"]
    SP["SAVEPOINT sp1\n(optional partial checkpoint)"]
    RB_SP["ROLLBACK TO SAVEPOINT sp1\n(undo since savepoint, keep outer tx)"]
    COMMIT["COMMIT\nAll changes durable,\nvisible to other transactions"]
    ROLLBACK["ROLLBACK\nAll changes discarded\nas if they never happened"]

    START --> OPS
    OPS --> CHECK
    CHECK -->|"Error or explicit savepoint"| SP
    SP --> OPS
    SP --> RB_SP
    RB_SP --> OPS
    CHECK -->|"All OK"| COMMIT
    CHECK -->|"Fatal error"| ROLLBACK
```

## MVCC row visibility rules

| Condition | Visible? |
|-----------|---------|
| `xmin` committed AND `xmax` is NULL | Yes — row is live |
| `xmin` committed AND `xmax` committed AND `xmax` > snapshot | Yes — deleted after our snapshot |
| `xmin` committed AND `xmax` committed AND `xmax` <= snapshot | No — deleted before our snapshot |
| `xmin` in-progress (not yet committed) | No — row is not yet real |
| `xmin` aborted | No — row was never committed |

## Why VACUUM is necessary

MVCC never overwrites rows in place. An UPDATE creates a new row version (`xmin = current_xid`) and marks the old one dead (`xmax = current_xid`). Dead row versions accumulate — they cannot be reclaimed until no live transaction's snapshot could still need them. VACUUM finds and marks those dead tuples as free space for future inserts.

Without VACUUM (or autovacuum), tables grow indefinitely even if net row count is stable. This is called **table bloat**.

```sql
-- See dead tuple accumulation
SELECT relname, n_live_tup, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```
