# Solutions — Row-Level Security and Multi-Tenancy

**Status: blocked — Docker not accessible in this session**

## Exercise 1 solution
Setting `app.tenant_id` with `SET LOCAL` scopes the value to the current transaction. Within the Acme transaction, only rows where `tenant_id = 'aaaaaaaa-...'` are visible. Within the BetaCo transaction, only BetaCo rows are visible. The policy is evaluated per-row by the database engine — the application cannot accidentally bypass it by constructing the wrong WHERE clause.

## Exercise 2 solution
RLS silently returns 0 rows for rows that violate the policy — no error is raised. This is by design: revealing that a row with a specific ID exists but is inaccessible would be a data leak. The attacker gets no information about BetaCo's data structure or ID values from the empty result.

## Exercise 3 solution
The `WITH CHECK` clause blocks inserts where `tenant_id != current_setting('app.tenant_id')::uuid`. The error message is:
```
ERROR:  new row violates row-level security policy for table "tasks"
```
This prevents one tenant from inserting data into another tenant's namespace even if they know the other tenant's ID.

## Exercise 4 solution
The second argument `TRUE` to `current_setting` makes it return NULL instead of raising an error when the setting is not defined. This is important for:
- Sessions that haven't set the tenant context yet (e.g., during migration)
- Superuser sessions where policies don't apply anyway
- Health-check queries that don't have tenant context

When `current_setting('app.tenant_id', TRUE)::uuid` evaluates to NULL, the policy `tenant_id = NULL` is always false (NULL != anything in SQL), so no rows are returned. Safe default behavior.

## Exercise 5 solution
Without `FORCE ROW LEVEL SECURITY`:
- The `cfp` role (table owner) bypasses all policies and sees all rows
- This is a security risk if migration scripts or admin queries run as the table owner

With `FORCE`:
- Even the table owner must satisfy the policy
- Superusers still bypass unless `row_security = on` is set explicitly (or SET ROLE to a non-superuser)

`BYPASSRLS` role attribute: grant to admin roles that legitimately need cross-tenant access (e.g., a support tool). Do not grant to application roles.

## Exercise 6 solution
EXPLAIN shows the RLS policy as a filter condition appended to the scan:
```
Filter: (tenant_id = (current_setting('app.tenant_id'::text, true))::uuid)
```
This confirms the policy is enforced at the PostgreSQL level, not in application code. The filter uses whatever index is available on `tenant_id` — always add an index on the tenant_id column for performance.

## Reflection answers
1. RLS returns 0 rows (not an error) to avoid information leakage. An error would confirm that a row exists. Silence is safer — the tenant can't distinguish "no such row" from "row exists but you can't see it".
2. ENABLE activates RLS for non-owner roles; FORCE applies it to the table owner as well. Without FORCE, the role that owns the table (typically the migration role) bypasses all policies.
3. Lenient mode `(TRUE)` returns NULL instead of raising an error when the setting is undefined. This prevents crashes in sessions that haven't set tenant context (e.g., direct superuser maintenance queries). The NULL → NULL comparison means no rows are returned — safe.
4. Transaction-mode PgBouncer: each SQL statement may use a different backend connection. `SET LOCAL` is transaction-scoped and resets on COMMIT — safe with transaction-mode pooling. Session-mode pooling: the connection persists across transactions; `SET LOCAL` resets on COMMIT, but if application code forgets to set it in a new transaction, it may read with the previous tenant's context from another session. Transaction-mode pooling is always safer for RLS-based multi-tenancy.
