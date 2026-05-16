# Practice: MVCC and Locking

**Stage:** 9 — Transactions, MVCC, Locks
**Concept files:** `concepts/intermediate/08-mvcc-and-snapshot-thinking.md`, `concepts/intermediate/09-locks-and-concurrency.md`
**Level:** Intermediate

## Goal
Observe MVCC internals (xmin/xmax, dead tuples, vacuum) and practice lock inspection, deadlock reproduction, and the SKIP LOCKED queue pattern.

## Schema overview
- `job_queue` — a task queue table used to demonstrate SKIP LOCKED
- `accounts` — a simple account table used to show lock contention and deadlocks
- Uses `pageinspect` extension to inspect raw tuple headers

## Files
| File | Purpose |
|---|---|
| `setup.sql` | Create tables, extensions, seed data |
| `00-setup-validation.md` | Confirm pageinspect and tables are ready |
| `exercises.md` | Step-by-step exercises |
| `solutions.md` | Expected outputs and explanations |
| `reflection.md` | Deeper questions and takeaways |
| `ontology-notes.md` | Ontology framing for MVCC and locks |
| `troubleshooting.md` | Common errors and fixes |
| `references.md` | Links and further reading |

## Prerequisites
- Completed Practice 04 (Transactions and Isolation)
- Two terminal sessions available for concurrent exercises

## Docker note
All SQL in this folder is blocked: Docker not accessible in this session.
Expected connection: `docker exec cfp_postgres psql -U cfp -d cfp`
