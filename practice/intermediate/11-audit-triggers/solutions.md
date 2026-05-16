# Solutions — Audit Triggers

**Status: blocked — Docker not accessible in this session**

## Exercise 1 solution
INSERT audit entries have: `old_data = NULL`, `new_data = <full row as JSONB>`. The `changed_by` column shows the current database role (`cfp`). The `changed_at` timestamp is the transaction's `now()`.

Key observation: every INSERT, UPDATE, and DELETE that happened during seeding was automatically recorded — no application code was required.

## Exercise 2 solution
The UPDATE entry shows:
- `old_data ->> 'tier'` = 'standard'
- `new_data ->> 'tier'` = 'premium'

Both old and new contain the FULL row, not just the changed field. This is intentional — it allows restoring the previous state without needing to reconstruct it from a series of diffs.

## Exercise 3 solution
The DELETE entry shows:
- `old_data` = the full deleted row (amount, status, customer_id, etc.)
- `new_data` = NULL

The deleted row's data is preserved in the audit log. This is how you implement "soft-recovery" for accidentally deleted data — query the audit log for the latest DELETE entry and re-insert from `old_data`.

## Exercise 4 solution
The JSONB diff query uses `jsonb_object_keys()` to get all keys, then checks `old_data -> key IS DISTINCT FROM new_data -> key`. This shows only the fields that actually changed. The `IS DISTINCT FROM` operator handles NULL correctly (unlike `!=`).

For INSERT operations, `old_data` is NULL — the query should be filtered to show only UPDATE operations for meaningful diffs.

## Exercise 5 solution
Status changes are tracked by comparing `old_data ->> 'status'` with `new_data ->> 'status'`. This query works even if the `status` field is not a separate column in the orders table (e.g., if it was in JSONB) — the audit log captured the entire row.

## Exercise 6 solution
`BEFORE` triggers modify `NEW` before the row is written. Setting `NEW.updated_at := now()` ensures the timestamp is always current, regardless of what the application sends. This is more reliable than relying on application code to set `updated_at`.

The `AFTER` audit trigger (Exercise 2) will capture the updated `updated_at` value because it fires after the `BEFORE` trigger modifies `NEW`.

## Reflection answers
1. `SECURITY DEFINER` makes the trigger function run with the function creator's privileges. This allows writing to `audit_log` even if the session role doesn't have INSERT on that table. Risk: a poorly written SECURITY DEFINER function can be a privilege escalation vector. Keep it small and audited. Alternative: grant INSERT on audit_log directly to the application role.
2. Audit entries are inside the same transaction as the originating statement. If the outer transaction rolls back, the audit entry is also rolled back — it never happened in the database. This is actually correct behavior: an aborted transaction left no trace. If you need audit entries even for rolled-back transactions (e.g., for security investigations), use dblink or pg_notify to write to a separate connection.
3. Diff-only audit: in the trigger function, compare `row_to_json(OLD)` vs `row_to_json(NEW)` field by field and only insert changed fields:
```sql
INSERT INTO audit_log (old_data, new_data)
SELECT
    jsonb_object_agg(k, old_row.v) FILTER (WHERE old_row.v IS DISTINCT FROM new_row.v),
    jsonb_object_agg(k, new_row.v) FILTER (WHERE old_row.v IS DISTINCT FROM new_row.v)
FROM jsonb_each(row_to_json(OLD)::jsonb) AS old_row(k, v)
JOIN jsonb_each(row_to_json(NEW)::jsonb) AS new_row(k, v) USING (k);
```
4. Statement-level triggers fire once per SQL statement, not once per row. For bulk operations (`INSERT INTO ... SELECT ...` with 1000 rows), a row-level trigger fires 1000 times, creating 1000 audit entries and 1000 function calls. A statement-level trigger with `REFERENCING NEW TABLE AS inserted_rows` can insert one audit entry per statement using `INSERT INTO audit_log SELECT ... FROM inserted_rows` — much more efficient for bulk operations.
