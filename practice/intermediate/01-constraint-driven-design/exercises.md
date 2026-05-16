# Exercises — Constraint-Driven Design

---

## Exercise 1: Inspect existing constraints

Without looking at `setup.sql`, use only SQL catalog queries to discover what constraints exist on the `products` and `reservations` tables. For each constraint, identify:
- Its type (CHECK, UNIQUE, EXCLUDE, FK, PK)
- What it enforces
- Whether it is deferrable

```sql
-- Hint:
SELECT conname, contype, condeferrable, condeferred,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'products'::regclass OR conrelid = 'reservations'::regclass
ORDER BY conrelid::text, contype;
```

---

## Exercise 2: Trigger each constraint violation

For each constraint below, write an INSERT or UPDATE statement that violates it. Run it and record the exact error message.

| Constraint | Table | What to violate |
|---|---|---|
| `price_must_be_positive` | products | price = -5 |
| `products_sku_unique` | products | duplicate SKU 'BOOK-PG-001' |
| `valid_order_status` | orders | status = 'returned' |
| `qty_must_be_positive` | order_items | qty = -1 |
| `no_overlapping_reservations` | reservations | room 1, any overlap with 09:00–11:00 |
| `customers_active_email_idx` | customers | duplicate active email |

---

## Exercise 3: Partial unique index behavior

a) Soft-delete Alice's active account (set `deleted_at = now()` for `id = 1`).
b) Insert a new customer with `email = 'alice@example.com'`. Does it succeed?
c) Re-insert a second customer with `email = 'alice@example.com'`. Does it succeed?
d) Explain why the partial unique index allows (b) but blocks (c).

---

## Exercise 4: Add a new CHECK constraint

Add a constraint to the `reservations` table that ensures reservations cannot be in the past (i.e., the lower bound of `during` must be >= now).

Hint: CHECK constraints cannot reference `now()` directly (it is not immutable). Research the alternative approach.

What are the implications of this limitation? Is there a better way to enforce "no past reservations" in PostgreSQL?

---

## Exercise 5: Named constraint error handling

When a constraint is named, the name appears in the error message. Write a Python-style pseudocode (or real Python if you prefer) that:
1. Attempts an INSERT into `products`
2. Catches the database error
3. Maps the constraint name to a user-facing message

Example mapping:
- `price_must_be_positive` → "Product price must be greater than zero."
- `products_sku_unique` → "This SKU already exists."

---

## Exercise 6: DEFERRABLE FK in practice

The `order_items.order_id` FK is `DEFERRABLE INITIALLY DEFERRED`. This means the FK is checked at COMMIT, not at INSERT.

a) In a transaction, insert an order_item for `order_id = 500` (which does not exist), then insert the order itself, then commit. Confirm it succeeds.
b) Repeat the same transaction but do NOT insert the order. What happens at COMMIT?
c) What is the practical use case for deferrable FKs? Give one real-world scenario beyond this exercise.

---

## Exercise 7: Design an EXCLUDE constraint

You are building a staff scheduling system. A staff member cannot be scheduled for two shifts that overlap.

Tables:
```sql
CREATE TABLE staff (id SERIAL PRIMARY KEY, name TEXT NOT NULL);
CREATE TABLE shifts (
    id         SERIAL PRIMARY KEY,
    staff_id   INT    NOT NULL REFERENCES staff(id),
    during     TSRANGE NOT NULL
    -- Add an EXCLUDE constraint here
);
```

Write the complete DDL for `shifts` including the EXCLUDE constraint. Test it by inserting two overlapping shifts for the same staff member and one non-overlapping shift.

---

## Exercise 8: Constraints vs. triggers

The `no_overlapping_reservations` EXCLUDE constraint automatically prevents overlapping bookings. Suppose instead you used a BEFORE INSERT trigger that queries existing reservations and raises an exception if an overlap is found.

a) Write that trigger function and trigger in SQL.
b) List two reasons why the EXCLUDE constraint is preferable to the trigger approach.
c) List one scenario where a trigger would be necessary instead of a constraint.
