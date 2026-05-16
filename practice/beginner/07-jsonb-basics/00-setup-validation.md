# Setup Validation: JSONB Basics

Run each check after executing `setup.sql`. All checks must pass before starting exercises.

---

## Check 1: Table exists with JSONB column

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "\d user_profiles"
```

**Expected output:**
```
                Table "public.user_profiles"
  Column  |  Type   | ...
----------+---------+----
 id       | integer |
 username | text    |
 metadata | jsonb   |
```

**Ontology note:** `metadata jsonb` is a column that stores a full JSON document per row. Each row can have a different JSON structure inside this column. `[[jsonb]]` → `[[semi-structured-data]]`

---

## Check 2: Row count and JSONB content

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT id, username, jsonb_pretty(metadata)
  FROM user_profiles
  ORDER BY id;
"
```

**Expected output (abbreviated):**
```
 id | username |        jsonb_pretty
----+----------+-----------------------------
  1 | alice    | {                          +
    |          |     "age": 29,             +
    |          |     "plan": "pro",         +
    |          |     "tags": [...]          +
    |          | }
...
(5 rows)
```

**Common error:** 0 rows — INSERT in setup.sql failed. Check for JSON syntax errors in the seed data.

---

## Check 3: JSONB operators work

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT username, metadata->>'plan' AS plan
  FROM user_profiles
  ORDER BY username;
"
```

**Expected output:**
```
 username |    plan
----------+------------
 alice    | pro
 bob      | free
 charlie  | pro
 diana    | enterprise
 eve      | free
```

---

## Setup passed

If all checks show expected output, setup is complete.
Open `exercises.md` and begin.
