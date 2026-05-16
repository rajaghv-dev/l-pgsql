# Reflection: Views and Functions Basics

Answer these questions after completing all exercises.
Write your answers in a scratch file or journal — they are for you, not for grading.

---

## Comprehension questions

1. In your own words: what is the difference between a VIEW and a MATERIALIZED VIEW? Give a one-sentence answer for each.
2. What is `LANGUAGE sql` in a function definition? What other language options exist in PostgreSQL? (Hint: look at pg_language.)
3. The `days_overdue()` function is marked `STABLE`. What does STABLE mean, and why not IMMUTABLE?

---

## Design questions

1. You have a view `active_checkouts` that 5 different services query. One day you need to add a `checkout_fee` column to the result. What are the steps to do this without breaking the 5 services?
2. Your `overdue_checkouts` view calls `days_overdue()` twice per row (once in WHERE, once in SELECT). On a table with 1 million checkouts, this matters. Rewrite the view to call the function only once. (Hint: subquery or CTE.)
3. A colleague wants to grant agents access to the database by giving them SELECT on all tables. You suggest using views instead. Write out the argument for why views are better for agent access control.

---

## Connection questions

1. How do views relate to roles and permissions (lesson 16)? What is the minimum set of permissions needed to query a view? (Hint: does the agent need SELECT on the base tables, or just on the view?)
2. A function marked `IMMUTABLE` can be used in an index expression (`CREATE INDEX ... ON books (LOWER(title))`). Why can't a `STABLE` function be used the same way?
3. How does a view behave inside a transaction? If you INSERT a new book, and then immediately SELECT from `available_books` in the same transaction, does the new book appear?

---

## Open questions

List any questions this session raised that you cannot yet answer:

- ...
- ...

Continue with:
- `practice/beginner/09-roles-basics/` — grant VIEW access to an agent role
- `concepts/beginner/18-full-text-search-intuition.md` — add FTS to a view's query
