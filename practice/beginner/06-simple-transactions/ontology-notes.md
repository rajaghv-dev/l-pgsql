# Ontology Notes: Simple Transactions

These notes map the concepts in this practice session to the broader PostgreSQL concept graph.

---

## Concept map

```
transaction
  ├── IS A: unit of work (atomic change to the database)
  ├── BOUNDED BY: BEGIN → COMMIT or ROLLBACK
  ├── IMPLEMENTS: ACID properties
  │     ├── Atomicity   — all or nothing
  │     ├── Consistency — constraints enforced before commit
  │     ├── Isolation   — concurrent transactions do not interfere
  │     └── Durability  — committed data survives crashes (WAL)
  ├── HAS: savepoints (named rollback points within a transaction)
  │     └── SAVEPOINT name → ROLLBACK TO name → RELEASE name
  ├── USES: WAL (Write-Ahead Log) for durability
  ├── GOVERNED BY: isolation level (READ COMMITTED, REPEATABLE READ, SERIALIZABLE)
  └── IMPLEMENTED BY: MVCC (Multi-Version Concurrency Control)

auto-commit
  ├── IS: default mode — every statement is its own transaction
  └── CONTRASTS WITH: explicit transaction (BEGIN ... COMMIT)
```

---

## Concept definitions

| Concept | Definition | Parent concept | Child concepts |
|---------|-----------|----------------|----------------|
| transaction | A group of SQL statements that execute atomically | unit of work | ACID, COMMIT, ROLLBACK, SAVEPOINT |
| atomicity | All statements in a transaction succeed or all are undone | ACID | — |
| COMMIT | Make all transaction changes permanent | transaction | — |
| ROLLBACK | Undo all changes since BEGIN | transaction | ROLLBACK TO SAVEPOINT |
| SAVEPOINT | Named point within a transaction for partial rollback | transaction | ROLLBACK TO, RELEASE |
| auto-commit | Each statement implicitly wrapped in its own transaction | default mode | — |
| MVCC | Mechanism allowing concurrent reads without blocking writers | isolation | — |
| READ COMMITTED | Isolation level: see only committed data; each statement sees freshest snapshot | isolation level | — |
| WAL | Write-Ahead Log: changes logged before table pages for crash recovery | durability | — |

---

## Key relationships

- **COMMIT IS A** decision point — makes tentative changes permanent.
- **ROLLBACK IS A** undo operation — restores database to pre-BEGIN state.
- **SAVEPOINT REQUIRES** an open transaction (BEGIN must precede it).
- **SAVEPOINT ENABLES** partial rollback without aborting the entire transaction.
- **AUTO-COMMIT CONTRASTS WITH** explicit BEGIN — auto-commit wraps one statement; explicit wraps many.
- **MVCC IMPLEMENTS** isolation — it keeps multiple row versions so readers do not block writers.
- **WAL IMPLEMENTS** durability — changes are logged before being written to the main table files.
- **CHECK constraint INTERACTS WITH** transactions — a violated CHECK aborts the transaction automatically.

---

## Obsidian graph links

- `[[transaction]]`
- `[[atomicity]]`
- `[[acid]]`
- `[[commit]]`
- `[[rollback]]`
- `[[savepoint]]`
- `[[auto-commit]]`
- `[[mvcc]]`
- `[[wal]]`
- `[[isolation-level]]`
- `[[read-committed]]`
- `[[constraint]]`

---

## Questions for deeper concept mapping

1. Is MVCC a type of transaction? (No — MVCC is the implementation mechanism that enables transaction isolation. They are at different conceptual levels.)
2. What concept is logically upstream of a transaction? (The write operation — transactions exist because writes need to be grouped and made atomic.)
3. What concepts does transaction isolation make possible downstream? (Safe concurrent writes, consistent reads, conflict detection in SERIALIZABLE mode.)
