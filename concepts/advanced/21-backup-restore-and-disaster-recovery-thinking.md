# Backup, Restore, and Disaster Recovery Thinking

Level: Advanced

## One-line intuition
A backup that has never been successfully restored is not a backup — and understanding the spectrum from pg_dump to PITR to pgBackRest is understanding the spectrum from "we have a file" to "we can recover to any minute in the last 30 days in under an hour."

## Why this exists
Every PostgreSQL deployment will eventually face data loss, corruption, or catastrophic failure. The question is not whether, but when — and whether you have tested your recovery procedures before the incident happens. Backup architecture determines RTO (how long until you're back online) and RPO (how much data you lose). These are business commitments, and they require specific technical implementation to deliver.

## First-principles explanation

### Backup types

**Logical backup (pg_dump)**: exports schema and data as SQL or custom format.
```bash
# Full database dump (custom format — best for pg_restore)
# blocked: Docker not accessible
# pg_dump -Fc -d mydb -f mydb_backup.dump
# pg_dump -s -d mydb -f schema.sql         # schema only
# pg_restore -d newdb mydb_backup.dump     # restore
```

Characteristics:
- Portable across PostgreSQL major versions
- Selective (specific tables, schemas)
- Slow for large databases
- Point-in-time consistency (single transaction snapshot)
- Cannot do PITR (no WAL)

**Physical backup (pg_basebackup)**: copies the entire PGDATA directory at the file level.
```bash
# blocked: Docker not accessible
# pg_basebackup -h primary -U replication_user -D /backup/base -Ft -Xs -P
# -Ft: tar format; -Xs: stream WAL during backup; -P: progress
```

Characteristics:
- Must restore to the same PostgreSQL major version
- Entire cluster backup (all databases)
- Much faster than pg_dump for large databases
- Foundation for PITR (WAL archiving builds on top)

### WAL archiving
WAL segments (16MB each) are continuously generated. Archive them to enable PITR:
```conf
# postgresql.conf
archive_mode = on
archive_command = 'rsync %p /backup/wal/%f'
wal_level = replica   # minimum for archiving
```

```sql
-- blocked: Docker not accessible
-- Verify archiving is working
SELECT last_archived_wal, last_archived_time, last_failed_wal
FROM pg_stat_archiver;
```

### PITR — Point-In-Time Recovery
Starting from a base backup, replay WAL up to a specific time:

```conf
# postgresql.conf (PG 12+)
restore_command = 'rsync /backup/wal/%f %p'
recovery_target_time = '2024-01-15 03:30:00'
recovery_target_action = promote
```

Recovery process:
1. Stop PostgreSQL
2. Extract base backup to PGDATA
3. Configure `recovery_target_time` in postgresql.conf
4. Create `recovery.signal` file (PG 12+)
5. Start PostgreSQL — it replays WAL until the target time
6. Verify data, promote to read-write mode

### RTO vs RPO

**RPO (Recovery Point Objective)**: maximum data loss tolerable.
- pg_dump only: RPO = time since last dump (could be 24h)
- WAL archiving (every 16MB or 5 min): RPO ≤ 5 minutes
- Streaming replication: RPO ≈ replication lag (seconds)

**RTO (Recovery Time Objective)**: maximum time to restore service.
- pg_dump restore: hours for 1TB
- Physical backup + WAL replay: transfer time + WAL replay time
- Streaming replica failover: < 1 minute

### pgBackRest — production backup tool
pgBackRest provides:
- Incremental and differential backups (copy only changed blocks)
- Parallel backup and restore (multiple worker threads)
- Backup verification (checksums on all files)
- Repository encryption at rest
- Retention policy management
- Standby backup (take backup from replica, not primary)

```bash
# blocked: Docker not accessible
# pgbackrest --stanza=db backup --type=full
# pgbackrest --stanza=db backup --type=incr
# pgbackrest --stanza=db restore --target='2024-01-15 03:30:00' --type=time
# pgbackrest --stanza=db check
```

### Testing restores — the most critical practice
A backup is only valid if a restore has been tested:
1. Take a fresh base backup (or use latest pgBackRest backup)
2. Restore to an isolated server (not production)
3. Verify PostgreSQL starts successfully
4. Run integrity checks: critical table row counts match
5. Time the restore — verify it meets RTO
6. Document: what backup, restored when, how long, what was verified

Automate: run weekly restore tests to a CI/staging environment.

### Backup monitoring
```sql
-- blocked: Docker not accessible
SELECT last_archived_wal, last_archived_time,
       now() - last_archived_time AS archive_age,
       last_failed_wal
FROM pg_stat_archiver;
-- Alert if archive_age > 10 minutes
```

## Micro-concepts
- **PGDATA**: the root data directory. pg_basebackup copies this entire directory.
- **WAL segment**: 16MB file. Named by LSN. Archived and replayed for PITR.
- **recovery.signal**: creating this empty file in PGDATA triggers PostgreSQL to enter recovery mode on startup (PG 12+).
- **`recovery_target_inclusive`**: whether to include transactions at exactly the target time (default true).
- **WAL-G**: lightweight cloud-native WAL archiving tool (alternative to custom archive_command).
- **pg_dumpall**: like pg_dump but for the entire cluster including roles and tablespaces.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: pg_dump creates a backup file. pg_restore loads it. Do this regularly.

**Intermediate view**: For large databases, use physical backup (pg_basebackup) + WAL archiving for PITR. Test restores. Know your RPO and RTO.

**Advanced view**: Backup architecture is a layered system: base backup (PITR foundation) + WAL archive (continuity between base backups) + streaming replica (near-zero RPO operational failover). All three layers are needed in production. pgBackRest manages base backup + WAL archive with encryption, retention, and verification. Testing restores weekly closes the feedback loop. RTO and RPO must be negotiated with stakeholders and verified technically — not assumed.

## Mental model
Backup architecture is a time machine with three modes:
- **pg_dump**: a photograph taken at one moment. Can reconstruct exactly that moment.
- **WAL archiving**: a time-lapse video from the photograph forward. Can seek to any frame (any minute) between base backup and now.
- **Streaming replica**: a live mirror playing in real-time. Can switch to it in seconds.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_stat_archiver`, `pg_stat_wal`, `pg_control_checkpoint()`.

**SQL view**:
```sql
-- blocked: Docker not accessible
-- WAL archiver status
SELECT archived_count, failed_count, last_archived_wal, last_failed_wal,
       now() - last_archived_time AS archive_age
FROM pg_stat_archiver;

-- Current WAL position
SELECT pg_current_wal_lsn(), pg_walfile_name(pg_current_wal_lsn());

-- Checkpoint info
SELECT checkpoint_lsn, checkpoint_time FROM pg_control_checkpoint();

-- Database sizes (helps estimate backup transfer time)
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database ORDER BY pg_database_size(datname) DESC;
```

**Non-SQL / hybrid view**: pgBackRest (https://pgbackrest.org/), Barman (https://www.pgbarman.org/), WAL-G (https://github.com/wal-g/wal-g).

## Design principle
**RPO and RTO are the specification; backup architecture is the implementation**: Define RPO and RTO first (business conversation), then design the architecture that delivers them. For most SaaS: RPO = 5 minutes (WAL archiving), RTO = 30 minutes (pg_basebackup + PITR). This requires: archiving WAL every 5 minutes, base backups nightly, PITR testing monthly.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: WAL archiving can silently fail. The `archive_command` exits 0 (success) even if remote storage is temporarily unavailable. Always monitor `pg_stat_archiver.last_failed_wal` and `archive_age`. An archiver that hasn't archived in 10 minutes is a crisis most teams discover only when they need the WAL.

**Creative**: Run a "chaos recovery" test quarterly: restore from backup to a new instance, change a known value, verify it is changed. This tests that the restored data is meaningful — different from just "PostgreSQL starts."

**Systems**: Backup strategy integrates with the full reliability architecture: streaming replication → operational failover (seconds); WAL archiving + base backup → PITR (RPO/RTO); pg_dump → logical portability (cross-version, selective). A cluster with streaming replication but no WAL archiving has no PITR capability — a corrupted primary and its replica both lose the corrupted data.

## MCP and agent perspective
Agent systems need their own backup consideration: agent memory (embeddings, episodic log) may need different RPO than the main application database. If agent memory loss is acceptable (agents can rebuild from conversation history), use lower-frequency backup. If agent memory is critical (persistent agent identity, learned preferences), apply the same WAL archiving + PITR discipline. Always include agent tables in restore tests — verify restored embeddings produce correct nearest-neighbor results.

## Ontology perspective
Backup and recovery are mechanisms for temporal identity preservation: the database has an identity over time, and backups preserve the evidence needed to reconstruct that identity at any past moment. PITR is the strongest form — it can reconstruct the database's exact state at any instant within the retention window. Without PITR, the database's temporal identity is quantized to discrete backup moments. The retention window is the database's temporal memory: everything within it is recoverable; everything before it is gone.

## Practice session

**Exercise 1 — Check WAL archiver**:
```sql
-- blocked: Docker not accessible
SELECT last_archived_wal, last_archived_time, last_failed_wal,
       now() - last_archived_time AS archive_age
FROM pg_stat_archiver;
```

**Exercise 2 — Database size estimate**: Calculate backup transfer time.
```sql
-- blocked: Docker not accessible
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS db_size
FROM pg_database ORDER BY pg_database_size(datname) DESC;
```

**Exercise 3 — Current WAL position**:
```sql
-- blocked: Docker not accessible
SELECT pg_current_wal_lsn(), pg_walfile_name(pg_current_wal_lsn());
```

**Exercise 4 — Checkpoint gap**: How much WAL since last checkpoint?
```sql
-- blocked: Docker not accessible
SELECT checkpoint_lsn, checkpoint_time,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), checkpoint_lsn)) AS wal_since_checkpoint
FROM pg_control_checkpoint();
```

**Exercise 5 — Restore verification query**: Compare row counts before/after.
```sql
-- blocked: Docker not accessible
-- Run before backup and after restore:
SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC;
```

## References
- PostgreSQL Documentation: [Backup and Restore](https://www.postgresql.org/docs/16/backup.html)
- PostgreSQL Documentation: [pg_dump](https://www.postgresql.org/docs/16/app-pgdump.html)
- PostgreSQL Documentation: [pg_basebackup](https://www.postgresql.org/docs/16/app-pgbasebackup.html)
- PostgreSQL Documentation: [Continuous Archiving and PITR](https://www.postgresql.org/docs/16/continuous-archiving.html)
- pgBackRest: https://pgbackrest.org/user-guide.html
- WAL-G: https://github.com/wal-g/wal-g
- Barman: https://www.pgbarman.org/
