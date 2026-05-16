# Solutions — Constraint-Driven Design

> validation: blocked — Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

---

## Exercise 1: Inspect constraints via catalog

```sql
SELECT conname, contype, condeferrable, condeferred,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid IN ('products'::regclass, 'reservations'::regclass)
ORDER BY conrelid::text, contype;
```

Expected output for `products`:
| conname | contype | condeferrable | definition |
|---|---|---|---|
| products_pkey | p | f | PRIMARY KEY (id) |
| products_sku_unique | u | f | UNIQUE (sku) |
| products_category_id_fkey | f | f | FOREIGN KEY (category_id) REFERENCES categories(id) |
| price_must_be_positive | c | f | CHECK ((price > 0)) |

For `reservations`: PK, FK to rooms, EXCLUDE constraint.

---

## Exercise 2: Constraint violations

```sql
-- price_must_be_positive
INSERT INTO products (category_id, name, sku, price) VALUES (1, 'X', 'X-001', -5);
-- ERROR: new row for relation "products" violates check constraint "price_must_be_positive"

-- products_sku_unique
INSERT INTO products (category_id, name, sku, price) VALUES (1, 'Y', 'BOOK-PG-001', 9.99);
-- ERROR: duplicate key value violates unique constraint "products_sku_unique"

-- valid_order_status
INSERT INTO orders (customer_id, status) VALUES (1, 'returned');
-- ERROR: new row for relation "orders" violates check constraint "valid_order_status"

-- qty_must_be_positive
INSERT INTO order_items (order_id, product_id, qty, unit_price) VALUES (1, 2, -1, 9.99);
-- ERROR: new row for relation "order_items" violates check constraint "qty_must_be_positive"

-- no_overlapping_reservations (room 1 is booked 09:00–11:00)
INSERT INTO reservations (room_id, guest, during)
    VALUES (1, 'Eve', '[2026-06-01 10:30, 2026-06-01 12:00)');
-- ERROR: conflicting key value violates exclusion constraint "no_overlapping_reservations"

-- customers_active_email_idx
INSERT INTO customers (email, full_name) VALUES ('bob@example.com', 'Dup Bob');
-- ERROR: duplicate key value violates unique constraint "customers_active_email_idx"
```

---

## Exercise 3: Partial unique index behavior

```sql
-- a) Soft-delete Alice (id=1)
UPDATE customers SET deleted_at = now() WHERE id = 1;

-- b) Insert a new Alice — SUCCEEDS (old Alice is deleted)
INSERT INTO customers (email, full_name) VALUES ('alice@example.com', 'Alice v2');

-- c) Insert another Alice — FAILS (v2 is active, unique among active)
INSERT INTO customers (email, full_name) VALUES ('alice@example.com', 'Alice v3');
-- ERROR: duplicate key value violates unique constraint "customers_active_email_idx"
```

**Explanation**: The partial unique index has `WHERE deleted_at IS NULL`. Rows where `deleted_at IS NOT NULL` are excluded from the index — they are invisible to the uniqueness check. So many deleted rows can share an email, but only one active row may.

---

## Exercise 4: CHECK constraint for no-past reservations

```sql
-- WRONG — CHECK cannot use now() (not immutable)
ALTER TABLE reservations
    ADD CONSTRAINT no_past_reservations
    CHECK (lower(during) >= now());  -- ERROR: functions in check constraints must be marked IMMUTABLE
```

PostgreSQL rejects this because `now()` is volatile (returns different values each call).

**Alternatives**:
1. **Application-layer validation** — check in application code before INSERT.
2. **BEFORE INSERT trigger** — triggers CAN call volatile functions:
```sql
CREATE OR REPLACE FUNCTION check_reservation_not_past()
RETURNS TRIGGER AS $$
BEGIN
    IF lower(NEW.during) < now() THEN
        RAISE EXCEPTION 'Reservation start time cannot be in the past';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER reservations_not_past
BEFORE INSERT OR UPDATE ON reservations
FOR EACH ROW EXECUTE FUNCTION check_reservation_not_past();
```

**Implication**: Constraints are statically validated at table definition time and must use immutable expressions. Time-relative rules require triggers or application logic.

---

## Exercise 5: Named constraint error handling

```python
import psycopg2

CONSTRAINT_MESSAGES = {
    "price_must_be_positive":  "Product price must be greater than zero.",
    "products_sku_unique":     "This SKU already exists.",
    "valid_order_status":      "Invalid order status value.",
    "qty_must_be_positive":    "Quantity must be at least 1.",
}

def insert_product(conn, category_id, name, sku, price):
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO products (category_id, name, sku, price) VALUES (%s, %s, %s, %s)",
                (category_id, name, sku, price)
            )
        conn.commit()
    except psycopg2.errors.CheckViolation as e:
        conn.rollback()
        constraint = e.diag.constraint_name
        msg = CONSTRAINT_MESSAGES.get(constraint, f"Constraint violated: {constraint}")
        raise ValueError(msg) from e
    except psycopg2.errors.UniqueViolation as e:
        conn.rollback()
        constraint = e.diag.constraint_name
        msg = CONSTRAINT_MESSAGES.get(constraint, f"Uniqueness violated: {constraint}")
        raise ValueError(msg) from e
```

---

## Exercise 6: DEFERRABLE FK in practice

```sql
-- a) Insert item before order — succeeds because FK is deferred
BEGIN;
INSERT INTO order_items (order_id, product_id, qty, unit_price) VALUES (500, 1, 1, 39.99);
INSERT INTO orders (id, customer_id, status) VALUES (500, 1, 'pending');
COMMIT;  -- FK checked here — order 500 exists → PASSES

-- b) Without the order — fails at COMMIT
BEGIN;
INSERT INTO order_items (order_id, product_id, qty, unit_price) VALUES (501, 1, 1, 39.99);
-- No INSERT INTO orders here
COMMIT;
-- ERROR: insert or update on table "order_items" violates foreign key constraint "order_items_order_fk"
```

**c) Real-world scenario**: Loading a graph of dependent objects from a file where the full referential graph is guaranteed to be consistent once complete, but intermediate states during loading may be inconsistent (e.g., importing a backup with circular relationships, or loading a bill-of-materials where assembly references sub-assemblies that appear later in the file).

---

## Exercise 7: Staff scheduling EXCLUDE constraint

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE staff (
    id   SERIAL PRIMARY KEY,
    name TEXT   NOT NULL
);

CREATE TABLE shifts (
    id       SERIAL   PRIMARY KEY,
    staff_id INT      NOT NULL REFERENCES staff(id),
    during   TSRANGE  NOT NULL,

    CONSTRAINT no_overlapping_shifts
        EXCLUDE USING GIST (staff_id WITH =, during WITH &&)
);

-- Seed
INSERT INTO staff (name) VALUES ('Dana'), ('Eli');

-- Succeeds: Dana 9–12
INSERT INTO shifts (staff_id, during) VALUES (1, '[2026-06-01 09:00, 2026-06-01 12:00)');

-- Succeeds: Dana 13–17 (no overlap)
INSERT INTO shifts (staff_id, during) VALUES (1, '[2026-06-01 13:00, 2026-06-01 17:00)');

-- Succeeds: Eli 09–12 (different staff_id)
INSERT INTO shifts (staff_id, during) VALUES (2, '[2026-06-01 09:00, 2026-06-01 12:00)');

-- FAILS: Dana 11–14 overlaps with Dana 9–12
INSERT INTO shifts (staff_id, during) VALUES (1, '[2026-06-01 11:00, 2026-06-01 14:00)');
-- ERROR: conflicting key value violates exclusion constraint "no_overlapping_shifts"
```

---

## Exercise 8: EXCLUDE vs. trigger

**a) Trigger approach:**
```sql
CREATE OR REPLACE FUNCTION check_no_overlap()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM reservations
        WHERE room_id = NEW.room_id
          AND id <> COALESCE(NEW.id, -1)
          AND during && NEW.during
    ) THEN
        RAISE EXCEPTION 'Room % is already booked during that time', NEW.room_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER reservations_no_overlap
BEFORE INSERT OR UPDATE ON reservations
FOR EACH ROW EXECUTE FUNCTION check_no_overlap();
```

**b) Why EXCLUDE is preferable:**
1. **Race condition safety**: The EXCLUDE constraint uses a GiST index with row-level locking during the check — it is safe under concurrent inserts. The trigger's `SELECT ... EXISTS` check is not atomic under high concurrency (two concurrent transactions can both pass the check, then both insert, creating an overlap).
2. **Performance**: The EXCLUDE constraint uses an index for the conflict check; the trigger performs a sequential scan or relies on a separate index that must be maintained manually.

**c) When a trigger is necessary:**
When the rule cannot be expressed as an index-based operator (e.g., "a reservation cannot be placed more than 30 days in advance" requires `now()`, which is volatile and cannot be used in a constraint).
