# Extension Selection and Risk Model

Level: Advanced

## One-line intuition
PostgreSQL extensions are a spectrum from pure-SQL safe wrappers to C code that runs inside the server process — and every extension you install is an availability and security bet whose odds you should understand before production deployment.

## Why this exists
PostgreSQL's extensibility is a superpower: pgvector, PostGIS, TimescaleDB, and dozens of others add capabilities that would require separate databases in other ecosystems. But extensions are not cost-free. A buggy C extension can segfault the backend process, crash the postmaster, or introduce security vulnerabilities. An unmaintained extension can block PostgreSQL major version upgrades for years. Evaluating extensions is an engineering discipline, not just a feature selection exercise.

## First-principles explanation

### Extension anatomy
An extension consists of:
- A **control file** (`.control`): metadata (name, version, requires, schema, trusted status)
- **SQL files** (`.sql`): DDL to create functions, types, operators, etc.
- Optional **C shared library** (`.so`/`.dll`): compiled code loaded into the server process
- Optional **Python/Perl/Tcl** scripts (for PL extensions)

```sql
-- blocked: Docker not accessible
-- Install an extension (creates its objects in the current database)
CREATE EXTENSION vector;       -- pgvector
CREATE EXTENSION pg_trgm;      -- trigram similarity
CREATE EXTENSION pgcrypto;     -- cryptographic functions

-- List installed extensions
SELECT extname, extversion FROM pg_extension;

-- Check what objects an extension owns
SELECT * FROM pg_depend WHERE classid = 'pg_extension'::regclass
    AND refobjid = (SELECT oid FROM pg_extension WHERE extname = 'vector');
```

### The trusted extension distinction (PostgreSQL 13+)
A **trusted extension** can be created by a non-superuser who has the `CREATE` privilege on the database. Marked in the `.control` file: `trusted = true`.

Trusted extensions contain only SQL/PL functions — no C code that could escape the SQL sandbox. Examples: `pg_trgm`, `citext`, `hstore`, `intarray`, `pgcrypto`.

Untrusted extensions require superuser. Examples: `postgres_fdw`, `file_fdw`, `pgstattuple`, `pg_buffercache`, `vector` (pgvector), `PostGIS`.

The trusted/untrusted distinction is a runtime security boundary: trust it, but verify by reading the control file.

### Risk dimensions

**1. C extension crash risk**
C extensions run in the same OS process as the backend. A C bug (buffer overflow, null pointer dereference, infinite loop) can:
- Crash the individual backend (connection lost, client sees error)
- Corrupt shared memory (all backends crash — cluster restart required)
- Cause data corruption in the worst case

Trusted SQL extensions cannot crash the server — they run in the SQL execution layer, not at the C level.

Risk mitigation:
- Pin to a specific extension version
- Test new versions on staging with load testing
- Monitor `pg_stat_activity` for backends that die unexpectedly after extension queries

**2. PostgreSQL version compatibility**
Extensions link against specific PostgreSQL internal APIs that change between major versions. An extension compiled for PG 15 cannot load in PG 16 — it must be recompiled and potentially updated.

Check before upgrade:
```sql
-- blocked: Docker not accessible
SELECT name, default_version, installed_version FROM pg_available_extensions
WHERE installed_version IS NOT NULL;
```

Verify each installed extension has a compatible version for the target PostgreSQL version before upgrading.

**3. Maintenance and support lifecycle**
Evaluate:
- Last commit date on the extension's repository
- Number of open bug reports
- PostgreSQL version support matrix in the README
- Vendor support (commercial) vs community support
- Number of production deployments (GitHub stars, mentions in prod postmortems)

Extensions maintained by major vendors (Timescale for TimescaleDB, Citus Data for pg_partman, pgvector by its maintainer with active community) have lower abandonment risk than single-developer extensions.

**4. Schema and data coupling**
Once installed, an extension's types are embedded in your tables. Removing it requires:
```sql
-- blocked: Docker not accessible
-- This fails if any table uses the extension's types
DROP EXTENSION vector;
-- Must drop all vector columns first:
ALTER TABLE documents DROP COLUMN embedding;
DROP EXTENSION vector;
```

Extensions that add custom types (PostGIS geometry, pgvector vector) create stronger schema coupling than extensions that add only functions.

**5. Upgrade path**
```sql
-- blocked: Docker not accessible
-- Upgrade extension in-place (if upgrade scripts exist)
ALTER EXTENSION vector UPDATE TO '0.7.0';
-- Check available upgrade paths
SELECT * FROM pg_extension_updates('vector');
```

Missing upgrade scripts require reinstall (DROP + CREATE EXTENSION), which requires dropping all objects that use the extension's types.

### Extension evaluation checklist
Before adding an extension to production:

| Criterion | Questions |
|---|---|
| License | Is it open-source? Permissive (MIT/Apache) or copyleft (GPL)? Commercial license terms? |
| Maintenance | Last release date? Active issue response? Multiple contributors? |
| PG version support | Does it support your current and target PG version? |
| C code? | Is it trusted? Does it have known CVEs? Has it been audited? |
| Type coupling | Does it introduce custom types into your tables? |
| Upgrade path | Are ALTER EXTENSION UPDATE scripts available for all version transitions? |
| Production proof | Is it used in production at similar scale? Case studies? |
| Performance impact | Does enabling it affect all queries (e.g., shared_preload_libraries) or only explicit usage? |
| Rollback plan | Can you remove it without data migration? |

### Extensions available in this environment
Available: `vector` (pgvector), `pgcrypto`, `pg_trgm`, `ltree`, `pg_buffercache`, `pageinspect`
Not available: `pg_cron`, `timescaledb`, `postgis`, `pgaudit`, `pg_partman`

For each available extension, risk profile:
- **vector**: C extension, actively maintained, MIT license, production-proven. Risk: C crash risk, type coupling (vector columns), HNSW build memory.
- **pgcrypto**: C extension, shipped with PostgreSQL contrib. Low risk — small, stable, long history. Risk: key management is application responsibility.
- **pg_trgm**: C extension, PostgreSQL contrib. Very low risk — core PostgreSQL team. Trusted in PG 13+.
- **pg_buffercache**: C extension, PostgreSQL contrib. Low risk. Read-only view of shared buffers.
- **pageinspect**: C extension, superuser only. Risk: can reveal internal page structure; security risk if exposed to untrusted users. For diagnostics only.
- **ltree**: C extension, PostgreSQL contrib. Low risk. Stable, long history.

## Micro-concepts
- **contrib**: PostgreSQL's bundled extension collection. Shipped with the server, maintained by the core team. Generally low risk.
- **`shared_preload_libraries`**: some extensions (pg_stat_statements, auto_explain, timescaledb) must be preloaded at server startup. Requires restart to add/remove.
- **`CREATE EXTENSION IF NOT EXISTS`**: idempotent creation — safe to include in deployment scripts.
- **extension versioning**: specified in `default_version` (in .control file). Installed version tracked in `pg_extension.extversion`.
- **`pg_available_extensions`**: lists all extensions available in the cluster's extension directory (installed on the OS, not yet in the database).
- **dump/restore behavior**: `pg_dump` includes `CREATE EXTENSION` statements. The extension binary must be installed on the target system before restore.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: Install extensions with `CREATE EXTENSION`. Common ones (pg_trgm, pgcrypto) are safe and widely used.

**Intermediate view**: C extensions can crash the server. Trusted extensions are safer for non-superuser. Check PostgreSQL version compatibility before upgrading. Don't install extensions you don't use.

**Advanced view**: Each C extension is a shared library loaded into every backend process. A memory safety bug affects the entire cluster. Production extension governance should include: a registry of installed extensions with versions and owners, a process for approving new extensions (security review + compatibility testing), a changelog of extension upgrades, and a rollback playbook for each extension. For SOC 2 / ISO 27001 compliance, third-party C code in the database process requires vendor security questionnaires.

## Mental model
Extensions are plugins loaded into the database engine. Pure SQL extensions are like changing the engine's oil — low risk, entirely within expected parameters. C extensions are like installing third-party ECU software — it can unlock new capabilities, but a bug in the code can shut down the whole engine while driving. The more popular and well-maintained the extension, the more road-tested the code is.

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_extension`, `pg_available_extensions`, `pg_available_extension_versions`.

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Installed extensions with versions
SELECT extname, extversion, extrelocatable
FROM pg_extension
ORDER BY extname;

-- Available (not yet installed) extensions
SELECT name, default_version, comment
FROM pg_available_extensions
WHERE installed_version IS NULL
ORDER BY name;

-- Check if an extension is trusted
SELECT name, trusted FROM pg_available_extensions WHERE name = 'pg_trgm';
```

**Non-SQL / hybrid view**: `apt show postgresql-16-pgvector` (Debian/Ubuntu) or `pg_config --sharedir` to find the extension directory. PGXN (https://pgxn.org/) is the PostgreSQL extension network — a searchable registry.

## Design principle
**Treat extensions as third-party dependencies with the same rigor as application libraries**: Version pin them, audit them, test them, have a plan to remove them. The difference from application libraries: a broken C extension can crash the database process, not just the application.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: The `shared_preload_libraries` requirement for some extensions (like pg_stat_statements, auto_explain, timescaledb) means they cannot be added or removed without a server restart. Restarting a production PostgreSQL server has downtime implications. Always check if a new extension requires `shared_preload_libraries` before planning a deployment.

**Creative**: Build an extension governance database: a table that tracks extension name, version, installation date, purpose, owner team, last security review date, and upgrade plan. Query this before major PostgreSQL version upgrades to get a complete compatibility checklist automatically.

**Systems**: Extension upgrades in a cluster with physical replication replicate the C library loading side-effect. When you `ALTER EXTENSION` on the primary, the DDL replicates to replicas, but the binary must be installed on replica OS first. Extension upgrades in replicated clusters require: (1) install new extension binary on all replicas, (2) install on primary, (3) ALTER EXTENSION on primary, (4) replication applies the DDL on replicas (which now have the binary). Order matters — if the binary is missing on a replica when DDL replicates, the replica crashes.

## MCP and agent perspective
For AI agent infrastructure, the minimum viable extension set is: `vector` (semantic search), `pgcrypto` (agent secret storage), `pg_trgm` (fuzzy matching), and `pg_stat_statements` (observability). Resist adding extensions for every new capability — each C extension is a dependency on an external software project. The agent system's reliability is bounded by the least-reliable extension it depends on.

## Ontology perspective
Extensions embody the open-closed principle at the database level: PostgreSQL's core is stable and well-tested (closed for modification), while the extension API allows new capabilities to be added without touching the core (open for extension). The risk model mirrors software dependency management: the more code you depend on, the more failure modes exist. The trusted/untrusted extension boundary is an ontological boundary between the SQL-safe sandbox and the native C execution environment.

## Practice session

**Exercise 1 — Inventory installed extensions**:
```sql
-- blocked: Docker not accessible
SELECT extname, extversion,
       (SELECT trusted FROM pg_available_extensions WHERE name = extname) AS is_trusted
FROM pg_extension
ORDER BY extname;
```

**Exercise 2 — Check available upgrades**:
```sql
-- blocked: Docker not accessible
SELECT name, installed_version, default_version,
       installed_version <> default_version AS upgrade_available
FROM pg_available_extensions
WHERE installed_version IS NOT NULL;
```

**Exercise 3 — Find extension object ownership**: What does pgcrypto own?
```sql
-- blocked: Docker not accessible
SELECT c.relname, c.relkind FROM pg_class c
JOIN pg_depend d ON d.objid = c.oid
WHERE d.refobjid = (SELECT oid FROM pg_extension WHERE extname = 'pgcrypto')
  AND d.deptype = 'e';
```

**Exercise 4 — Check shared_preload requirement**: Does an extension need preloading?
```sql
-- blocked: Docker not accessible
SHOW shared_preload_libraries;
-- pg_stat_statements should appear if installed
-- timescaledb must appear before it functions
```

**Exercise 5 — Safe extension removal**: Drop objects first.
```sql
-- blocked: Docker not accessible
-- Example: remove pgcrypto safely
-- First: find all functions using pgcrypto types (manual check)
-- Then: DROP EXTENSION pgcrypto CASCADE;  -- CASCADE drops dependent objects
-- WARNING: CASCADE is destructive — audit dependencies first
```

## References
- PostgreSQL Documentation: [Packaging Related Objects into an Extension](https://www.postgresql.org/docs/16/extend-extensions.html)
- PostgreSQL Documentation: [CREATE EXTENSION](https://www.postgresql.org/docs/16/sql-createextension.html)
- PostgreSQL Documentation: [Trusted Extensions](https://www.postgresql.org/docs/16/sql-createextension.html#id-1.9.3.55.6)
- PGXN — PostgreSQL Extension Network: https://pgxn.org/
- PostgreSQL contrib extensions: https://www.postgresql.org/docs/16/contrib.html
- Álvaro Herrera: [Extension infrastructure](https://www.postgresql.org/docs/16/extend-extensions.html)
