# Practice Session: Audit Triggers

Level: Intermediate  
Prerequisites: `concepts/intermediate/17-functions-triggers-and-audit-patterns.md`

## Goal

Build an audit log table and a PL/pgSQL trigger that records every INSERT, UPDATE, and DELETE on a target table. Practice reading the OLD and NEW row variables.

## Quick start

```bash
# blocked: Docker not accessible; validate when Docker Desktop WSL2 integration is enabled
docker exec cfp_postgres psql -U cfp -d cfp -f practice/intermediate/11-audit-triggers/setup.sql
```

## Files

| File | Purpose |
|------|---------|
| setup.sql | Creates documents table + audit_log table + trigger function + AFTER trigger |
| exercises.md | INSERT a row and check audit_log, UPDATE and see old_data/new_data, DELETE and verify, query audit history |
| solutions.md | Trigger function with TG_OP, OLD, NEW; JSONB casting; audit query patterns |
| reflection.md | Questions on trigger overhead, bypassing triggers, immutable audit design |
| ontology-notes.md | [[security-ontology]] [[transaction-ontology]] |
| troubleshooting.md | Trigger not firing, JSONB cast errors, TG_OP values |
| references.md | PL/pgSQL trigger docs, audit pattern resources |

## What you'll learn

- `CREATE OR REPLACE FUNCTION ... RETURNS TRIGGER LANGUAGE plpgsql`
- `TG_OP`, `OLD`, `NEW` row variables
- `CREATE TRIGGER ... AFTER INSERT OR UPDATE OR DELETE`
- Storing `row_to_json(OLD)::jsonb` in an audit log
- Why agent writes should always pass through an audit trigger

## MCP and agent perspective

Every MCP tool that writes data should operate on a table covered by an audit trigger. This means no agent action is invisible — every write leaves a traceable record that humans can inspect.
