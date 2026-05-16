# <!-- TODO: fill in for this specific lesson -->

Level: Advanced

> **Advanced calibration rules:**
> - Assume the reader designs production schemas and understands EXPLAIN ANALYZE output.
> - Go deep on internals: storage layout, buffer management, WAL, MVCC visibility, lock modes.
> - Emphasize failure modes, performance forensics, and operational runbooks.
> - Systems thinking is central: cascades, back-pressure, degraded-mode behavior.
> - Agent-safe architecture is a first-class concern: immutable audit, RLS, MCP gateway design.
> - Every performance claim should include a method to measure it locally.
> - Assume the reader will read PostgreSQL source code comments if pointed there.

---

## One-line intuition

<!-- TODO: fill in for this specific lesson -->
One sentence that encodes the deep insight — the thing that separates experts from intermediate practitioners.
Pattern: "X works by Y, which means the real cost is Z — not what most people think."

Example (MVCC): "PostgreSQL never updates a row in place — it writes a new row version and marks the old one dead, which is why VACUUM exists and why long transactions cause bloat."

---

## Why this exists

<!-- TODO: fill in for this specific lesson -->
Answer: "What fundamental constraint or correctness problem does this solve?"

- What was the state of the art before PostgreSQL implemented this?
- What failure mode does this prevent at production scale?
- What is the theoretical foundation (if any: ACID, CAP, consensus, etc.)?
- What was the motivating PostgreSQL commit or version?

Reference to the PostgreSQL source or commit notes if available:
`<!-- TODO: link to PostgreSQL mailing list discussion or commit if verifiable -->`

---

## First-principles explanation

<!-- TODO: fill in for this specific lesson -->
Start at the storage or execution model level.

1. **Storage layer:** What does this look like on disk or in memory?
2. **Execution layer:** How does the executor or planner interact with this?
3. **Concurrency layer:** How does this interact with MVCC, locking, or WAL?
4. **Recovery layer:** How does this survive a crash or a ROLLBACK?

Formal invariants (if applicable):
- <!-- invariant 1: e.g., "A committed transaction's WAL records always precede its heap changes" -->
- <!-- invariant 2 -->

---

## Micro-concepts

<!-- TODO: fill in for this specific lesson -->
4–7 precise sub-concepts. Each is a production-relevant insight.

### Micro-concept 1: <!-- name -->

**What it is:** One precise sentence.
**Why it matters in production:** One sentence about a real failure this prevents or enables.
**Internal mechanism:** Two to three sentences about how PostgreSQL implements this internally.

**Demonstrate it locally:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: SQL that reveals the internal mechanism -->
"
```

**Inspect internals:**
```bash
# Use pageinspect or pg_buffercache if relevant
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: pageinspect / pg_buffercache / pg_stat_bgwriter query -->
"
```

**Failure mode:** What goes wrong when this is misunderstood or misconfigured?
**Detection:** How do you detect this failure in pg_stat_* or logs?
**Remediation:** What is the runbook step to fix it?

---

### Micro-concept 2: <!-- name -->

<!-- repeat pattern above -->

---

## Beginner view

<!-- TODO: fill in for this specific lesson -->
One sentence only — pointer to beginner file.

"Beginner introduction: `concepts/beginner/<!-- file -->`."

---

## Intermediate view

<!-- TODO: fill in for this specific lesson -->
One paragraph — bridge from intermediate design knowledge to advanced internals.

"At the intermediate level, you learned <!-- summary of intermediate knowledge -->.
The advanced question is: <!-- what deeper question does that raise? -->"

---

## Advanced view

<!-- TODO: fill in for this specific lesson -->
This is the primary section. Cover all of:

### Storage and memory internals

```bash
# Inspect buffer cache behavior
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT * FROM pg_buffercache
  WHERE relfilenode = (SELECT relfilenode FROM pg_class WHERE relname = '<!-- table_name -->');
"

# Inspect page-level internals
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT * FROM heap_page_items(get_raw_page('<!-- table_name -->', 0));
"
```

### WAL and crash recovery

- What WAL records does this operation write?
- What is the WAL volume impact at high write rates?
- What happens to this operation during crash recovery?

```bash
# Monitor WAL write rate
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT pg_walfile_name(pg_current_wal_lsn()), pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0');
"
```

### Locking and concurrency

- Which lock mode does this acquire? (`AccessShareLock`, `RowExclusiveLock`, `AccessExclusiveLock`, etc.)
- What does it block? What blocks it?
- How long can it hold the lock, and what is the blast radius?

```bash
# Monitor locks
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT pid, locktype, relation::regclass, mode, granted
  FROM pg_locks
  WHERE NOT granted OR relation IS NOT NULL
  ORDER BY pid;
"
```

### Parallel execution

- Is this operation parallelizable?
- What `max_parallel_workers_per_gather` value triggers parallel execution?
- What prevents parallelism (non-parallel-safe functions, cursors, etc.)?

### Performance forensics

```bash
# Query plan with all details
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN (ANALYZE, BUFFERS, WAL, FORMAT TEXT)
  <!-- TODO: representative query -->;
"

# pg_stat_statements snapshot
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT query, calls, mean_exec_time, stddev_exec_time, rows, shared_blks_hit, shared_blks_read
  FROM pg_stat_statements
  WHERE query ILIKE '%<!-- keyword -->%'
  ORDER BY mean_exec_time DESC
  LIMIT 5;
"
```

What to look for:
- `Buffers: shared hit=X read=Y` — cache hit ratio for this query
- `Workers Planned/Launched` — parallel execution status
- `actual loops=X` — loop count in nested loop joins
- `rows removed by filter=X` — missing index signal

---

## Mental model

<!-- TODO: fill in for this specific lesson -->
A precise mental model that survives edge cases.

**Core model:**
```
<!-- ASCII diagram of the internal process -->
Client Request
    │
    ▼
Parse → Rewrite → Plan → Execute
    │                        │
    ▼                        ▼
Shared buffer            Heap / Index pages
    │                        │
    ▼                        ▼
WAL buffer → WAL file    MVCC visibility check
    │
    ▼
Checkpoint → fsync
```

**The key insight:** <!-- one sentence that makes the model actionable -->

**Where the model breaks down:** <!-- specific edge case that requires a different mental model -->

---

## PostgreSQL view

<!-- TODO: fill in for this specific lesson -->
Deep system catalog and statistics inspection:

```bash
# Relevant GUC parameters
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT name, setting, unit, context, short_desc
  FROM pg_settings
  WHERE name IN ('<!-- param1 -->', '<!-- param2 -->', '<!-- param3 -->');
"

# Statistics collector views
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT <!-- columns -->
  FROM pg_stat_<!-- view -->
  WHERE <!-- filter -->;
"

# Wait events (what is the process waiting for?)
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT pid, wait_event_type, wait_event, state, query
  FROM pg_stat_activity
  WHERE state != 'idle';
"
```

Relevant `postgresql.conf` parameters:
| Parameter | Default | When to change | Effect |
|-----------|---------|----------------|--------|
| `<!-- param1 -->` | `<!-- default -->` | <!-- condition --> | <!-- effect --> |
| `<!-- param2 -->` | `<!-- default -->` | <!-- condition --> | <!-- effect --> |

---

## SQL view

<!-- TODO: fill in for this specific lesson -->
Full syntax including advanced options:

```sql
-- Advanced syntax with all options
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- full SQL syntax -->
    <!-- option 1 -->   -- internals note: what this triggers
    <!-- option 2 -->   -- internals note: what this triggers
    <!-- option 3 -->   -- internals note: what this triggers
"
```

Execution characteristics:
- Lock acquired: `<!-- lock mode -->`
- WAL generated: `<!-- WAL volume estimate -->`
- Parallel eligible: Yes / No — why?
- MVCC impact: `<!-- describe how this affects tuple visibility -->`

---

## Non-SQL or hybrid view

<!-- TODO: fill in for this specific lesson -->
Advanced hybrid patterns:

```bash
# Vector + relational hybrid pattern
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: advanced JSONB, FTS, or pgvector integration example -->
"
```

Architecture decision:
- When does moving data out of PostgreSQL (into Redis, Elasticsearch, etc.) become correct?
- What is the consistency trade-off of a hybrid approach?
- What is the agent safety implication of data split across systems?

---

## Design principle

<!-- TODO: fill in for this specific lesson -->
The advanced principle — usually about invariants, failure modes, or irreversibility.

**Principle:** <!-- one-line statement -->

**Rationale:** <!-- two to four sentences with internals justification -->

**Correct production pattern:**
```sql
-- Production-grade implementation
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: correct advanced SQL, e.g., with proper locking, partitioning, or RLS -->
"
```

**Anti-pattern:**
```sql
-- This breaks at scale or under concurrent load — here is why
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: anti-pattern with internals explanation of why it fails -->
"
```

**Justified exception:** <!-- when is it acceptable to break this principle? -->

---

## Critical thinking

<!-- TODO: fill in for this specific lesson -->
Questions requiring systems-level reasoning:

1. What is the worst-case failure mode, and how long does recovery take?
2. What monitoring alert would give you 60 seconds of warning before this becomes a crisis?
3. If you had to revert this decision after 6 months in production, what is the migration plan?
4. What assumption built into PostgreSQL's implementation becomes incorrect at 1TB table size?
5. How does this interact with logical replication or streaming replication?

---

## Creative thinking

<!-- TODO: fill in for this specific lesson -->
1. What unconventional system design does this enable that most PostgreSQL users haven't considered?
2. If you were designing PostgreSQL's successor, how would you change this mechanism?
3. Can you use this feature to implement a primitive that PostgreSQL does not natively support (e.g., queues, pub/sub, event sourcing)?

---

## Systems thinking

<!-- TODO: fill in for this specific lesson -->
Full cascade analysis:

- **Upstream pressure points:** What writes or reads feed into this that could amplify failure?
- **Downstream dependencies:** What replication, caching, or application layer depends on correctness here?
- **Back-pressure:** Does this block other operations? Is there a queue depth limit?
- **Degraded-mode behavior:** What happens when this operates at 80% of its designed capacity?
- **Recovery time:** In the worst case, how long does full recovery take and what is the procedure?
- **Observability:** What pg_stat_* row or log line tells you this is failing before the user notices?
- **Runbook entry:** <!-- one-line summary of the remediation procedure -->

---

## MCP and agent perspective

<!-- TODO: fill in for this specific lesson -->
Advanced agent-safe architecture:

**Scenario:** <!-- e.g., "An agent operating in a regulated domain that must produce an immutable evidence trail" -->

- **State read:** <!-- describe, including which RLS policy scopes it -->
- **State written:** <!-- describe, is it append-only or mutable? -->
- **MCP tool name:** `<!-- e.g., submit_compliance_record -->`
- **Tool input:** Strongly typed — `{ "record_type": "...", "payload": {...}, "agent_id": "..." }`
- **Permission boundary:** Role `<!-- role_name -->` with `<!-- privilege_set -->`. RLS policy: `<!-- policy_name -->`
- **Immutability guarantee:** `<!-- how this is enforced — e.g., trigger blocks DELETE, column is generated -->``
- **Validation before execution:**
  1. Schema validation (JSON Schema or CHECK constraint)
  2. Business rule validation (PL/pgSQL function)
  3. Idempotency check (unique constraint on operation_id)
- **Audit event:** Written by trigger to `<!-- audit_table -->` — not writeable by the agent
- **Human approval required:** <!-- Yes/No/Conditional — specify the trigger condition -->
- **Failure mode:** <!-- describe the most dangerous failure: e.g., partial write, duplicate, phantom read -->
- **Recovery:** `<!-- compensating transaction or ROLLBACK procedure -->`
- **MCP gateway design note:** <!-- e.g., "The gateway must validate tenant_id before passing to psql, never trust agent-supplied tenant context" -->
- **Ontology connection:** `[[<!-- concept -->]]`

```bash
# Agent-safe write pattern with full audit context
docker exec cfp_postgres psql -U cfp -d cfp -c "
  BEGIN;
  SET LOCAL app.tenant_id = '42';
  SET LOCAL app.agent_id = 'agent-xyz';
  SET LOCAL app.operation_id = 'op-abc123';  -- idempotency key

  -- Trigger writes audit record; agent cannot skip it
  INSERT INTO <!-- table --> (<!-- cols -->)
  VALUES (<!-- values -->)
  ON CONFLICT (operation_id) DO NOTHING
  RETURNING id;

  COMMIT;
"
```

---

## Ontology perspective

<!-- TODO: fill in for this specific lesson -->

- **Concept name:** <!-- TODO -->
- **Is a:** <!-- parent concept in the concept hierarchy -->
- **Has parts:** <!-- sub-concepts / implementation details -->
- **Related to:** <!-- sibling concepts at same level of abstraction -->
- **Contrasts with:** <!-- opposing mechanism or alternative -->
- **Depends on:** <!-- prerequisite concepts (must understand first) -->
- **Enables:** <!-- higher-level concepts this makes possible -->

Obsidian links:
- `[[<!-- parent concept -->]]`
- `[[<!-- child concept 1 -->]]`
- `[[<!-- child concept 2 -->]]`
- `[[<!-- related concept -->]]`
- `[[<!-- contrasting concept -->]]`

---

## Practice session

```
practice/advanced/<!-- topic-folder-name -->/
```

```bash
# Run setup
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/advanced/<!-- topic-folder-name -->/setup.sql

# Validate: confirm internals are visible
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: system catalog or pg_stat_* validation query -->
"
```

---

## References

<!-- TODO: fill in for this specific lesson -->

| Title | URL | Type | Level | Time |
|-------|-----|------|-------|------|
| PostgreSQL docs — <!-- topic --> | https://www.postgresql.org/docs/current/<!-- page --> | Official docs | Advanced | 30 min |
| PostgreSQL internals (Hironobu Suzuki) | https://www.interdb.jp/pg/ | Free book | Advanced | 2–4 hr |
| <!-- TODO: mailing list thread or commit note --> | <!-- URL --> | Source | Advanced | 20 min |
| <!-- TODO: performance case study --> | <!-- URL --> | Engineering blog | Advanced | 15 min |

> If a reference cannot be verified, write: `TODO: Find verified reference for this topic.`
