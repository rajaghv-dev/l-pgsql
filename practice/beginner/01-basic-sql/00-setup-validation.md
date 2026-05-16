# Setup Validation — Practice 01: Basic SQL

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Step 1 — Run setup.sql

```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < practice/beginner/01-basic-sql/setup.sql
```

The final `SELECT` in setup.sql should produce 5 rows.

---

## Step 2 — Confirm table exists

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'books';
```

Expected: one row with `table_name = books`.

---

## Step 3 — Confirm columns

```sql
SELECT column_name, data_type, is_nullable, column_default
FROM   information_schema.columns
WHERE  table_name = 'books'
ORDER  BY ordinal_position;
```

Expected columns:
```
 column_name | data_type         | is_nullable | column_default
-------------+-------------------+-------------+---------------------
 id          | bigint            | NO          | nextval(...)
 title       | text              | NO          |
 author      | text              | NO          |
 year        | integer           | NO          |
 available   | boolean           | NO          | true
```

---

## Step 4 — Confirm row count

```sql
SELECT COUNT(*) FROM books;
```

Expected: `5`

---

## Step 5 — Confirm seed data

```sql
SELECT id, title, available FROM books ORDER BY id;
```

Expected:
```
 id │ title            │ available
────┼──────────────────┼──────────
  1 │ Dune             │ t
  2 │ Neuromancer      │ t
  3 │ Foundation       │ f
  4 │ 1984             │ t
  5 │ Brave New World  │ f
```

---

## Checklist

- [ ] `setup.sql` ran without errors
- [ ] `books` table exists in `public` schema
- [ ] 5 columns with correct types
- [ ] 5 rows present
- [ ] `available` defaults to `true`
