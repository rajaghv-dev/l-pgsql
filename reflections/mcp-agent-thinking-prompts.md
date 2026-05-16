# MCP and Agent Thinking Prompts

## How to use these questions

Use these when designing, reviewing, or debugging MCP tools backed by PostgreSQL. Each question has a defensible answer — the goal is to make you think through the implications before writing code.

## Tool design

### Q: Why should an MCP tool validate its inputs before querying PostgreSQL, even if the database has constraints?
**Type:** Critical
**Level:** Intermediate
**Hint:** Constraints prevent bad data storage, but they don't prevent bad SQL injection or unexpected query shapes.

### Q: What happens if an agent forgets to SET app.tenant_id before querying a table with RLS enabled?
**Type:** Systems
**Level:** Intermediate
**Hint:** RLS uses current_setting with a 'missing_ok' flag. What does it return when the setting is not set?

### Q: How would you design a tool that allows an agent to search one tenant's data and write to another?
**Type:** Creative
**Level:** Advanced
**Hint:** Should this be one tool or two? What are the security implications of cross-tenant writes?

### Q: Why is an MCP tool that runs arbitrary SQL dangerous, even for a trusted agent?
**Type:** Critical
**Level:** Intermediate
**Hint:** "Trusted" means the model — not the prompt. How does an adversarial prompt affect a trusted agent?

### Q: An agent tool needs to return the count of documents for the current tenant. Should it use COUNT(*) or a cached value?
**Type:** Systems
**Level:** Intermediate
**Hint:** Consider freshness, lock contention, and whether the count needs to be exact.

### Q: How would you make an agent tool idempotent — safe to retry on failure?
**Type:** Systems
**Level:** Intermediate
**Hint:** What database features help with idempotency? (ON CONFLICT, RETURNING, sequence-based deduplication)

### Q: Why should an audit log table be INSERT-only? What enforces this?
**Type:** Critical
**Level:** Intermediate
**Hint:** Who could modify the audit log, and why would that be a problem? How do triggers help?

### Q: An agent tool times out. Should the partial result be committed or rolled back?
**Type:** Systems
**Level:** Advanced
**Hint:** What is the connection between transaction boundaries and tool timeouts?

### Q: Should the MCP server or the database enforce tenant isolation? Why?
**Type:** Critical
**Level:** Intermediate
**Hint:** Consider what happens if there is a bug in the MCP server. Which layer is harder to bypass?

### Q: How do you test that an MCP tool correctly enforces RLS?
**Type:** Systems
**Level:** Intermediate
**Hint:** What test scenarios would prove RLS is working correctly vs. just appearing to work?

### Q: If two agent instances run the same tool simultaneously, what database mechanisms prevent them from conflicting?
**Type:** Systems
**Level:** Advanced
**Hint:** Think about SKIP LOCKED for queues, serializable isolation for invariants, and advisory locks.

### Q: An agent calls a tool that deletes a row. The human later asks "what was deleted?". What should the system return?
**Type:** Agent
**Level:** Intermediate
**Hint:** The row is gone. What else should have been written at deletion time?

### Q: Why does a tool that calls multiple database operations need to wrap them in a single transaction?
**Type:** Systems
**Level:** Intermediate
**Hint:** What happens to the audit log if the second operation fails but the first already committed?

### Q: Should agents be given the ability to create or drop tables? Why or why not?
**Type:** Critical
**Level:** Advanced
**Hint:** DDL takes AccessExclusiveLock. What is the blast radius if an agent executes a DROP TABLE?

### Q: How would you implement rate limiting for an agent tool at the database level?
**Type:** Creative
**Level:** Advanced
**Hint:** Think about pg_stat_statements, application tables for rate counts, or advisory locks.
