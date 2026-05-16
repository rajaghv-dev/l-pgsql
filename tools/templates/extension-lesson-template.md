# Extension: <!-- extension_name -->

> File location: `extensions/<!-- extension_name -->.md`
>
> **How to use this template:**
> One file per extension. Keep it practical and scannable.
> Every SQL block must be runnable with the local setup.
> Prefer links over long explanations.

---

## One-line purpose

<!-- TODO: fill in for this specific extension -->
One sentence. What does this extension do and why would you install it?

Example: "pg_trgm adds trigram-based fuzzy text matching — lets you find 'postgress' when the user types 'postgres'."

---

## Why it exists

<!-- TODO: fill in for this specific extension -->
What problem does PostgreSQL's built-in functionality leave unsolved?
What domain or use case demanded this extension?
Who maintains it (PostgreSQL core team, contrib, third-party)?

- **Maintainer:** <!-- e.g., PostgreSQL core contrib / third-party / PGXS -->
- **First available:** PostgreSQL <!-- version -->
- **Docs URL:** <!-- https://www.postgresql.org/docs/current/... or external URL -->

---

## Install command

Check if already installed:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT * FROM pg_extension WHERE extname = '<!-- extension_name -->';
"
```

Install:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE EXTENSION IF NOT EXISTS <!-- extension_name -->;
"
```

Verify:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT extname, extversion FROM pg_extension WHERE extname = '<!-- extension_name -->';
"
```

Expected output:
```
   extname    | extversion
--------------+------------
 <!-- name --> | <!-- ver -->
```

> Note: Some extensions require `shared_preload_libraries` in `postgresql.conf` and a server restart.
> If required, add: `<!-- extension_name -->` to `shared_preload_libraries`.
> Status for this extension: <!-- required / not required -->

---

## Core operations

### Operation 1: <!-- name, e.g., "Create the supporting schema" -->

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: SQL for first core operation, e.g., CREATE TABLE with extension type -->
"
```

**What this does:** <!-- one sentence -->
**When you need this:** <!-- one sentence about the use case -->

---

### Operation 2: <!-- name, e.g., "Basic query" -->

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: SQL for the most common query pattern with this extension -->
"
```

**What this does:** <!-- one sentence -->
**Expected output format:** <!-- describe the result shape -->

---

### Operation 3: <!-- name, e.g., "Practical example" -->

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: SQL for a realistic end-to-end example -->
"
```

---

### Operation 4 (advanced): <!-- name, e.g., "Configuration tuning" -->

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: SQL or config for advanced usage -->
"
```

---

## Index types (if applicable)

<!-- TODO: fill in or remove this section if the extension adds no index types -->
This extension adds the following index access methods:

| Index type | Operator class | Use case |
|------------|---------------|----------|
| `<!-- e.g., GIN -->` | `<!-- e.g., vector_cosine_ops -->` | <!-- use case --> |
| `<!-- e.g., IVFFlat -->` | `<!-- e.g., vector_l2_ops -->` | <!-- use case --> |

Create an index:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE INDEX <!-- idx_name --> ON <!-- table --> USING <!-- method --> (<!-- column --> <!-- ops_class -->);
"
```

Trade-offs:
- Build time: <!-- fast / slow at X rows -->
- Query speedup: <!-- rough estimate or order of magnitude -->
- Maintenance cost: <!-- impact on INSERT / UPDATE / DELETE -->
- When NOT to use an index from this extension: <!-- condition -->

---

## Performance characteristics

<!-- TODO: fill in for this specific extension -->

| Dimension | Characteristic | Notes |
|-----------|----------------|-------|
| Query speed | <!-- fast / O(log n) / O(n) --> | <!-- condition for fast path --> |
| Index build time | <!-- fast / slow --> | <!-- row count threshold --> |
| Index size | <!-- small / large / X× table size --> | <!-- reason --> |
| Write overhead | <!-- low / medium / high --> | <!-- what triggers the overhead --> |
| Parallel safe | <!-- yes / no / partial --> | <!-- which operations --> |
| Works with partitioning | <!-- yes / no / limited --> | <!-- caveat if any --> |

**Bottleneck:** <!-- what saturates first at high load -->
**Scale limit:** <!-- approximate row count or data size where behavior changes -->

---

## Agent and MCP angle

<!-- TODO: fill in for this specific extension -->
How would an AI agent use this extension?

- **Agent use case:** <!-- e.g., "Semantic memory retrieval for RAG", "Typo-tolerant user input correction" -->
- **MCP tool name:** `<!-- e.g., search_memory, fuzzy_match_product -->`
- **Tool input:** `{ <!-- key fields --> }`
- **PostgreSQL operation:** `<!-- the SQL the tool executes -->`
- **Why this is better than the naive approach:** <!-- e.g., "avoids loading all rows into the application layer" -->
- **Permission boundary:** The MCP tool should run as role `<!-- role_name -->` with `SELECT` only on the relevant table
- **What must NOT be exposed:** <!-- e.g., "Raw embeddings, internal similarity scores used for ranking" -->
- **Audit consideration:** <!-- e.g., "Log all similarity-search queries with the query vector hash, not the full vector" -->
- **Failure mode:** <!-- e.g., "Index not built → falls back to seq scan → acceptable for dev, unacceptable in prod" -->

```bash
# Agent query pattern
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SET app.agent_id = 'agent-xyz';
  <!-- TODO: agent-safe query using this extension -->
"
```

---

## When to use

<!-- TODO: fill in for this specific extension -->
Use this extension when:

- <!-- condition 1, e.g., "You need fuzzy text matching and pg_trgm index is faster than LIKE '%...%'" -->
- <!-- condition 2 -->
- <!-- condition 3 -->

Concrete signal: <!-- e.g., "You see slow LIKE queries in pg_stat_statements" -->

---

## When NOT to use

<!-- TODO: fill in for this specific extension -->
Do not use this extension when:

- <!-- condition 1, e.g., "You only have < 1000 rows — a LIKE scan is fine" -->
- <!-- condition 2, e.g., "The extension requires a library that is not in your container image" -->
- <!-- condition 3, e.g., "You need exact matches only — a B-tree index is simpler and faster" -->

---

## Alternatives

<!-- TODO: fill in for this specific extension -->

| Alternative | When it is better | When this extension wins |
|-------------|------------------|--------------------------|
| <!-- e.g., built-in LIKE --> | <!-- e.g., small tables, exact prefix matching --> | <!-- e.g., fuzzy matching at scale --> |
| <!-- e.g., Elasticsearch --> | <!-- e.g., you need full search infrastructure --> | <!-- e.g., you want to stay in PostgreSQL --> |

---

## Quick reference

```bash
# Install
docker exec cfp_postgres psql -U cfp -d cfp -c "CREATE EXTENSION IF NOT EXISTS <!-- extension_name -->;"

# Most common query
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: the one-liner that shows the extension working -->
"

# Check it is active
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT extname, extversion FROM pg_extension WHERE extname = '<!-- extension_name -->';
"
```

---

## References

<!-- TODO: fill in for this specific extension -->

| Title | URL | Type | Level | Time |
|-------|-----|------|-------|------|
| PostgreSQL docs — <!-- extension_name --> | https://www.postgresql.org/docs/current/<!-- page --> | Official docs | <!-- level --> | 15 min |
| <!-- TODO: tutorial or deep-dive --> | <!-- URL --> | <!-- type --> | <!-- level --> | <!-- time --> |

> If a reference cannot be verified, write: `TODO: Find verified reference for this extension.`
