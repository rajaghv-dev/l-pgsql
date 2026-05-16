# Reflection — Practice 02: Schema and Table Basics

---

## Comprehension

1. `information_schema` and `pg_catalog` both describe database objects. What is the difference? When would you prefer one over the other?

2. What does `CREATE SCHEMA IF NOT EXISTS` do when the schema already exists? Why is this useful in migration scripts?

3. When you run `ALTER TABLE store.customers ADD COLUMN phone VARCHAR(20)`, PostgreSQL does not rewrite the table. How is this possible? What would force a full table rewrite?

4. What is the difference between `DROP TABLE store.reviews` and `DROP TABLE store.reviews CASCADE`? When would you use CASCADE?

---

## Design

5. The `store` schema contains `customers`, `products`, and `orders`. A new requirement: track the individual products in each order (an order can contain multiple products at different quantities). Design the table needed. What columns? What foreign keys? What constraints?

6. If a company has two product lines with completely different attributes, would you use one products table with many nullable columns, two separate tables, or one table with a JSONB metadata column? Argue for your preferred approach.

7. The `orders.status` column is `TEXT` with no constraint. A developer accidentally inserts `'PENDING'` instead of `'pending'`. How would you prevent this? Write the constraint.

---

## Systems

8. You need to add a `NOT NULL` column to a 50-million-row table in production with zero downtime. What is the correct multi-step process? (Hint: DEFAULT, backfill, set NOT NULL.)

9. A schema change (DROP COLUMN) was deployed to production. An old version of the application is still running and tries to INSERT with that column name. What happens? How do you design zero-downtime schema changes?

10. `pg_total_relation_size` includes TOAST. What is TOAST, and why does a table with many large TEXT values have a separate TOAST file?

---

## Agent/MCP

11. An agent needs to discover the full structure of an unknown database: schemas → tables → columns → constraints → indexes → foreign keys. Write the sequence of queries it would run (in SQL) to build this map.

12. An agent is given the task: "add a discount_percent column to the products table." What checks should it do before running `ALTER TABLE`? What could go wrong if it skips those checks?
