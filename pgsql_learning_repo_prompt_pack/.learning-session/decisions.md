# Decisions

- Use staged generation to avoid token explosion.
- Use session memory so work can resume across agents.
- Use beginner/intermediate/advanced levels to preserve depth without dumping everything at once.
- Use ontology to connect entities, relationships, constraints, invariants, access paths, and failure modes.
- Use validation before declaring stage completion.
- Use MCP/agent perspective because PostgreSQL can safely support agent memory, state, permissions, retrieval, and audit.
