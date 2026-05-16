# Reflection — Indexing Strategies

---

## 1. The right index for the right query

After completing all exercises, you have 5+ indexes on `idx_events`. For each one, write one sentence explaining exactly which query pattern it serves and what it would cost to remove it.

---

## 2. Write overhead

Every index you add makes INSERTs and UPDATEs slower. If `idx_events` were receiving 10,000 new rows per second (a moderate event stream), estimate the write overhead of having:
- 1 index (PK only)
- 5 indexes (as in this exercise)
- 10 indexes

How would you decide which indexes to keep for a high-write event stream?

---

## 3. BRIN vs. B-tree trade-off

You observed that BRIN is dramatically smaller than B-tree for the timestamp column. When would you choose B-tree over BRIN despite the size difference? Think about:
- Data that is inserted out-of-time order
- Queries that need to find a specific narrow time range (< 1 minute) in a 1-billion-row table

---

## 4. The invisible cost of GIN

GIN indexes are large and slower to update than B-tree. If your JSONB payloads are updated frequently (e.g., a `status` field inside the JSON is updated for each event), what happens to the GIN index? What PostgreSQL mechanism deals with this?

Hint: look up "GIN pending list" in the PostgreSQL docs.

---

## 5. Expression index — when is it a trap?

Suppose you create `CREATE INDEX ON idx_events (LOWER(user_email))` but all your queries use `WHERE user_email ILIKE 'User_42@example.com'`. Does the expression index help? Why or why not?

What pattern of application code would make an expression index valuable vs. useless?

---

## 6. Index-only scan conditions

An Index Only Scan requires the visibility map to be current. What happens to Index Only Scan performance after a large UPDATE that touches many rows but no VACUUM has run?

What autovacuum setting would you tune to keep the visibility map current for a heavily-updated table?

---

## 7. The "no unused index" rule

Some teams enforce a rule: "drop any index where `idx_scan = 0` after 30 days of production traffic." What are the risks of this rule applied blindly? When would it be wrong to drop a `idx_scan = 0` index?
