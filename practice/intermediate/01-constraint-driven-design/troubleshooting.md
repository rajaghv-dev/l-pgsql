# Troubleshooting — Constraint-Driven Design

---

## ERROR: could not create exclusion constraint — extension btree_gist required

**Cause**: The `btree_gist` extension is not installed.

**Fix**:
```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;
```
This must be run before creating the EXCLUDE constraint on non-gist-native types like `INT`.

---

## ERROR: functions in check constraints must be marked IMMUTABLE

**Cause**: Using a volatile function like `now()` or `current_timestamp` in a CHECK constraint.

**Fix**: Use a BEFORE INSERT/UPDATE trigger for time-relative validation:
```sql
CREATE OR REPLACE FUNCTION check_future_reservation() RETURNS TRIGGER AS $$
BEGIN
    IF lower(NEW.during) < now() THEN
        RAISE EXCEPTION 'Reservation cannot start in the past';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

## ERROR: cannot insert into column "line_total" — it is a generated column

**Fix**: Remove `line_total` from your INSERT column list. Generated columns cannot be set explicitly.

---

## Partial unique index not being used

**Symptom**: Duplicate active email inserted successfully.
**Cause**: The condition `WHERE deleted_at IS NULL` in the index — if `deleted_at` has a default value (e.g., `now()`) instead of NULL for new rows, active rows won't match the index condition.

**Fix**: Ensure `deleted_at` is NULL for active customers (no default value for `deleted_at`).

---

## DEFERRABLE FK check fails at unexpected time

**Symptom**: Expected FK error at COMMIT, but got it at INSERT.
**Cause**: The FK may be `DEFERRABLE INITIALLY IMMEDIATE` (deferred possible, but immediate by default). The `setup.sql` uses `DEFERRABLE INITIALLY DEFERRED`.

**Fix**: Check the constraint definition:
```sql
SELECT conname, condeferrable, condeferred FROM pg_constraint
WHERE conname = 'order_items_order_fk';
-- condeferrable=true, condeferred=true → deferred by default
```

If you need to change deferral mode within a session:
```sql
SET CONSTRAINTS order_items_order_fk DEFERRED;
-- or
SET CONSTRAINTS order_items_order_fk IMMEDIATE;
```

---

## EXCLUDE constraint not catching overlap

**Symptom**: Overlapping reservation inserted without error.
**Cause**: TSRANGE overlap uses `&&`. Ensure both ranges actually overlap:
```sql
-- [09:00, 11:00) and [11:00, 12:00) do NOT overlap (exclusive upper bound)
-- [09:00, 11:00) and [10:59, 12:00) DO overlap
SELECT '[2026-06-01 09:00, 2026-06-01 11:00)'::tsrange
    && '[2026-06-01 11:00, 2026-06-01 12:00)'::tsrange;
-- Returns false — no overlap at a single point with exclusive bound
```

---

## Named constraint not appearing in error message

**Symptom**: Error message says "check constraint" but no name.
**Cause**: Constraint was defined inline without a name.

```sql
-- Unnamed — error will say "check constraint on table products"
CHECK (price > 0)

-- Named — error will say "check constraint price_must_be_positive"
CONSTRAINT price_must_be_positive CHECK (price > 0)
```

**Fix**: Drop and re-add with a name:
```sql
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_price_check;
ALTER TABLE products ADD CONSTRAINT price_must_be_positive CHECK (price > 0);
```

---

## Cannot drop a constraint — other objects depend on it

**Cause**: A FK in another table references the PK/UNIQUE constraint you're trying to drop.

**Fix**:
```sql
ALTER TABLE child_table DROP CONSTRAINT child_fk_constraint;
ALTER TABLE parent_table DROP CONSTRAINT parent_constraint;
```
Drop the FK first, then the referenced constraint.
