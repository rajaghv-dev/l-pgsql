# Reflection: JOINs and Aggregation

Answer these questions after completing all exercises.
Write your answers in a scratch file or journal — they are for you, not for grading.

---

## Comprehension questions

1. In your own words, what is the difference between INNER JOIN and LEFT JOIN? Give a one-sentence answer for each.
2. What is the difference between WHERE and HAVING? Can they appear in the same query? In what order are they applied?
3. Why does `COUNT(*)` and `COUNT(column_name)` sometimes give different results? When would they differ in the exercises above?

---

## Design questions

1. The books table has 14 rows. If it grew to 10 million rows, which exercises would become slow first? What would you add to fix each one?
2. Exercise 4 groups by `a.name` (author name as text). A colleague says "just use `a.id`." They are right — why? Rewrite exercise 4 using `GROUP BY a.id` and include `a.name` in SELECT.
3. Exercise 3 finds books with no checkouts using LEFT JOIN. List two other ways to write the same query. Which would you choose for a production codebase, and why?

---

## Connection questions

1. How does the concept of INNER JOIN relate to the foreign key constraint you learned in `concepts/beginner/06-data-types-and-constraints.md`? (A FK constraint guarantees JOIN results are valid — explain this.)
2. Aggregation (lesson 11) and SELECT/filter (lesson 08) are separate concepts, but they appear in the same query. Draw the logical pipeline for exercise 4: what happens at each stage (FROM, JOIN, GROUP BY, SELECT, ORDER BY)?
3. You used `COALESCE` in exercises 2 and 3 to handle NULL author names. How does NULL propagation relate to the INNER vs LEFT JOIN distinction?

---

## Open questions

List any questions this session raised that you cannot yet answer:

- ...
- ...

Bring these to `concepts/beginner/12-indexes-as-shortcuts.md` (for performance questions) or `concepts/beginner/13-transactions-as-safe-change.md` (for concurrency questions), or search `references.md`.
