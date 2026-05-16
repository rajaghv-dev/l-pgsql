# Reflection — Constraint-Driven Design

---

## 1. The cost of NOT NULL

Go through the `setup.sql` and list every column that is NOT NULL. For each one, ask: "What would happen if this column were accidentally NULL?" Would the application crash, silently return wrong results, or handle it gracefully?

Which NOT NULL constraint do you think is most critical? Which columns should be NOT NULL that currently aren't (if any)?

---

## 2. The partial unique index decision

The `customers` table uses a partial unique index instead of a UNIQUE constraint for `email`. This was a deliberate design choice for soft deletes.

What are the risks of this approach? Specifically:
- Can two active users accidentally share an email if the application has a bug?
- How does this interact with an application that caches constraint violation error codes?

---

## 3. Constraints as documentation

Imagine a new team member reads the `reservations` table DDL (with the EXCLUDE constraint) without any other context.

What do they learn about the business rules just from reading the DDL? What do they NOT learn (what is only in application code)?

---

## 4. Constraint vs. trigger trade-off

For each business rule below, decide whether you would implement it as a constraint or a trigger, and why:

| Business rule | Constraint or trigger? |
|---|---|
| Price must be positive | ? |
| Order total must equal sum of line items | ? |
| A room cannot be double-booked | ? |
| A reservation cannot be made more than 90 days in advance | ? |
| A product's stock level cannot go below zero | ? |

---

## 5. Deferred constraints and batch loading

Deferred constraints are uncommon in most application code but essential for certain ETL/batch patterns.

Describe a data import scenario (from a CSV, API, or backup file) where a deferred FK would make the import significantly simpler. What would the alternative be without deferrable constraints?

---

## 6. What constraints cannot do

Constraints operate on single rows (CHECK) or across rows within the same table using an index (UNIQUE, EXCLUDE). They cannot:
- Reference data in another table (that requires a trigger or FK)
- Call volatile functions like `now()`
- Express aggregate conditions (e.g., "total orders for a customer cannot exceed 1000")

For each of these limitations, describe the safest workaround.
