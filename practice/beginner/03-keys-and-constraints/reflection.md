# Reflection — Practice 03: Keys and Constraints

---

## Comprehension

1. In Exercise 3, `ON CONFLICT (email) DO NOTHING` silently ignores the duplicate row. Is it possible to know afterward whether the INSERT was a new row or a conflict? How?

2. NOT NULL is not stored in `pg_constraint` — it is stored in `pg_attribute.attnotnull`. Why might PostgreSQL store it differently from CHECK, UNIQUE, and FK constraints?

3. When you add a CHECK constraint with `NOT VALID`, existing rows are NOT validated immediately. What does PostgreSQL do with new rows during the window between `ADD CONSTRAINT NOT VALID` and `VALIDATE CONSTRAINT`?

4. The `ON DELETE RESTRICT` behavior blocks deletion of a parent with children. What is the difference between RESTRICT and NO ACTION in practice?

---

## Design

5. The `products.status` column is constrained to `('active', 'discontinued', 'draft')`. A new requirement adds the status `'archived'`. What SQL do you write to add it? Is there any risk?

6. Design a `store.addresses` table where each customer can have zero or more addresses, one of which can be marked as the default. Write the DDL including all relevant constraints and keys.

7. Consider a `CHECK (email LIKE '%@%')` constraint on the customers table. What are the limits of this constraint? What valid emails would it allow that are not real email addresses? What invalid emails would it allow?

---

## Systems

8. A migration adds `CONSTRAINT chk_price CHECK (price > 0)` to a 10-million-row table. What happens if even one row has `price = 0`? What is the correct production migration process?

9. Foreign key checks require a lookup in the parent table on every INSERT/UPDATE to the child table. What index makes this lookup fast? Does PostgreSQL create it automatically?

10. Explain why gaps in a BIGSERIAL sequence are normal and do not indicate data loss. When would gaps appear? Is there a way to have a gap-free sequence? (Hint: think about transactions and sequence caching.)

---

## Agent/MCP

11. An agent is writing a new order. Before it inserts, what constraints must it satisfy? List each constraint by name and what the agent must provide or verify.

12. An agent encounters this error while inserting a product:
    ```
    ERROR: new row for relation "products" violates check constraint "chk_products_price_pos"
    ```
    Design the agent's recovery workflow: what should it do next? How should it communicate the problem to the user or calling system?

13. Design a tool called `safe_delete_customer` that an agent could call. It should: check for active orders, decide whether to cancel or block deletion, and return a structured result. Describe the SQL steps and the result format (not code — describe the logic).
