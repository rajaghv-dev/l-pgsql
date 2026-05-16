# Buffer Cache and IO Thinking

Level: Advanced

## One-line intuition
Every query in PostgreSQL either gets its data from shared_buffers (fast), from the OS page cache (medium), or from disk (slow) — and the ratio between these determines whether your database feels instant or agonizing.

## Why this exists
IO is the most common bottleneck in PostgreSQL. Queries that hit shared buffers run in microseconds; queries that wait for disk reads run in milliseconds. Understanding the buffer cache — how it works, how to measure its effectiveness, and how to reason about its interactions with the OS page cache — is the foundation for IO-based performance work.

## First-principles explanation

### The three layers of IO
```
Query asks for page X
  1. Check shared_buffers (PostgreSQL buffer pool)
     → HIT: return from RAM in ~1 microsecond
  2. Check OS page cache (kernel buffer cache)
     → HIT: copy to shared_buffers, return in ~10-50 microseconds
  3. Read from disk (SSD or HDD)
     → SSD: ~100-500 microseconds
     → HDD: ~5-10 milliseconds
```

PostgreSQL deliberately uses OS-level paging too (unlike Oracle which bypasses the OS with direct IO). This means pages may reside in both shared_buffers AND the OS page cache simultaneously — **double buffering**. The benefit: the OS handles additional caching for free. The cost: memory is used twice for the same data; less RAM available for other processes.

### shared_buffers
The PostgreSQL buffer pool. Each buffer is exactly one page (8KB by default). All backends share this pool. The buffer replacement algorithm is a variant of clock (not strict LRU) with "usage count" — hot pages are more resistant to eviction.

Typical sizing:
- Dedicated PostgreSQL server: 25% of RAM (e.g., 8GB on a 32GB server)
- Shared server: 10-15% of RAM
- Changing requires restart

### effective_cache_size
**Not actual memory** — a hint to the planner about the total RAM available for caching (shared_buffers + OS page cache). The planner uses this to decide if an index scan is likely to be cache-resident (cheap) or disk-bound (expensive).

Setting too low → planner avoids index scans unnecessarily.
Setting too high → planner assumes everything is cached, then is wrong.

Rule of thumb: `effective_cache_size = shared_buffers + (available OS RAM × 0.7)`.

On a 32GB server with 8GB shared_buffers and 20GB free OS RAM:
`effective_cache_size = 8GB + 14GB = 22GB`

### Cache hit rate
```sql
-- blocked: Docker not accessible
SELECT
    sum(heap_blks_hit) AS heap_hits,
    sum(heap_blks_read) AS heap_reads,
    round(
        sum(heap_blks_hit)::numeric /
        nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0) * 100, 2
    ) AS hit_rate_pct
FROM pg_statio_user_tables;
```

Healthy hit rate: > 95% for OLTP. < 90% indicates working set exceeds shared_buffers.

Note: this includes OS page cache hits counted as "reads" — PostgreSQL does not distinguish shared_buffers hits from OS cache hits in this view. True disk reads require OS-level instrumentation (iostat, pgBadger + I/O tracing).

### pg_buffercache extension
Shows exactly what is in shared_buffers right now:
```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS pg_buffercache;

-- What's taking up buffer space?
SELECT c.relname, count(*) AS buffers,
       pg_size_pretty(count(*) * 8192) AS cached_size,
       round(count(*) * 100.0 / (SELECT count(*) FROM pg_buffercache), 2) AS pct
FROM pg_buffercache b
JOIN pg_class c ON c.relfilenode = b.relfilenode
WHERE b.relfilenode IS NOT NULL
GROUP BY c.relname
ORDER BY buffers DESC
LIMIT 20;

-- Dirty buffer ratio (unflushed changes)
SELECT count(*) AS dirty_buffers
FROM pg_buffercache
WHERE isdirty = true;
```

### Random IO vs sequential IO: the cost model
The `random_page_cost` vs `seq_page_cost` ratio is the planner's model of IO efficiency:
- **Sequential IO**: large reads benefit from kernel read-ahead; disk arm doesn't move (HDD), or NAND pre-fetch (SSD). Very fast.
- **Random IO**: each read goes to a new location. No prefetch benefit. Slow on HDD; much faster on SSD.

Default: `random_page_cost = 4.0, seq_page_cost = 1.0` — 4:1 ratio, calibrated for HDDs.
On NVMe SSD: set `random_page_cost = 1.1` — random and sequential are nearly identical cost.
On cloud persistent SSD (EBS, GCP PD): `random_page_cost = 1.5-2.0`.

Getting this wrong causes the planner to over-prefer sequential scans on NVMe systems.

### bgwriter and checkpointer
**bgwriter**: proactively writes dirty shared buffers to disk, reducing checkpoint pressure. Controlled by `bgwriter_lru_maxpages` and `bgwriter_delay`.

**checkpointer**: at each checkpoint, writes all dirty buffers to ensure data files are consistent. Frequent checkpoints = frequent IO bursts (checkpoint_completion_target smooths this). Rare checkpoints = long crash recovery time.

Checkpoint tuning:
```
checkpoint_timeout = 15min        -- max time between checkpoints
max_wal_size = 4GB                -- WAL size trigger for checkpoint
checkpoint_completion_target = 0.9 -- spread writes over 90% of checkpoint interval
```

### work_mem and sort/hash spills
`work_mem` is the memory budget for a single sort or hash table operation. Multiple operations per query × multiple connections = total RAM usage can be `work_mem × operations × connections`.

If a sort or hash exceeds `work_mem`, it spills to disk (temp files). Visible in `EXPLAIN ANALYZE` as `Sort Method: external merge` or `Hash Batches: N > 1`.

```sql
-- blocked: Docker not accessible
-- Check for temp file usage (spills to disk)
SELECT datname, temp_files, pg_size_pretty(temp_bytes) AS temp_size
FROM pg_stat_database
ORDER BY temp_bytes DESC;
```

## Micro-concepts
- **buffer pin**: a backend pins a buffer before reading it, preventing eviction while in use.
- **dirty buffer**: a buffer modified in shared_buffers but not yet written to the data file.
- **WAL vs data IO**: WAL writes are sequential (cheap); data page writes are random (expensive in checkpoint). This asymmetry is why WAL enables high throughput.
- **synchronous_commit = off**: allows WAL to be acknowledged before it is flushed to disk. Risks losing up to `wal_writer_delay` of committed transactions on crash. Huge write throughput gain for non-critical data.
- **full_page_writes**: after a checkpoint, PostgreSQL writes full pages to WAL on first modification (to handle torn pages on crash). Increases WAL volume. Required for crash safety.
- **huge_pages**: using OS huge pages (2MB) for shared_buffers reduces TLB pressure. Set `huge_pages = try` for high-memory systems.

## Beginner view / Intermediate view / Advanced view

**Beginner view**: PostgreSQL caches data in RAM. More RAM = faster queries. Check cache hit rate.

**Intermediate view**: `shared_buffers` is the primary cache. `effective_cache_size` tells the planner what's available. Cache hit rate above 95% is healthy. Spills to disk from sorts (temp files) hurt performance.

**Advanced view**: Double-buffering means PostgreSQL and the OS both cache pages. On Linux, `DROP CACHES` before benchmarking to measure true cold-cache performance. `pg_buffercache` reveals exactly which tables dominate the buffer pool — useful for diagnosing cache thrashing (a large table's sequential scan evicting all other cached pages). On NVMe systems, `random_page_cost = 1.1` is critical: without it, the planner chooses sequential scans over index scans even for 1% selectivity, causing unnecessary full table scans. The checkpoint IO pattern (spreading writes via `checkpoint_completion_target = 0.9`) prevents IO spikes that cause query latency jitter.

## Mental model
Imagine a library:
- **Disk** = the book archive in the basement (slow, exhaustive)
- **OS page cache** = the reading room with carts of recently requested books
- **shared_buffers** = your personal desk with the books currently open and in use
- **bgwriter** = the librarian who returns desk books to the reading room proactively
- **checkpointer** = the closing-time archivist who ensures all changes are filed in the basement
- **work_mem** = your scratch pad for sorting and organizing — if too small, you spill notes onto the floor (temp files)

## PostgreSQL view / SQL view / Non-SQL or hybrid view

**PostgreSQL view**: `pg_statio_user_tables`, `pg_statio_user_indexes`, `pg_buffercache`, `pg_stat_database` (temp files), `pg_stat_bgwriter` (checkpoint stats).

**SQL view**:
```sql
-- blocked: Docker not accessible
-- Cache hit rate per table
SELECT relname,
       heap_blks_hit, heap_blks_read,
       round(heap_blks_hit::numeric / nullif(heap_blks_hit + heap_blks_read, 0) * 100, 1) AS hit_pct
FROM pg_statio_user_tables
ORDER BY heap_blks_read DESC;

-- Checkpoint health
SELECT checkpoints_timed, checkpoints_req,
       round(buffers_checkpoint * 8.0 / 1024, 0) AS checkpoint_mb,
       round(buffers_clean * 8.0 / 1024, 0) AS bgwriter_mb,
       round(buffers_backend * 8.0 / 1024, 0) AS backend_io_mb
FROM pg_stat_bgwriter;

-- Temp file spill detection
SELECT datname, temp_files, pg_size_pretty(temp_bytes) AS spilled
FROM pg_stat_database WHERE temp_files > 0 ORDER BY temp_bytes DESC;
```

**Non-SQL / hybrid view**: `iostat -x 1` at the OS level shows actual disk read/write throughput per device. `vmstat` shows swap usage (a sign that shared_buffers + OS cache is exceeding available RAM). `free -m` shows OS page cache size in practice.

## Design principle
**Cache the working set, not the entire dataset**: For OLTP, the working set (active rows queried in the last N minutes) should fit in shared_buffers + OS page cache. For analytics, sequential IO is cheap enough that cache hit rate matters less than IO bandwidth. Tune `shared_buffers` to cover the OLTP working set, not as a percentage of total database size.

## Critical thinking / Creative thinking / Systems thinking

**Critical**: Cache hit rate from `pg_statio_user_tables` can be misleadingly high if the OS page cache is doing the heavy lifting — PostgreSQL counts OS cache hits as "hits" relative to disk. On a system with cold shared_buffers but warm OS cache, hit rate appears good while actually all reads go through the OS. True cold-cache IO requires `pg_prewarm` to load specific tables, or OS-level cache drop, to measure accurately.

**Creative**: `pg_prewarm` can preload critical tables into shared_buffers after a restart, dramatically reducing cold-start latency:
```sql
-- blocked: Docker not accessible
CREATE EXTENSION pg_prewarm;
SELECT pg_prewarm('orders');       -- preloads all pages of orders table
SELECT pg_prewarm('orders', 'prefetch');  -- async prefetch
```

**Systems**: In a multi-tenant environment, one tenant's large analytical query can evict all other tenants' cached pages (cache thrashing). Mitigations: `pg_buffercache` monitoring to detect eviction patterns; query timeout on analytical queries; pg_partman to partition large tenant tables so full scans are bounded; separate databases per tenant for isolation (separate buffer pools per database is not native — requires OS-level cgroup memory isolation or separate PostgreSQL instances).

## MCP and agent perspective
AI agents typically read recent memory records (episodic store) on every invocation — these rows should always be in shared_buffers. If the agent's memory table is small (< 1000 rows per agent), it will be hot in cache naturally. If it is large (100K+ rows), agents should use indexed access patterns (lookups by session_id + time range) rather than sequential scans that evict other cached pages. Monitor `pg_statio_user_tables` for the agent memory table: if `heap_blks_read` is non-zero regularly, shared_buffers may need adjustment or the agent query patterns need index optimization.

## Ontology perspective
The buffer cache is a materialization of the access pattern — it encodes which data is currently "alive" in the system's working consciousness. Least-recently-used eviction is a model of attention decay: frequently accessed data stays relevant; rarely accessed data fades. double-buffering between PostgreSQL and the OS represents two levels of a memory hierarchy, each with different agents (PostgreSQL vs kernel) making eviction decisions without coordination — a form of emergent cache management.

## Practice session

**Exercise 1 — Cache hit rate**: Measure current hit rate across all tables.
```sql
-- blocked: Docker not accessible
SELECT round(sum(heap_blks_hit)::numeric / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0) * 100, 2) AS overall_hit_rate_pct
FROM pg_statio_user_tables;
```

**Exercise 2 — Buffer census**: Which tables own the most buffers?
```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS pg_buffercache;
SELECT c.relname, count(*) AS buffers, pg_size_pretty(count(*) * 8192) AS cached
FROM pg_buffercache b
JOIN pg_class c ON c.relfilenode = b.relfilenode
WHERE b.relfilenode IS NOT NULL
GROUP BY c.relname ORDER BY buffers DESC LIMIT 10;
```

**Exercise 3 — Temp file detection**: Check for sort/hash spills.
```sql
-- blocked: Docker not accessible
SELECT datname, temp_files, pg_size_pretty(temp_bytes) AS total_spilled
FROM pg_stat_database
WHERE temp_files > 0;
```

**Exercise 4 — Checkpoint IO**: Assess who is doing most of the writes.
```sql
-- blocked: Docker not accessible
SELECT buffers_checkpoint AS checkpoint_writes,
       buffers_clean AS bgwriter_writes,
       buffers_backend AS backend_writes,
       maxwritten_clean
FROM pg_stat_bgwriter;
```

**Exercise 5 — effective_cache_size estimation**: Calculate for current system.
```sql
-- blocked: Docker not accessible
SHOW shared_buffers;
-- Check OS RAM: run `free -m` in shell
-- Set: effective_cache_size = shared_buffers + 0.7 * free_ram
SHOW effective_cache_size;
```

## References
- PostgreSQL Documentation: [Resource Consumption — Memory](https://www.postgresql.org/docs/16/runtime-config-resource.html#RUNTIME-CONFIG-RESOURCE-MEMORY)
- PostgreSQL Documentation: [pg_buffercache](https://www.postgresql.org/docs/16/pgbuffercache.html)
- PostgreSQL Documentation: [pg_statio_user_tables](https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STATIO-ALL-TABLES-VIEW)
- PostgreSQL Documentation: [Checkpoints](https://www.postgresql.org/docs/16/wal-configuration.html)
- Hironobu Suzuki: [The Internals of PostgreSQL, Chapter 8 — Buffer Manager](https://www.interdb.jp/pg/pgsql08.html)
- Christophe Pettus: [PostgreSQL Configuration for Humans](https://www.pgexperts.com/document.html?id=34)
- pg_prewarm: [Documentation](https://www.postgresql.org/docs/16/pgprewarm.html)
