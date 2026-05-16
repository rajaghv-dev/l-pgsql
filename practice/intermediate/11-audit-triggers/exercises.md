# Exercises — Audit Triggers

**Status: blocked — Docker not accessible in this session**

## Exercise 1: Observe audit entries from seeding

```sql
-- blocked: Docker not accessible

SELECT id, table_name, operation, record_id, new_data, changed_by, changed_at
FROM audit_log
ORDER BY changed_at
LIMIT 10;

-- Note: old_data is NULL for INSERT operations
-- new_data contains the full row as JSONB
```

## Exercise 2: Update a record and observe the audit diff

```sql
-- blocked: Docker not accessible

-- Update Alice's tier
UPDATE customers SET tier = 'premium' WHERE id = 1;

-- Read the audit entry for this update
SELECT
    operation,
    old_data ->> 'tier' AS old_tier,
    new_data ->> 'tier' AS new_tier,
    changed_by,
    changed_at
FROM audit_log
WHERE table_name = 'customers' AND record_id = '1' AND operation = 'UPDATE'
ORDER BY changed_at DESC
LIMIT 1;
```

## Exercise 3: Delete a record and observe audit trail

```sql
-- blocked: Docker not accessible

-- Delete an order
DELETE FROM orders WHERE id = 1;

-- The audit log retains the deleted row's data
SELECT
    operation,
    old_data ->> 'amount' AS deleted_amount,
    old_data ->> 'status' AS deleted_status,
    new_data
FROM audit_log
WHERE table_name = 'orders' AND record_id = '1' AND operation = 'DELETE';
-- new_data is NULL for DELETE operations
```

## Exercise 4: Query audit history for a specific record

```sql
-- blocked: Docker not accessible

-- Full change history for customer id=1
SELECT
    operation,
    old_data,
    new_data,
    changed_by,
    changed_at
FROM audit_log
WHERE table_name = 'customers' AND record_id = '1'
ORDER BY changed_at;

-- Show only what changed between old and new
SELECT
    changed_at,
    operation,
    key,
    old_data -> key AS old_val,
    new_data -> key AS new_val
FROM audit_log,
     LATERAL jsonb_object_keys(COALESCE(new_data, old_data)) AS key
WHERE table_name = 'customers'
  AND record_id = '1'
  AND (old_data -> key) IS DISTINCT FROM (new_data -> key)
ORDER BY changed_at;
```

## Exercise 5: Status change audit query

```sql
-- blocked: Docker not accessible

-- Find all order status changes
SELECT
    record_id AS order_id,
    old_data ->> 'status' AS from_status,
    new_data ->> 'status' AS to_status,
    changed_at
FROM audit_log
WHERE table_name = 'orders'
  AND operation = 'UPDATE'
  AND (old_data ->> 'status') != (new_data ->> 'status')
ORDER BY changed_at;
```

## Exercise 6: BEFORE trigger for updated_at

```sql
-- blocked: Docker not accessible

-- Create a BEFORE trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER orders_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Verify
UPDATE orders SET notes = 'expedited' WHERE id = 2;
SELECT updated_at FROM orders WHERE id = 2;
-- Should show current timestamp
```

## Reflection questions
1. Why does the audit trigger use `SECURITY DEFINER`? What risk does this introduce?
2. What happens to audit entries if the outer transaction rolls back?
3. How would you implement a "diff-only" audit log that stores only changed fields?
4. When would a statement-level trigger with transition tables be better than a row-level trigger?
