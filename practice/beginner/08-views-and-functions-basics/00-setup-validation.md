# Setup Validation: Views and Functions Basics

Run each check after executing `setup.sql`. All checks must pass before starting exercises.

---

## Check 1: Tables and views exist

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT table_name, table_type
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name IN ('books', 'checkouts', 'available_books', 'active_checkouts')
  ORDER BY table_name;
"
```

**Expected output:**
```
    table_name    | table_type
------------------+------------
 active_checkouts | VIEW
 available_books  | VIEW
 books            | BASE TABLE
 checkouts        | BASE TABLE
(4 rows)
```

**Ontology note:** Views appear alongside base tables in `information_schema.tables`. PostgreSQL treats views as named relations — they can be queried with the same SELECT syntax. `[[view]]` → `[[derived-relation]]`

---

## Check 2: Function exists

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT routine_name, routine_type, data_type
  FROM information_schema.routines
  WHERE routine_schema = 'public' AND routine_name = 'days_overdue';
"
```

**Expected output:**
```
 routine_name | routine_type | data_type
--------------+--------------+-----------
 days_overdue | FUNCTION     | integer
(1 row)
```

---

## Check 3: View and function return correct data

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT patron_name, title, due_date, days_overdue(due_date) AS days_overdue
  FROM active_checkouts
  ORDER BY due_date;
"
```

**Expected output (dates relative to 2026-05-16):**
```
 patron_name |               title                |  due_date  | days_overdue
-------------+------------------------------------+------------+--------------
 Bob         | The Pragmatic Programmer           | 2026-05-04 |           12
 Charlie     | Designing Data-Intensive Apps      | 2026-04-24 |           22
 Eve         | Thinking, Fast and Slow            | 2026-05-15 |            1
```

(Exact values depend on current date — `days_overdue` is computed at query time.)

---

## Setup passed

If all checks show expected output, setup is complete.
Open `exercises.md` and begin.
