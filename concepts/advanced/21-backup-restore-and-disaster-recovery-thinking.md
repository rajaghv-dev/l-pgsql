# Backup, Restore, and Disaster Recovery Thinking

Level: Advanced
PostgreSQL 16 | Container: `docker exec cfp_postgres psql -U cfp -d cfp`

## One-line intuition
The only backup that matters is a tested restore — unverified backups are wishful thinking.

## Why this exists
Data loss is catastrophic and irreversible. Every production PostgreSQL deployment needs a documented backup strategy with tested recovery procedures, clear RTO (recovery time objective) and RPO (recovery point objective) targets, and a restore runbook that someone has actually executed.

## First-principles explanation
PostgreSQL provides two primary backup mechanisms: logical (pg_dump — portable, per-database, SQL-level) and physical (pg_basebackup — file-level copy of the entire cluster). WAL archiving enables point-in-time recovery (PITR) by replaying WAL segments after a physical backup. The choice between logical and physical backup depends on size, recovery granularity, and RTO requirements.

## Micro-concepts
- **pg_dump**: logical backup — exports SQL for a single database; portable across versions; suitable for small-to-medium databases
- **pg_basebackup**: physical backup — copies the entire data directory; faster for large databases; requires same PostgreSQL version for restore
- **WAL archiving**: continuous WAL shipping enables PITR; combined with pg_basebackup for full recovery capability
- **RTO**: Recovery Time Objective — maximum acceptable downtime (how fast must you recover?)
- **RPO**: Recovery Point Objective — maximum acceptable data loss (how much data can you afford to lose?)

## Beginner view
Use pg_dump for small databases. Schedule it regularly. Store backups off-site. Test restoring periodically.

## Intermediate view
pg_dump is too slow for large databases. Use pg_basebackup + WAL archiving for large production databases. Understand the difference between crash recovery (automatic) and point-in-time recovery (manual).

## Advanced view
Design backup strategy around RTO and RPO targets. pgBackRest provides incremental backups, parallel backup/restore, compression, and encryption. Tablespace-aware backups. Streaming replication as a warm standby complements (but does not replace) backups.

## Mental model
Three concentric circles: crash recovery (automatic, always on), PITR (physical backup + WAL, minutes of RPO), restore from backup (logical or physical, hours of RPO). Each circle has a cost in complexity and RTO.

## PostgreSQL view
```sql
-- blocked: Docker not accessible; validate against cfp_postgres when available

-- Check WAL archiving status
SELECT archived_count, failed_count, last_archived_wal, last_failed_wal
FROM pg_stat_archiver;

-- Check current WAL LSN position
SELECT pg_current_wal_lsn(), pg_walfile_name(pg_current_wal_lsn());

-- Estimate pg_dump size
SELECT pg_size_pretty(pg_database_size('cfp'));
```

## SQL view
```sql
-- blocked: Docker not accessible

-- Logical backup (run on host, not in psql)
-- pg_dump -U cfp -d cfp -F c -f cfp_backup.dump

-- Logical restore
-- pg_restore -U cfp -d cfp_new cfp_backup.dump

-- Physical backup (run on host)
-- pg_basebackup -U cfp -D /backup/cfp_base -Ft -z -P
```

## Non-SQL or hybrid view
pgBackRest provides: incremental backups (only changed files), parallel backup, S3/GCS storage, backup verification, and automated restore testing. It is the recommended tool for production PostgreSQL backup.

## Design principle
**Test your restore**: schedule a monthly restore drill to a staging environment. If you cannot restore from backup in your target RTO, your backup strategy is incomplete regardless of how many backups you have.

## Critical thinking
When would streaming replication NOT protect you from a data loss event? (DROP TABLE accidentally, logical corruption, WAL segment loss between primary and replica.)

## Creative thinking
How would you design a self-testing backup system that automatically verifies each backup is restorable?

## Systems thinking
How does WAL archiving interact with replication? (Primary archives WAL, replica streams it — archive is the safety net for gaps in the stream.)

## MCP and agent perspective
- Agents must NEVER have privileges to delete WAL files, drop databases, or access backup storage
- Backup schedules should be immutable from the agent perspective
- If an agent accidentally drops a table, PITR to just before the drop is the recovery path

## Ontology perspective
[[transaction-ontology]] [[observability-ontology]] [[performance-ontology]]

## References
- [pg_dump](https://www.postgresql.org/docs/16/app-pgdump.html) — official docs
- [pg_basebackup](https://www.postgresql.org/docs/16/app-pgbasebackup.html) — physical backup
- [Continuous Archiving and PITR](https://www.postgresql.org/docs/16/continuous-archiving.html) — WAL archiving guide
- [pgBackRest](https://pgbackrest.org) — production backup tool
