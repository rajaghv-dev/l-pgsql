# Troubleshooting — Audit Triggers

## Trigger function not found
**Error:** `ERROR: function generic_audit_fn() does not exist`
**Cause:** Setup SQL was not run, or was run in a different schema.
**Fix:** Run setup.sql, then verify: `SELECT proname FROM pg_proc WHERE proname = 'generic_audit_fn';`

## audit_log has no entries after setup
**Cause:** Trigger was attached after the INSERT statements ran.
**Diagnosis:** Check trigger existence:
```sql
SELECT trigger_name FROM information_schema.triggers
WHERE event_object_table = 'customers';
```
**Fix:** Drop and recreate the triggers, then re-insert seed data.

## old_data is NULL for UPDATE operations
**Cause:** Trigger function has a logic error in the CASE statement, or OLD is not accessible.
**Fix:** Ensure the trigger is `AFTER INSERT OR UPDATE OR DELETE FOR EACH ROW`. The OLD variable is only populated for UPDATE and DELETE. Double-check:
```sql
CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE row_to_json(OLD)::jsonb END
```

## audit_log grows too large
**Symptom:** `pg_total_relation_size('audit_log')` is huge.
**Fix options:**
1. Add a retention policy — delete entries older than 90 days:
```sql
DELETE FROM audit_log WHERE changed_at < now() - INTERVAL '90 days';
```
2. Partition `audit_log` by month for efficient cleanup:
```sql
CREATE TABLE audit_log PARTITION BY RANGE (changed_at);
```
3. Archive old entries to cold storage.

## Performance: high-write table with audit trigger is slow
**Cause:** Each row write now also writes to audit_log (2x write amplification).
**Fix options:**
1. Use statement-level triggers for bulk operations
2. Log only specific columns (not the full row)
3. Use pg_notify to queue audit writes asynchronously (accept eventual consistency)
4. Only audit high-risk operations (DELETE, UPDATE of specific columns)

## ERROR: permission denied for table audit_log
**Cause:** The trigger function is not SECURITY DEFINER, and the executing role lacks INSERT on audit_log.
**Fix:** Add `SECURITY DEFINER` to the function, or `GRANT INSERT ON audit_log TO cfp;`.
