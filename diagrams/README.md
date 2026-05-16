# l-pgsql/diagrams

Visual diagrams for understanding PostgreSQL internals, query execution, concurrency, and application integration.

## What each diagram covers

| File | What it shows |
|------|---------------|
| `postgres-mental-model.md` | High-level map: databases → schemas → tables → rows; client connections → backend processes → shared memory → storage |
| `sql-vs-non-sql-capability-map.md` | SQL capabilities (SELECT/JOIN/aggregates/CTEs/window functions) vs non-SQL capabilities (JSONB/FTS/vector/ltree/geospatial) and their overlap |
| `extension-ecosystem-map.md` | PostgreSQL extensions categorized by purpose: Search, Security, Observability, Data Types, Indexing, Foreign Data |
| `application-to-database-flow.md` | Sequence: User → App → Connection Pool → Backend → Parser → Planner → Executor → Storage → Response |
| `sql-query-lifecycle.md` | What happens inside PostgreSQL when a query runs: parse → validate → plan → execute → return results |
| `transaction-mvcc-flow.md` | How MVCC snapshots work, how concurrent transactions see different versions of rows, and how VACUUM cleans up dead tuples |
| `index-selection-flow.md` | Decision tree: B-tree vs GIN vs GiST vs BRIN vs Hash vs partial indexes — which to choose and when |
| `vector-search-flow.md` | End-to-end vector search: text → embedding model → pgvector INSERT → query → ORDER BY cosine similarity → results |
| `hybrid-search-flow.md` | Combining FTS tsvector search with vector similarity search, merging and ranking results |
| `agent-safety-model.md` | How a bad agent action is stopped at each layer: typed validation → RLS → CHECK → NOT NULL/FK → TRIGGER → TRANSACTION |

## How to view Mermaid diagrams

All diagrams use [Mermaid](https://mermaid.js.org/) syntax — a text-based diagramming language that renders directly in many tools.

### GitHub
GitHub renders Mermaid in Markdown files automatically. Open any `.md` file in this folder on github.com to see the rendered diagram.

### VSCode
Install the [Markdown Preview Mermaid Support](https://marketplace.visualstudio.com/items?itemName=bierner.markdown-mermaid) extension. Then open any `.md` file and press `Ctrl+Shift+V` (or `Cmd+Shift+V` on Mac) to preview.

### Obsidian
Install the **Mermaid** community plugin via Settings → Community Plugins. Mermaid blocks in your notes will render in preview mode automatically.

### Online editor
Paste any Mermaid block at [mermaid.live](https://mermaid.live) to render and export as SVG/PNG.
