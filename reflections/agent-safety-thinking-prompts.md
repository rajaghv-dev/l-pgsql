# Agent Safety Thinking Prompts

## How to use these questions

Use these when designing agent-safe database architectures or reviewing existing agent integrations. The goal is to build systems where agent mistakes are contained and reversible.

## Permission and isolation

### Q: What is the difference between authentication (who is the agent?) and authorization (what can it do?) in PostgreSQL?
**Type:** Critical
**Level:** Beginner
**Hint:** Think about pg_hba.conf (authentication) vs GRANT and RLS policies (authorization).

### Q: Why is an INSERT-only audit table safer than a regular table that allows UPDATE and DELETE?
**Type:** Critical
**Level:** Intermediate
**Hint:** If the audit table is mutable, who benefits from mutating it — and what does that tell you?

### Q: An agent has BYPASSRLS privilege. What does this mean for tenant isolation?
**Type:** Critical
**Level:** Intermediate
**Hint:** BYPASSRLS grants what? Is there any RLS policy that still applies?

### Q: How does SKIP LOCKED prevent two agent workers from processing the same pending action simultaneously?
**Type:** Systems
**Level:** Intermediate
**Hint:** What does SKIP LOCKED do when a row is already locked by another transaction?

### Q: If an agent's role has SUPERUSER, what tenant isolation mechanisms are still effective?
**Type:** Critical
**Level:** Advanced
**Hint:** Superuser bypasses RLS (unless FORCE ROW SECURITY is set). What is still protecting data?

### Q: An agent is given a "read-only" role. Can it still cause problems?
**Type:** Critical
**Level:** Intermediate
**Hint:** SELECT can lock rows. Long-running SELECT can block autovacuum. What else?

## Audit and traceability

### Q: An agent inserts a row. Six months later, the row looks wrong. How do you know the agent caused it?
**Type:** Systems
**Level:** Intermediate
**Hint:** What must have been captured at insert time for this question to be answerable?

### Q: Why should agent_id be stored in the audit log rather than inferred from the database session?
**Type:** Critical
**Level:** Intermediate
**Hint:** Multiple agent requests may share a connection pool. What does that mean for session-based identification?

### Q: Can a trigger be disabled? Who can disable it? What does this mean for audit log completeness?
**Type:** Critical
**Level:** Advanced
**Hint:** ALTER TABLE DISABLE TRIGGER requires what privilege? How do you detect a disabled trigger?

## Failure and recovery

### Q: An agent tool fails halfway through a multi-step operation. What is the correct recovery strategy?
**Type:** Systems
**Level:** Intermediate
**Hint:** Consider: transaction rollback, compensation events, and idempotent retry.

### Q: Why is a "compensation event" safer than a direct undo (DELETE or UPDATE) for agent recovery?
**Type:** Critical
**Level:** Advanced
**Hint:** Consider the audit trail and the difference between rewriting history and recording a correction.

### Q: An agent accidentally inserts 10,000 rows with wrong data. What options exist for remediation?
**Type:** Creative
**Level:** Advanced
**Hint:** Think about point-in-time recovery, soft delete, correction events, and the cost of each.

### Q: How would you design a database schema so that agent mistakes are always reversible?
**Type:** Creative
**Level:** Advanced
**Hint:** Consider: never DELETE, use soft deletes, event sourcing, immutable ledgers, snapshots.

### Q: What is the minimum set of privileges an agent needs for read-only memory retrieval?
**Type:** Critical
**Level:** Intermediate
**Hint:** List specifically: CONNECT, USAGE ON SCHEMA, SELECT ON TABLE — anything else?

### Q: Why should agent tools have explicit timeouts, and what happens in PostgreSQL if a query times out?
**Type:** Systems
**Level:** Intermediate
**Hint:** statement_timeout causes an error — not a graceful stop. What does that mean for open transactions?
