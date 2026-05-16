# References: Simple Transactions

Topic-specific references for this practice session.

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|-----------|
| PostgreSQL docs — Transactions tutorial | https://www.postgresql.org/docs/current/tutorial-transactions.html | Official docs | Beginner | 10 min | Beginner overview of BEGIN/COMMIT/ROLLBACK |
| PostgreSQL docs — Transaction Isolation | https://www.postgresql.org/docs/current/transaction-iso.html | Official docs | Intermediate | 20 min | Isolation levels with anomaly table |
| PostgreSQL docs — SAVEPOINT | https://www.postgresql.org/docs/current/sql-savepoint.html | Official docs | Beginner | 5 min | SAVEPOINT, ROLLBACK TO, RELEASE syntax |
| PostgreSQL docs — MVCC | https://www.postgresql.org/docs/current/mvcc-intro.html | Official docs | Intermediate | 15 min | How PostgreSQL implements isolation |
| PostgreSQL docs — WAL | https://www.postgresql.org/docs/current/wal-intro.html | Official docs | Intermediate | 15 min | How durability is implemented |
| PostgreSQL docs — pg_stat_activity | https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW | Official docs | Beginner | 5 min | Diagnosing idle-in-transaction sessions |
| SQLBolt — No transaction lesson yet | — | — | — | — | SQLBolt does not cover transactions; use the PostgreSQL tutorial above |

---

## Further reading

After completing this practice session, continue with:

- `concepts/beginner/14-jsonb-as-flexible-data.md` — using JSONB inside transactions
- `concepts/beginner/16-roles-and-permissions.md` — which roles can BEGIN/COMMIT/ROLLBACK
- `concepts/intermediate/` (future) — SELECT FOR UPDATE, advisory locks, deadlock detection

---

## Reference quality note

All references in this file are free to access (official PostgreSQL documentation).
