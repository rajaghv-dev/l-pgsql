# References — Audit Triggers

## PostgreSQL official documentation
- CREATE TRIGGER: https://www.postgresql.org/docs/16/sql-createtrigger.html
- PL/pgSQL Trigger Functions: https://www.postgresql.org/docs/16/plpgsql-trigger.html
- PL/pgSQL — special trigger variables (TG_OP, TG_TABLE_NAME): https://www.postgresql.org/docs/16/plpgsql-trigger.html#PLPGSQL-DML-TRIGGER
- information_schema.triggers: https://www.postgresql.org/docs/16/infoschema-triggers.html

## Reference implementations
- audit-trigger (2ndQuadrant): https://github.com/2ndQuadrant/audit-trigger — production-ready audit trigger
- pgaudit (not available locally): https://github.com/pgaudit/pgaudit — statement-level audit extension

## Blog posts
- "Auditing Changes in PostgreSQL": https://www.cybertec-postgresql.com/en/tracking-changes-in-postgresql/
- "PostgreSQL Triggers in Practice": https://www.postgresql.org/docs/16/trigger-example.html

## Related concepts in this repo
- `concepts/intermediate/17-functions-triggers-and-audit-patterns.md`
- `concepts/intermediate/18-row-level-security-and-tenant-isolation.md` — capture tenant context in audit
- `practice/intermediate/10-rls-and-multi-tenancy/` — RLS complements audit for full accountability
