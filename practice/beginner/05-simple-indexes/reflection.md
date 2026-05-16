# Reflection: Simple Indexes

Answer these questions after completing all exercises.
Write your answers in a scratch file or journal — they are for you, not for grading.

---

## Comprehension questions

1. What is the difference between `EXPLAIN` and `EXPLAIN ANALYZE`? When would you use each?
2. Why does PostgreSQL sometimes choose a sequential scan even when an index exists?
3. What is the "leftmost prefix rule" for composite indexes? Give an example of a query that would and would not use the index `(category, price)`.

---

## Design questions

1. You have a table with 50,000 products. You add 5 indexes. Later, you benchmark INSERT performance and find it is 3× slower than before. Which indexes would you consider dropping first, and how would you decide?
2. A colleague wants to add an index on the `name` column (free-text product names like "Product 1234"). Is this a good idea for the query `WHERE name LIKE 'Product%'`? What about `WHERE name LIKE '%1234'`? Why the difference?
3. You need fast lookups on `sku` AND occasional range queries on `price`. Would you create one composite index or two separate indexes? Explain your reasoning.

---

## Connection questions

1. Indexes are used by JOIN operations too. Look at the `04-joins-and-aggregation` setup — which JOIN columns in that practice session have indexes? Which do not? What would you add?
2. The partial index in exercise 5 only covers `in_stock = false`. What would happen to the query `WHERE in_stock = false AND price < 50.00` — would it use the partial index?
3. How do indexes relate to the concept of a transaction? When you INSERT a row inside a transaction, what happens to the index?

---

## Open questions

List any questions this session raised that you cannot yet answer:

- ...
- ...

Continue with:
- `concepts/beginner/13-transactions-as-safe-change.md` — how index updates interact with transactions
- `Use The Index, Luke` (https://use-the-index-luke.com/) — deep dive into index internals
