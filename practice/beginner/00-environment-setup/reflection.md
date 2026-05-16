# Reflection — Practice 00: Environment Setup

Answer these questions in a personal notes file or discuss with a study partner. There are no single correct answers — the goal is to build intuition.

---

## Comprehension

1. What is the difference between `current_user` (in SQL) and the Unix user you used to run `docker exec`? Why might they be different?

2. PostgreSQL has `template0` and `template1` databases. What is the difference between them? Why would you never connect to `template0`?

3. The `pg_extension` catalog showed `plpgsql`. What is `plpgsql` and why is it always installed?

---

## Design

4. If you were building a multi-tenant SaaS application, would you put each tenant's data in a separate PostgreSQL database, a separate schema, or a separate table with a `tenant_id` column? What are the trade-offs of each?

5. Why does PostgreSQL use a connection model (one process per connection) rather than a thread-per-connection model? What are the implications for high-concurrency applications?

---

## Systems

6. `now()` returns the same timestamp throughout a transaction, even if the transaction runs for several seconds. Why was this designed this way? What function would you use if you need the real wall-clock time at the moment of each call?

7. If two developers both run `docker exec cfp_postgres psql -U cfp -d cfp` at the same time, do they share the same session? What happens if they both run `BEGIN` and try to write to the same row?

---

## Agent/MCP

8. An AI agent is given access to a PostgreSQL MCP server. Before writing anything, what queries should it run to understand the environment? (Think: version, schema, tables, constraints, current user's permissions.)

9. If an MCP server exposes a `query` tool that runs arbitrary SQL, what are the risks? How would you mitigate them? (Think: read-only vs read-write, SQL injection from tool arguments, permission scoping.)

10. Design a simple "connection health check" function that an agent could call at session start. What should it return? What should it do if the check fails?
