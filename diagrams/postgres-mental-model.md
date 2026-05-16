# PostgreSQL Mental Model

A high-level map of the two main dimensions of PostgreSQL: the **logical object hierarchy** (what you store) and the **process/memory architecture** (how PostgreSQL runs).

## Logical Object Hierarchy

```mermaid
flowchart TD
    PG["PostgreSQL Server"]
    DB1["Database: app_db"]
    DB2["Database: analytics_db"]
    S1["Schema: public"]
    S2["Schema: auth"]
    S3["Schema: audit"]
    T1["Table: users"]
    T2["Table: orders"]
    T3["Table: sessions"]
    T4["Table: events"]
    R1["Rows"]
    C1["Columns: id, email, created_at"]
    C2["Columns: id, user_id, total"]
    TY1["Types: uuid, text, timestamptz"]
    TY2["Types: int, numeric, bool"]
    CN1["Constraints: PK, UNIQUE, NOT NULL"]
    CN2["Constraints: FK → users, CHECK"]

    PG --> DB1
    PG --> DB2
    DB1 --> S1
    DB1 --> S2
    DB1 --> S3
    S1 --> T1
    S1 --> T2
    S2 --> T3
    S3 --> T4
    T1 --> R1
    T1 --> C1
    T2 --> C2
    C1 --> TY1
    C1 --> CN1
    C2 --> TY2
    C2 --> CN2
```

## Process and Memory Architecture

```mermaid
flowchart TD
    CLI["psql / app client"]
    POOL["Connection Pool\npgBouncer / built-in"]
    POSTMASTER["Postmaster\n(listener process)"]
    BACKEND["Backend Process\n(one per connection)"]
    BGW["Background Workers\nautovacuum, walwriter\ncheckpointer, bgwriter"]

    SHMEM["Shared Memory"]
    SBUF["Shared Buffers\n(page cache)"]
    WAL["WAL Buffers\n(write-ahead log)"]
    LOCK["Lock Table"]

    STORAGE["Storage (disk)"]
    HEAP["Heap Files\n(table data pages)"]
    IXFILES["Index Files\n(B-tree, GIN, GiST…)"]
    WALFILES["WAL Segments"]
    PGDATA["$PGDATA directory"]

    CLI --> POOL
    POOL --> POSTMASTER
    POSTMASTER --> BACKEND
    POSTMASTER --> BGW

    BACKEND --> SHMEM
    BGW --> SHMEM

    SHMEM --> SBUF
    SHMEM --> WAL
    SHMEM --> LOCK

    SBUF --> STORAGE
    WAL --> WALFILES
    STORAGE --> HEAP
    STORAGE --> IXFILES
    HEAP --> PGDATA
    IXFILES --> PGDATA
    WALFILES --> PGDATA
```

## Key Takeaways

- Every client connection spawns one **backend process** — PostgreSQL is process-based, not thread-based.
- **Shared Buffers** is the main in-memory page cache; reads/writes go through it before touching disk.
- **WAL (Write-Ahead Log)** ensures durability: changes are logged before they are applied to heap files.
- **Schemas** are namespaces inside a database — they let you organize tables without creating separate databases.
- **Constraints** live on columns and tables, enforcing correctness at the storage layer regardless of the application.
