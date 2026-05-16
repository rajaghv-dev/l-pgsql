# Practice Session: Row-Level Security and Multi-Tenancy

Level: Intermediate  
Prerequisites: `concepts/intermediate/18-row-level-security-and-tenant-isolation.md`, basic SQL

## Goal

Implement row-level security so each tenant can only see their own rows. Practice the `current_setting('app.tenant_id')` pattern used in multi-tenant SaaS and AI agent architectures.

## Quick start

```bash
# blocked: Docker not accessible; validate when Docker Desktop WSL2 integration is enabled
docker exec cfp_postgres psql -U cfp -d cfp -f practice/intermediate/10-rls-and-multi-tenancy/setup.sql
```

## Files

| File | Purpose |
|------|---------|
| setup.sql | Creates tenants, documents tables; enables RLS; inserts seed rows for 2 tenants |
| exercises.md | SET app.tenant_id, verify isolation, create policy, BYPASSRLS test |
| solutions.md | Full solutions with RLS policy syntax explained |
| reflection.md | Questions on RLS performance, BYPASSRLS risk, agent safety |
| ontology-notes.md | Concept links: [[security-ontology]] [[ai-agent-memory-ontology]] |
| troubleshooting.md | Policy not applied, current_setting errors, permission denied |
| references.md | RLS official docs, MCP safety resources |

## What you'll learn

- `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`
- `CREATE POLICY ... USING (tenant_id = current_setting('app.tenant_id')::int)`
- `SET LOCAL app.tenant_id = '42'`
- Why `BYPASSRLS` is dangerous for agent roles
- How RLS makes tenant isolation database-enforced, not application-enforced

## MCP and agent perspective

Every agent query must be wrapped: `SET LOCAL app.tenant_id = ?` before any SELECT/INSERT/UPDATE. RLS enforces the boundary even if the application has a bug. Without RLS, a buggy agent could leak data across tenants.
