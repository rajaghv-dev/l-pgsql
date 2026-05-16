# l-pgsql / ontology

This folder contains a structured ontology of PostgreSQL and related concepts, formatted for use with Obsidian's graph view.

---

## What is this ontology?

Each `.md` file in this folder represents a concept domain. Within each file, concepts are defined, categorized, and cross-linked using Obsidian `[[wikilink]]` syntax. Together they form a navigable knowledge graph of PostgreSQL — from SQL basics to AI agent memory patterns.

---

## How to use with Obsidian

1. Open this repository as an Obsidian vault (File → Open folder as vault → select `/mnt/d/wsl/l-pgsql`).
2. Navigate to this `ontology/` folder in the file explorer.
3. Open any `.md` file and click a `[[wikilink]]` to follow connections.
4. Use **Graph View** (Ctrl+G) to see the entire concept graph at once.
5. Use **Local Graph** (right-click a note → Open local graph) to see neighbors of a single concept.

---

## How to read the wikilinks

| Format | Meaning |
|--------|---------|
| `[[concept-name]]` | Link to a concept file or a heading anchor |
| `[[file#Section]]` | Link to a specific section within a file |
| `[[file\|display text]]` | Link with custom display text |

Cross-links appear in the **Related concepts** and **Obsidian connections** sections of every ontology file. They express semantic relationships: parent/child, sibling, contrast, and dependency.

---

## File index

| File | Domain |
|------|--------|
| [[postgres-concept-map]] | Master navigation map |
| [[sql-ontology]] | Core SQL: SELECT, JOIN, CTE, subquery |
| [[schema-design-ontology]] | Tables, columns, constraints, normalization |
| [[entity-relationship-ontology]] | ER modeling mapped to PostgreSQL |
| [[index-ontology]] | B-tree, GIN, GiST, BRIN, partial, composite |
| [[query-ontology]] | Parse → plan → execute lifecycle |
| [[transaction-ontology]] | ACID, MVCC, isolation, vacuum |
| [[extension-ontology]] | Extension ecosystem and categories |
| [[performance-ontology]] | Cost model, statistics, ANALYZE, scan types |
| [[security-ontology]] | Roles, grants, RLS, pgcrypto, audit |
| [[observability-ontology]] | pg_stat_* views, pg_locks, Prometheus, Grafana |
| [[vector-search-ontology]] | Embeddings, pgvector, ivfflat, hnsw, RAG |
| [[geospatial-ontology]] | PostGIS, geometry, SRID, spatial indexes |
| [[time-series-ontology]] | Partitioning, BRIN, window functions, date_trunc |
| [[ai-agent-memory-ontology]] | Agent memory, MCP tools, RLS, event log |
| [[domain-ontology-examples]] | Applying ontology to e-commerce, CMS, ledger |

---

## Reading the ontology files

Each file follows a consistent template:

- **Level / Domain** — complexity tier and subject area
- **Definition** — one precise sentence
- **Why this concept matters** — practical importance
- **Related concepts** — typed wikilinks (parent / child / related / contrast)
- **SQL representation** — Create / Inspect / Modify / Remove patterns
- **System catalog reference** — `pg_catalog` tables and views
- **Mental models** — Beginner → Intermediate → Advanced
- **MCP and agent perspective** — how an AI agent interacts with this concept
- **Practical implication** — situation/implication table
- **Obsidian connections** — flat list for graph density

---

## Stage notes

- Stage 13: Core ontology (SQL, schema, ER, index, query, transaction, extension)
- Stage 14: Advanced capabilities (performance, security, observability, vector, geospatial, time-series, AI agent memory, domain examples)
