# Troubleshooting — Practice 01: Basic SQL

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Error 1 — relation "books" does not exist

**Symptom:**
```
ERROR:  relation "books" does not exist
LINE 1: SELECT * FROM books;
```

**Cause:** `setup.sql` was not run, or was run against a different database.

**Fix:**
```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < practice/beginner/01-basic-sql/setup.sql
```

Then verify: `SELECT table_name FROM information_schema.tables WHERE table_name = 'books';`

---

## Error 2 — column does not exist

**Symptom:**
```
ERROR:  column "available" does not exist
```

**Cause:** Typo in column name, or running a query from a different exercise against a different table version.

**Fix:**
```sql
-- Check actual column names
SELECT column_name FROM information_schema.columns WHERE table_name = 'books';
-- Or in psql:
\d books
```

---

## Error 3 — syntax error at or near "="

**Symptom:**
```
ERROR:  syntax error at or near "="
LINE 1: WHERE available = TRUE
```

**Cause:** SQL keywords (TRUE, FALSE) are case-insensitive but must be unquoted. `'TRUE'` (string) is not the same as `TRUE` (boolean).

**Fix:**
```sql
WHERE available = true       -- correct
WHERE available = 'true'     -- wrong: comparing boolean to text
WHERE available              -- correct PostgreSQL shorthand
```

---

## Error 4 — INSERT violates not-null constraint

**Symptom:**
```
ERROR:  null value in column "title" of relation "books" violates not-null constraint
```

**Cause:** The `title` column is NOT NULL, but no value was provided.

**Fix:** Always supply values for NOT NULL columns that have no DEFAULT:
```sql
INSERT INTO books (title, author, year) VALUES ('My Book', 'Author Name', 2024);
-- 'available' has DEFAULT true, so it can be omitted
```

---

## Error 5 — duplicate key value violates unique constraint

**Symptom:**
```
ERROR:  duplicate key value violates unique constraint "books_pkey"
DETAIL:  Key (id)=(1) already exists.
```

**Cause:** Attempting to INSERT with an explicit `id` that already exists. Usually happens when re-running setup.sql manually with fixed IDs.

**Fix:** The setup.sql uses `ON CONFLICT (id) DO NOTHING` to handle this gracefully. If you see this error, you ran a custom INSERT. Either omit the `id` (let BIGSERIAL assign it) or use `ON CONFLICT DO NOTHING`.

---

## Error 6 — UPDATE with no WHERE clause

**Symptom:** No error — but every row in the table was updated.

**Cause:** `UPDATE books SET available = false;` without WHERE updates all rows.

**How to detect:** `RETURNING` shows all modified rows. If you see more rows than expected, a WHERE clause was missing.

**Fix:** Always include WHERE in UPDATE unless a full-table update is intentional. Use a transaction and ROLLBACK if you catch the mistake:
```sql
BEGIN;
UPDATE books SET available = false;  -- oops, no WHERE
-- Check damage:
SELECT COUNT(*) FROM books WHERE available = false;
ROLLBACK;  -- undo the change
```

---

## Error 7 — RETURNING not recognized

**Symptom:**
```
ERROR:  syntax error at or near "RETURNING"
```

**Cause:** The SQL client or driver does not support RETURNING (it is PostgreSQL-specific). Some ORMs strip it.

**Fix:** This only applies outside psql. In psql, RETURNING always works. If using an ORM, check whether the ORM wraps RETURNING correctly.

---

## Error 8 — Sequence out of sync after manual ID inserts

**Symptom:** After running setup.sql with explicit IDs (1-5), the next `INSERT INTO books (title, ...) VALUES (...)` tries to assign id=1 and fails with a duplicate key error.

**Cause:** The BIGSERIAL sequence was not advanced past the manually inserted IDs.

**Fix:** setup.sql includes `SELECT setval(...)` to fix this. If you see the error anyway:
```sql
SELECT setval(pg_get_serial_sequence('books', 'id'), (SELECT MAX(id) FROM books));
```
