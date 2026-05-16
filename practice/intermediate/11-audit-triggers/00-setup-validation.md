# Setup Validation — Practice 11

**Status: blocked — Docker not accessible in this session**

```sql
-- blocked: Docker not accessible

-- 1. Tables exist
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('customers', 'orders', 'audit_log')
ORDER BY table_name;

-- 2. Triggers are registered
SELECT trigger_name, event_object_table, event_manipulation, action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table;
-- Expected: customers_audit and orders_audit

-- 3. Audit log has entries from seeding
SELECT table_name, operation, COUNT(*)
FROM audit_log
GROUP BY table_name, operation
ORDER BY table_name;
-- Expected: customers INSERT=3, orders INSERT=4

-- 4. Check audit_log structure
SELECT record_id, old_data, new_data FROM audit_log LIMIT 3;
-- INSERT rows: old_data=NULL, new_data has the full row
```
