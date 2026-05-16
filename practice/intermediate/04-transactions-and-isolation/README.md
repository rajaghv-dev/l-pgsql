# Practice: Transactions and Isolation Levels

**Stage:** 9 — Transactions, MVCC, Locks
**Concept file:** `concepts/intermediate/07-transactions-and-isolation.md`
**Level:** Intermediate

## Goal
Understand how PostgreSQL isolation levels affect concurrent behavior by running experiments that surface phantom reads, non-repeatable reads, and serialization anomalies in a banking schema.

## Schema overview
A `bank_accounts` table with balances, and a `transfers` table that records movements between accounts. Exercises use two concurrent sessions to observe isolation behavior.

## Files
| File | Purpose |
|---|---|
| `setup.sql` | Create tables and seed data |
| `00-setup-validation.md` | Confirm setup is correct |
| `exercises.md` | Step-by-step exercises |
| `solutions.md` | Expected outputs and explanations |
| `reflection.md` | Deeper questions and takeaways |
| `ontology-notes.md` | Ontology framing for transactions |
| `troubleshooting.md` | Common errors and fixes |
| `references.md` | Links and further reading |

## Prerequisites
- Completed Stage 8 (indexes and query planning)
- Familiarity with SQL transactions (BEGIN/COMMIT/ROLLBACK)
- Two terminal sessions available to simulate concurrent access

## Docker note
All SQL in this folder is blocked: Docker not accessible in this session.
Expected connection: `docker exec cfp_postgres psql -U cfp -d cfp`
