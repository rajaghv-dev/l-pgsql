# Reflection — Schema Design

Use these prompts after completing the exercises. Write in your own words; there are no "correct" answers here.

---

## 1. Access-pattern-first thinking

Before you looked at `setup.sql`, what tables did you assume the e-commerce schema would need? How close was your mental model to the actual schema? What did you add or remove?

---

## 2. The generated column trade-off

`line_total` is stored as a generated column rather than computed in every query. What are the failure modes of this approach? (Hint: what happens if the formula needs to change — e.g., you need to add a discount applied after purchase?)

---

## 3. JSONB for product attributes

The `products.attrs` column is JSONB. Imagine your company's analytics team needs to filter products by `attrs->>'color'` for 10 million product rows. What would you do to make this query fast? What are the limits of that approach?

---

## 4. Normalization vs. query complexity

After Exercise 2, consider: the query joins 4 tables. Would a denormalized `orders_flat` table (from Exercise 3) make that query simpler? Would you still choose the normalized design for a production system? Under what conditions might you change your mind?

---

## 5. Schema as a contract

If you were onboarding a new developer onto this codebase, what would you highlight about the schema that communicates business rules without requiring them to read application code?

---

## 6. Mistakes to avoid

Describe one schema design mistake you could make with this domain that would be expensive to fix later (e.g., after 10 million orders are in the table). How would you detect it early?

---

## 7. FK directionality

Why does `orders.customer_id` reference `customers.id` and not the other way around (`customers.order_id` referencing `orders.id`)? What would break if the FK were reversed?
