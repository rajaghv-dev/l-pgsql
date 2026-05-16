# Tooling Gaps

Documents which graph/code-intelligence tools were checked for availability in this environment (WSL2, Ubuntu) and what alternatives are used instead.

Checked: 2026-05-16

| Tool | Expected use | Available? | Evidence | Alternative |
|---|---|---|---|---|
| Graphify | Repo knowledge graph — visualise file/concept relationships across the curriculum | No | `which graphify` → not found | Manual `find` + `grep` traversal; Obsidian graph view (see below) |
| CodeGraph | Typed code dependency graph — trace import/call edges between source files | No | `which codegraph` → not found | `grep -r` for cross-file references; `git log --follow` for rename history |
| CodeQL | Security/correctness semantic queries over source | No | `which codeql` → not found | Manual SQL pattern review; `grep` for anti-patterns in `.sql` files |
| Pyrefly | Python type checking | No | `which pyrefly` → not found | N/A — repo contains no Python source files; not needed |
| Memgraph | Graph database backend for structured knowledge queries | No | `which memgraph` → not found | PostgreSQL itself (available via `psql`); flat-file indexes in `docs/` |
| Obsidian | Human-readable knowledge base with graph view and back-links | Yes (config present) | `.obsidian/` exists: `app.json`, `appearance.json`, `core-plugins.json`, `graph.json`, `plugins/` | Primary human navigation tool; used alongside `docs/*.md` files |

## Notes

- All five binary tools (graphify, codegraph, codeql, pyrefly, memgraph) are absent from the WSL2 PATH.
- Docker Desktop WSL integration is not active in this shell session (`docker ps` returns "command not found"), so container-based tool installation is blocked until Docker Desktop WSL2 integration is enabled.
- Obsidian is the only graph-capable tool present. Its config directory is tracked in `.obsidian/` at the repo root, giving vault-level linking and graph traversal for documentation files.
- For all code-intelligence tasks the practical fallbacks are: `grep -r`, `find`, `git log`, and direct `Read`/`Edit` operations via the Claude Code CLI.
