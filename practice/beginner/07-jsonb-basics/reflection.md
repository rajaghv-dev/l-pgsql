# Reflection: JSONB Basics

Answer these questions after completing all exercises.
Write your answers in a scratch file or journal — they are for you, not for grading.

---

## Comprehension questions

1. In your own words, what is the difference between `->` and `->>`? When would you use each?
2. What does the `@>` operator check? Can it be used with arrays? (Test: find users with the 'admin' tag.)
3. Why does JSONB require `jsonb_set()` for updates rather than direct key assignment?

---

## Design questions

1. You have a `user_profiles` table. Some users have a `location` field; others have a `preferences` field; most have both. Should you: (a) use JSONB for all of it, (b) use separate columns for known fields, (c) a mix? What drives your decision?
2. A colleague suggests storing all user data in JSONB: `id, jsonb` only. What is wrong with this approach? What do you lose compared to proper columns?
3. The GIN index on `metadata` helps `@>` and `?` but not `->>` comparisons. If your most common query is `WHERE metadata->>'plan' = 'pro'`, what index would you create?

---

## Connection questions

1. How does JSONB relate to transactions? If you `jsonb_set()` inside a transaction and then ROLLBACK, what happens to the JSONB change?
2. Compare JSONB to the `ltree` extension (lesson 17). When would you use `ltree` instead of a JSONB nested object for hierarchical data?
3. pgvector stores embeddings as a `vector` type. JSONB stores arbitrary JSON. Both are "flexible" column types. What is the key difference in how they are queried and indexed?

---

## Open questions

List any questions this session raised that you cannot yet answer:

- ...
- ...

Continue with:
- `practice/beginner/08-views-and-functions-basics/` — creating views over JSONB queries
- `concepts/beginner/17-extensions-as-capability-addons.md` — jsonb_path_ops, pg_trgm
