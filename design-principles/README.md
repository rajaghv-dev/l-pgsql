# l-pgsql/design-principles

Actionable design principles for working with PostgreSQL at every level of experience.

## Design principles vs best practices

**Best practices** are community-agreed defaults: "use connection pooling", "enable autovacuum", "set up monitoring". They tell you what to do.

**Design principles** are decision rules that tell you *how to think* when facing a trade-off. They are stated as imperatives ("Always...", "Never...", "Prefer...") and come with a rationale, a concrete example, and — importantly — a description of when it's acceptable to break the rule.

These principles are opinionated by design. If you find yourself disagreeing, that's a good sign: write down why. That reasoning is the start of your own architecture decision record.

## How to use this folder

- **Learning:** Read one file per study session. Apply the principle in a schema or query you're actively writing.
- **Code review:** Use the principles as a checklist. "Does this PR violate the FK index rule? The short-transaction rule?"
- **Teaching:** Use the counter-examples as prompts. Show the broken version first, ask what will go wrong, then reveal the principle.
- **Agent/MCP design:** The `mcp-tool-design-principles.md` file translates database principles into MCP tool design rules.

## Files in this folder

| File | Audience | Principles |
|------|----------|-----------|
| `beginner-design-principles.md` | New to SQL or PostgreSQL | Always use a PK, never omit WHERE, use timestamptz, etc. |
| `intermediate-design-principles.md` | Comfortable with SQL, building real schemas | Normalize-then-denormalize, partial indexes, CHECK over app validation |
| `advanced-design-principles.md` | Production systems, performance tuning | MVCC-aware design, RLS, vacuum strategy, partitioning |
| `schema-design-principles.md` | Schema architects | Naming, normalization, audit columns, making bad data hard to store |
| `query-design-principles.md` | Query authors | Filter early, avoid SELECT *, use RETURNING, set-based thinking |
| `indexing-design-principles.md` | Anyone writing queries or maintaining tables | Index what you query, verify with EXPLAIN, remove unused indexes |
| `transaction-design-principles.md` | Application developers | Short transactions, SAVEPOINT, SERIALIZABLE only when necessary |
| `concurrency-design-principles.md` | High-throughput systems | SKIP LOCKED, optimistic locking, DDL lock awareness |
| `security-design-principles.md` | Multi-tenant apps, production | Least privilege, RLS, no plaintext passwords, audit writes |
| `mcp-tool-design-principles.md` | AI/agent system builders | Narrow tools, typed validation, tenant context, human approval |
