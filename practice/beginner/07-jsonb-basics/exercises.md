# Exercises: JSONB Basics

Level: Beginner

Work through each exercise in order. Do not look at `solutions.md` until you have tried.

---

## Exercise 1: Extract JSONB Values — `->` vs `->>`

**Goal:** Understand the difference between `->` (returns JSONB) and `->>` (returns text).

**First-principles question:** Why does it matter whether the return type is JSONB or text? When would you need one vs the other?

**Task:**
1. Use `->` to extract the `age` field from `metadata`. What type does it return?
2. Use `->>` to extract the `age` field. What type does it return?
3. Try to compare the `->` result to an integer: `metadata->'age' = 29`. Does it work?
4. Try to cast the `->>` result to integer: `(metadata->>'age')::int > 25`.

**Commands:**
```bash
# What type does -> return?
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT username,
         metadata->'age'       AS age_jsonb,
         metadata->>'age'      AS age_text,
         pg_typeof(metadata->'age') AS jsonb_type,
         pg_typeof(metadata->>'age') AS text_type
  FROM user_profiles;
"

# Filter by age using cast
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT username, (metadata->>'age')::int AS age
  FROM user_profiles
  WHERE (metadata->>'age')::int > 25
  ORDER BY age DESC;
"
```

**Expected result (filter query):**
```
 username | age
----------+-----
 diana    |  41
 bob      |  34
 alice    |  29
 eve      |  27
```

**Critical-thinking question:** `metadata->'age'` returns JSONB integer `29`. `metadata->>'age'` returns text `'29'`. If you compare `metadata->>'age' > '9'`, the comparison is alphabetical (text), not numeric. '9' > '29' alphabetically. Why is this dangerous and how do you prevent it?

**Creative-thinking question:** Can you select the `city` from a nested object? Try: `metadata->'location'->>'city'`. Chain `->` for JSONB navigation, then `->>`  at the end for text output.

**What this teaches:** `->` navigates the JSON tree (result is JSONB); `->>` returns the leaf value as text. Always cast to the correct type when comparing or computing.

---

## Exercise 2: Filter with `@>` (Containment Operator)

**Goal:** Use the `@>` operator to find users whose metadata contains a specific value.

**First-principles question:** What does "containment" mean for JSONB? How is it different from `metadata->>'plan' = 'pro'`?

**Task:** Find all users whose metadata contains `{"plan": "pro"}` using the `@>` operator.

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT username, metadata->>'plan' AS plan
  FROM user_profiles
  WHERE metadata @> '{\"plan\": \"pro\"}';
"
```

Or using `$` quoting to avoid escaping:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT username, metadata->>'plan' AS plan
  FROM user_profiles
  WHERE metadata @> '{\"plan\": \"pro\"}'::jsonb;
"
```

**Expected result:**
```
 username | plan
----------+------
 alice    | pro
 charlie  | pro
```

**Critical-thinking question:** Could you also write `WHERE metadata->>'plan' = 'pro'`? Yes. When would `@>` be preferred? (Hint: `@>` uses the GIN index; `->>'plan' = 'pro'` does not — it requires a B-tree expression index.)

**Creative-thinking question:** Use `@>` to find users who have the 'admin' tag. (Hint: `metadata @> '{"tags": ["admin"]}'`.)

**Agent/MCP angle:**
- Agent scenario: A permission-checking agent verifies if a user has the 'admin' tag before allowing an action.
- MCP tool name: `check_user_tag`
- Tool input: `{ "username": "alice", "tag": "admin" }`
- PostgreSQL operation: `WHERE username = $1 AND metadata @> jsonb_build_object('tags', jsonb_build_array($2))`
- Required permission: `SELECT` on `user_profiles`

**What this teaches:** `@>` is the JSONB containment check — "does this document contain this sub-document?" It supports GIN index acceleration.

---

## Exercise 3: Update a Nested JSONB Key

**Goal:** Use `jsonb_set()` to update a nested value inside the JSONB column.

**First-principles question:** Why is `jsonb_set()` needed instead of a direct assignment like `SET metadata->'age' = 30`?

**Task:** Update Alice's age from 29 to 30 using `jsonb_set()`.

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  UPDATE user_profiles
  SET metadata = jsonb_set(metadata, '{age}', '30')
  WHERE username = 'alice'
  RETURNING username, metadata->>'age' AS new_age;
"
```

**Expected result:**
```
 username | new_age
----------+---------
 alice    | 30
```

**Critical-thinking question:** `jsonb_set(metadata, '{age}', '30')` replaces the entire metadata column with a new JSONB value (with the age changed). This means every UPDATE to a JSONB field rewrites the entire column value for that row. How might this affect performance for very large JSONB documents?

**Creative-thinking question:** Add a new key `premium` (set to `true`) to Bob's metadata, creating the key if it does not exist. (Hint: `jsonb_set(metadata, '{premium}', 'true', true)` — the fourth argument `true` means "create if missing".)

**What this teaches:** JSONB is immutable — you cannot update a key in-place. `jsonb_set()` returns a new JSONB value with the key changed; UPDATE replaces the column with this new value.

---

## Exercise 4: Add and Query a GIN Index

**Goal:** Create a GIN index on the `metadata` column and verify it speeds up `@>` queries.

**First-principles question:** A GIN index is an "inverted index." What does inverted mean in this context? (Hint: it maps JSONB keys/values to the rows that contain them.)

**Task:**
1. Run EXPLAIN on a `@>` query — note the plan (Seq Scan expected).
2. Create a GIN index on `metadata`.
3. Run EXPLAIN again — verify the plan changes.

**Commands:**
```bash
# Before GIN index
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT username FROM user_profiles WHERE metadata @> '{\"plan\": \"pro\"}';
"

# Create GIN index
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE INDEX idx_profiles_metadata ON user_profiles USING GIN (metadata);
"

# After GIN index
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT username FROM user_profiles WHERE metadata @> '{\"plan\": \"pro\"}';
"
```

**Expected plan change:**

Before:
```
 Seq Scan on user_profiles  (cost=...)
   Filter: (metadata @> '{"plan": "pro"}')
```

After:
```
 Bitmap Heap Scan on user_profiles (cost=...)
   Recheck Cond: (metadata @> '{"plan": "pro"}')
   ->  Bitmap Index Scan on idx_profiles_metadata (cost=...)
```

Note: With only 5 rows, the planner may still prefer Seq Scan (the table is tiny). This is expected — to see the index used, you would need thousands of rows. The index structure is correct either way.

**Critical-thinking question:** The GIN index only helps operators that it supports: `@>`, `?`, `?|`, `?&`. It does NOT help `metadata->>'plan' = 'pro'`. Why? (Because `->>` extracts text and compares with =; the GIN index is on the JSONB structure, not on extracted text values.)

**Systems-thinking question:** A table with 1 million user profiles — all using JSONB for preferences. The GIN index is large because it indexes every key-value pair in every document. How would you reduce the index size? (Hint: `jsonb_path_ops` operator class — indexes only containment paths, not key existence.)

**What this teaches:** GIN indexes enable fast JSONB `@>`, `?`, and related operators. Without a GIN index, these queries are sequential scans.

---

## Exercise 5: Expand JSONB to Rows with `jsonb_each`

**Goal:** Use `jsonb_each()` to expand a JSONB object into key-value rows.

**Task:** For each user profile, expand the top-level JSONB keys into separate rows. Show username, key name, and value.

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT u.username, k.key, k.value
  FROM user_profiles u,
       jsonb_each(u.metadata) AS k
  ORDER BY u.username, k.key;
"
```

**Expected result (partial):**
```
 username |    key      |          value
----------+-------------+--------------------------
 alice    | age         | 29
 alice    | location    | {"city": "London", ...}
 alice    | plan        | \"pro\"
 alice    | tags        | ["admin", "beta"]
 bob      | age         | 34
...
```

**Critical-thinking question:** `jsonb_each` returns one row per top-level key. Nested objects (like `location`) appear as a single JSONB value. How would you also expand nested objects? (Hint: `jsonb_each` recursively on the nested value, or use SQL/JSON path functions.)

**What this teaches:** `jsonb_each()` is a set-returning function that turns a JSONB object into rows — useful for schema discovery and pivot-style reports.

---

## Exercise 6 (stretch): Merge JSONB Objects with `||`

**Goal:** Add new keys to a JSONB document using the merge operator `||`.

**Difficulty:** Stretch — only attempt after completing exercises 1–5.

**Task:** Add a `{"verified": true, "signup_method": "email"}` object to Charlie's metadata using `||`. Verify the result.

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  UPDATE user_profiles
  SET metadata = metadata || '{\"verified\": true, \"signup_method\": \"email\"}'::jsonb
  WHERE username = 'charlie'
  RETURNING username, jsonb_pretty(metadata);
"
```

**What this teaches:** The `||` operator merges two JSONB objects. Top-level keys from the right operand overwrite keys from the left if they share the same name. This is the idiomatic way to add multiple new keys at once.
