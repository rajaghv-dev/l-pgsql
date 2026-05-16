# Reflection: Roles Basics

Answer these questions after completing all exercises.
Write your answers in a scratch file or journal — they are for you, not for grading.

---

## Comprehension questions

1. What is the difference between a group role and a login role in PostgreSQL? Can a role be both?
2. Why are three separate GRANTs needed (CONNECT, USAGE, SELECT) for a role to read a table?
3. What does `rolinherit = t` mean? What would `rolinherit = f` require the role to do differently?

---

## Design questions

1. Your application has two types of agents:
   - `search_agent`: can only SELECT from `products` and `categories`
   - `order_agent`: can SELECT from `products` and INSERT into `orders`
   
   Design the role hierarchy (group roles + login roles) for these two agents. Write the CREATE ROLE and GRANT statements.

2. A security audit finds that your application role has `SUPERUSER` in production (inherited from the initial setup). List the steps to safely migrate to least-privilege roles without downtime.

3. You want to ensure that new tables created in the future are automatically readable by `lib_readonly`. What `ALTER DEFAULT PRIVILEGES` statement would you use?

---

## Connection questions

1. How do roles relate to views (lesson 15)? If a role has SELECT on a view but not on the base table, can it read the data? Why?
2. In the context of pgvector and semantic search (lesson 19): what is the minimum privilege an agent needs to run a vector similarity query (`SELECT ... ORDER BY embedding <-> query_vec LIMIT 5`)?
3. If you add Row-Level Security (RLS) to `library_books` so each patron can only see their own checkouts, how does that interact with `lib_readonly`'s SELECT privilege?

---

## Open questions

List any questions this session raised that you cannot yet answer:

- ...
- ...

Continue with:
- `concepts/beginner/20-ontology-for-database-learning.md` — synthesize everything into a concept map
- `concepts/intermediate/` (future) — Row-Level Security, pg_hba.conf, pgBouncer connection pooling
