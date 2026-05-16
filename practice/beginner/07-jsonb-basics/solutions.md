# Solutions: JSONB Basics

Level: Beginner

Read `exercises.md` and attempt the exercises before opening this file.

---

## Solution: Exercise 1 — `->` vs `->>`

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT username,
         metadata->'age'         AS age_jsonb,
         metadata->>'age'        AS age_text,
         pg_typeof(metadata->'age')   AS jsonb_type,
         pg_typeof(metadata->>'age')  AS text_type
  FROM user_profiles
  ORDER BY username;
"
```

**Output:**
```
 username | age_jsonb | age_text | jsonb_type | text_type
----------+-----------+----------+------------+-----------
 alice    | 29        | 29       | jsonb      | text
...
```

**Why this works:** `->` returns a JSONB value (the number `29` as a JSONB integer). `->>'` casts it to text ('29' as a string). `pg_typeof()` reveals the runtime type.

**Filter with cast:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT username, (metadata->>'age')::int AS age
  FROM user_profiles
  WHERE (metadata->>'age')::int > 25
  ORDER BY age DESC;
"
```

**Key learning:** Always cast when comparing JSONB text values numerically. Text comparison `'9' > '29'` is true (alphabetical); numeric comparison `9 > 29` is false (correct).

---

## Solution: Exercise 2 — `@>` Containment

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT username FROM user_profiles
  WHERE metadata @> '{\"plan\": \"pro\"}'::jsonb;
"
```

**Output:**
```
 username
----------
 alice
 charlie
```

**Find users with 'admin' tag:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT username FROM user_profiles
  WHERE metadata @> '{\"tags\": [\"admin\"]}'::jsonb;
"
```

**Key learning:** `@>` checks if the left JSONB contains all key-value pairs of the right JSONB. For arrays, it checks if the left array contains all elements of the right array. This is the GIN-indexable containment check.

---

## Solution: Exercise 3 — Update with `jsonb_set`

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  UPDATE user_profiles
  SET metadata = jsonb_set(metadata, '{age}', '30')
  WHERE username = 'alice'
  RETURNING username, metadata->>'age' AS new_age;
"
```

**Output:**
```
 username | new_age
----------+---------
 alice    | 30
```

**Add a new key (create if missing):**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  UPDATE user_profiles
  SET metadata = jsonb_set(metadata, '{premium}', 'true', true)
  WHERE username = 'bob'
  RETURNING username, metadata->>'premium' AS premium;
"
```

**Key learning:** `jsonb_set(jsonb, path, new_value, create_missing)` — the fourth argument defaults to false (do not create). Set it to true to add new keys. The path is an array of text keys: `'{key}'` for top-level, `'{parent,child}'` for nested.

---

## Solution: Exercise 4 — GIN Index

```bash
# Before
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT username FROM user_profiles WHERE metadata @> '{\"plan\": \"pro\"}'::jsonb;
"

# Create
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE INDEX idx_profiles_metadata ON user_profiles USING GIN (metadata);
"

# After
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN SELECT username FROM user_profiles WHERE metadata @> '{\"plan\": \"pro\"}'::jsonb;
"
```

**Key learning:** GIN indexes are inverted indexes — they map JSONB keys and values to the rows that contain them. A containment check (`@>`) becomes a GIN lookup instead of a full table scan. On small tables (5 rows), the planner may still choose Seq Scan — this is correct since the overhead of the index is not worth it for tiny tables.

**Reduced-size index option:**
```bash
# jsonb_path_ops: smaller index, only supports @>
docker exec cfp_postgres psql -U cfp -d cfp -c "
  DROP INDEX IF EXISTS idx_profiles_metadata;
  CREATE INDEX idx_profiles_metadata ON user_profiles
    USING GIN (metadata jsonb_path_ops);
"
```

---

## Solution: Exercise 5 — `jsonb_each`

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT u.username, k.key, k.value
  FROM user_profiles u,
       jsonb_each(u.metadata) AS k
  ORDER BY u.username, k.key;
"
```

**Key learning:** `jsonb_each()` is a set-returning function (SRF). Using it in the FROM clause (lateral join style) expands each JSONB object into one row per key-value pair. This is useful for schema inspection, pivot queries, and EAV-style dynamic queries.

---

## Solution: Exercise 6 (stretch) — Merge with `||`

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  UPDATE user_profiles
  SET metadata = metadata || '{\"verified\": true, \"signup_method\": \"email\"}'::jsonb
  WHERE username = 'charlie'
  RETURNING username, jsonb_pretty(metadata);
"
```

**Key learning:** `||` merges two JSONB objects at the top level. If the right operand has a key that the left operand also has, the right operand's value wins. This is the idiomatic "add multiple keys" pattern. For nested merges, you need recursive logic or `jsonb_set` per key.
