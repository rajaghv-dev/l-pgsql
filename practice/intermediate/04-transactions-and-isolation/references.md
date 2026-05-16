# References — Transactions and Isolation Levels

## PostgreSQL official documentation
- Transaction Isolation: https://www.postgresql.org/docs/16/transaction-iso.html
- BEGIN: https://www.postgresql.org/docs/16/sql-begin.html
- SET TRANSACTION: https://www.postgresql.org/docs/16/sql-set-transaction.html
- SAVEPOINT: https://www.postgresql.org/docs/16/sql-savepoint.html
- ROLLBACK TO SAVEPOINT: https://www.postgresql.org/docs/16/sql-rollback-to.html

## Papers and books
- Hal Berenson et al., "A Critique of ANSI SQL Isolation Levels" (SIGMOD 1995) — defines the anomalies precisely
- Michael J. Cahill et al., "Serializable Isolation for Snapshot Databases" (SIGMOD 2008) — SSI algorithm used in PostgreSQL
- Martin Kleppmann, *Designing Data-Intensive Applications*, Chapter 7 (O'Reilly) — best accessible explanation of transaction semantics

## Blog posts
- Bruce Momjian, "Serializable Snapshot Isolation in PostgreSQL": https://www.pgcon.org/2012/schedule/attachments/228_ssi.pdf
- Brandur Leach, "Serializable Transactions in PostgreSQL": https://brandur.org/postgres-transactions
- Cybertec, "PostgreSQL Transactions — Under the Hood": https://www.cybertec-postgresql.com/en/transactions-in-postgresql-under-the-hood/

## Related concepts in this repo
- `concepts/intermediate/08-mvcc-and-snapshot-thinking.md` — the MVCC mechanism that implements snapshots
- `concepts/intermediate/09-locks-and-concurrency.md` — row-level locks used within transactions
- `practice/intermediate/05-mvcc-and-locking/` — hands-on lock and MVCC exercises
