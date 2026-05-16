# References — RLS and Multi-Tenancy

## PostgreSQL official documentation
- Row Security Policies: https://www.postgresql.org/docs/16/ddl-rowsecurity.html
- CREATE POLICY: https://www.postgresql.org/docs/16/sql-createpolicy.html
- pg_policies view: https://www.postgresql.org/docs/16/view-pg-policies.html
- current_setting(): https://www.postgresql.org/docs/16/functions-admin.html#FUNCTIONS-ADMIN-SET

## Blog posts and tutorials
- "Row Level Security in PostgreSQL" (Citus): https://www.citusdata.com/blog/2016/08/10/row-level-security/
- "Multi-tenancy with Row Level Security" (Supabase): https://supabase.com/docs/guides/auth/row-level-security
- "Postgres RLS Deep Dive" (Braintree): https://www.braintreepayments.com/blog/postgres-row-level-security/
- "RLS with PgBouncer": https://www.cybertec-postgresql.com/en/row-security-with-pgbouncer/

## Related concepts in this repo
- `concepts/intermediate/18-row-level-security-and-tenant-isolation.md`
- `concepts/intermediate/17-functions-triggers-and-audit-patterns.md` — audit trail to complement RLS
- `practice/intermediate/11-audit-triggers/` — audit logging of tenant-scoped data
