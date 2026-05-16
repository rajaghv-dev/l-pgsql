# Reflection: Simple Transactions

Answer these questions after completing all exercises.
Write your answers in a scratch file or journal — they are for you, not for grading.

---

## Comprehension questions

1. In your own words, what does "atomicity" mean? Give a one-sentence definition, then give an example from the exercises.
2. What is the difference between ROLLBACK and ROLLBACK TO SAVEPOINT?
3. What does "auto-commit" mean? If you run a single UPDATE without BEGIN, is it wrapped in a transaction?

---

## Design questions

1. You are building a checkout system. A single "place order" operation must:
   - Deduct stock from inventory
   - Create an order record
   - Charge the customer's balance
   
   How would you structure these three operations in PostgreSQL? What happens if the third step fails?

2. A colleague says "we don't need transactions — our writes are simple." They mean: each endpoint only writes to one table. Are they correct? What scenario could still go wrong?

3. Long transactions hold locks. A report takes 5 minutes to run inside a transaction. During that time, a routine VACUUM cannot reclaim space because the transaction is holding an old snapshot. How would you avoid this?

---

## Connection questions

1. How do transactions relate to the CHECK constraint on `bank_accounts.balance >= 0`? What happens to the transaction when the CHECK fires?
2. Exercise 4 demonstrates READ COMMITTED isolation. How would the behavior change if you used SERIALIZABLE? When would you choose SERIALIZABLE in a real application?
3. How do transactions interact with indexes? When you UPDATE a row inside a transaction (before COMMIT), is the index also updated? Can another session use the index to find the updated row?

---

## Open questions

List any questions this session raised that you cannot yet answer:

- ...
- ...

Continue with:
- `concepts/beginner/14-jsonb-as-flexible-data.md` — flexible data in transactions
- `concepts/intermediate/` (future) — MVCC internals, SELECT FOR UPDATE, advisory locks
