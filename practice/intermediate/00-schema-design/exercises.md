# Exercises — Schema Design

Work through these exercises in order. Write your SQL before checking `solutions.md`.

---

## Exercise 1: Read the schema as a diagram

Without running any SQL, draw (or describe in text) the entity-relationship diagram for the 5 tables in `setup.sql`. For each relationship, label:
- The cardinality (1:1, 1:N, M:N)
- Which table holds the FK
- The `ON DELETE` behavior

**Deliverable**: a text description or ASCII diagram.

---

## Exercise 2: Query across all tables

Write a single query that returns, for each confirmed or shipped order:
- Customer full name
- Order ID
- Order status
- Product name and qty for each line item
- Line total per item
- Order grand total (sum of line totals for that order)

Sort by customer name, then order ID.

---

## Exercise 3: Identify a normalization violation

The following table design is proposed as an alternative to the current `order_items` table:

```sql
-- Proposed bad design
CREATE TABLE orders_flat (
    order_id      INT,
    customer_name TEXT,      -- duplicated from customers
    product_name  TEXT,      -- duplicated from products
    category_name TEXT,      -- duplicated from categories
    qty           INT,
    unit_price    NUMERIC(10,2)
);
```

a) Which normal form(s) does this violate? Explain each violation.
b) Describe one update anomaly, one insertion anomaly, and one deletion anomaly that this design creates.
c) How does the current `setup.sql` schema avoid each anomaly?

---

## Exercise 4: Debate a denormalization choice

The current schema captures `unit_price` at the time of purchase in `order_items`. The `products.price` column reflects the current price.

a) Why is this the correct design? What anomaly would occur if `order_items` used a FK to `products.price` instead?
b) Is `unit_price` in `order_items` a form of denormalization? Justify your answer.
c) The `line_total` column is a generated column. Name one other column you could add as a generated column to this schema and explain its value.

---

## Exercise 5: Add a new relationship

A product can have multiple tags (e.g., "bestseller", "new-arrival", "on-sale"). Tags are shared across products.

a) What is the cardinality of this relationship?
b) Write the DDL to implement it correctly (new tables, FKs, indexes).
c) Write a query to find all products tagged "bestseller".
d) Propose an alternative using a PostgreSQL array column. What do you gain and lose?

---

## Exercise 6: Schema evolution

You need to add a `shipping_address` to orders. The address has: street, city, state, postal_code, country.

Consider two approaches:
- **Option A**: Add 5 separate columns to `orders`.
- **Option B**: Add one `JSONB` column `shipping_address` to `orders`.
- **Option C**: Create a separate `addresses` table and FK from `orders`.

For each option, describe:
1. How easy it is to query `WHERE country = 'US'`
2. How easy it is to enforce that country is always present
3. How easy it is to add a new address field later without a migration
4. Which you would choose and why

---

## Exercise 7: Spot the cardinality error

A junior developer writes:

```sql
CREATE TABLE products_categories (
    product_id  INT NOT NULL REFERENCES products(id),
    category_name TEXT NOT NULL  -- stores the name, not the category id
);
```

a) What normalization problem does this create?
b) What happens if a category is renamed?
c) Rewrite the DDL correctly using the existing `categories` table.

---

## Exercise 8: Analytical query

Using only the current schema, answer:
- Which customer has spent the most total across all orders (any status)?
- Which product appears in the most orders?
- What is the average order value (sum of line_totals per order)?

Write one query per question.
