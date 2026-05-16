# Troubleshooting: JSONB Basics

Common errors encountered in this practice session and how to fix them.

---

## Error 1: `invalid input syntax for type json`

**Trigger:** Passing an invalid JSON string to a JSONB column or operator.

```sql
-- WRONG: single quotes inside JSON must be escaped, or use $$ quoting
WHERE metadata @> '{"plan": 'pro'}';  -- unbalanced quotes
```

**Cause:** JSON requires double quotes for strings. PostgreSQL SQL uses single quotes for string literals. When embedding JSON inside SQL strings, double quotes must be escaped as `\"` or you use dollar-quoting.

**Fix:**
```bash
# Option A: escape double quotes in the shell
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT username FROM user_profiles WHERE metadata @> '{\"plan\": \"pro\"}'::jsonb;
"

# Option B: use heredoc (no escaping needed)
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
SELECT username FROM user_profiles WHERE metadata @> '{"plan": "pro"}';
EOF
```

---

## Error 2: Wrong result — text comparison instead of numeric

**Symptom:** Query returns wrong rows. For example, users with age 9 appear when filtering `> '25'`.

**Cause:** `metadata->>'age'` returns text. Text comparison is lexicographic: '9' > '25' (because '9' > '2' as characters).

**Fix:** Always cast numeric JSONB values before comparing:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT username FROM user_profiles
  WHERE (metadata->>'age')::int > 25;
"
```

---

## Error 3: `@>` query does not use GIN index (still Seq Scan)

**Symptom:** EXPLAIN shows Seq Scan even after creating a GIN index.

**Cause (common):** With only 5 rows, the planner always prefers Seq Scan — the index overhead is not worth it. This is correct behavior.

**Cause (rare):** The index was created after the query was planned; run `ANALYZE user_profiles;` to update statistics.

**Diagnosis:**
```bash
# Confirm the index exists
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'user_profiles';
"
# Force index use (for testing only)
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SET enable_seqscan = off;
  EXPLAIN SELECT username FROM user_profiles WHERE metadata @> '{\"plan\": \"pro\"}'::jsonb;
  RESET enable_seqscan;
"
```

---

## Error 4: `jsonb_set` silently does nothing

**Symptom:** UPDATE runs without error, but the JSONB value does not change.

**Cause:** The path does not exist and the `create_missing` parameter (4th arg) is `false` (default).

**Fix:**
```bash
# Pass true as the 4th argument to create the path if missing
docker exec cfp_postgres psql -U cfp -d cfp -c "
  UPDATE user_profiles
  SET metadata = jsonb_set(metadata, '{new_key}', '\"value\"', true)
  WHERE username = 'alice'
  RETURNING metadata->>'new_key';
"
```

---

## Error 5: `||` overwrites a key unexpectedly

**Symptom:** Merging JSONB with `||` loses an existing key.

**Cause:** If both left and right JSONB have the same top-level key, the right value wins. This is by design.

**Example:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT '{\"a\": 1}' || '{\"a\": 2}'::jsonb;
  -- Result: {\"a\": 2} — the 1 is overwritten
"
```

**Fix:** Use `jsonb_set` to update specific nested keys without risk of overwriting others. Only use `||` when you are certain about which keys you are adding.

---

## Setup troubleshooting

**Problem:** `relation "user_profiles" does not exist`
**Fix:** Re-run setup.sql:
```bash
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/07-jsonb-basics/setup.sql
```

**Problem:** Container is not running
**Fix:**
```bash
docker compose -f /mnt/d/wsl/l-pgsql/tools/dashboards/docker-compose.yml up -d cfp_postgres
```
