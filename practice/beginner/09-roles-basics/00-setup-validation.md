# Setup Validation: Roles Basics

Run each check after executing `setup.sql`. All checks must pass before starting exercises.

---

## Check 1: library_books table exists with data

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT id, title, author, available FROM library_books ORDER BY id;
"
```

**Expected output:**
```
 id |               title                |       author        | available
----+------------------------------------+---------------------+-----------
  1 | PostgreSQL: Up and Running         | Regina Obe          | t
  2 | The Art of PostgreSQL              | Dimitri Fontaine    | t
  3 | Database Design for Mere Mortals   | Michael Hernandez   | f
(3 rows)
```

---

## Check 2: Confirm cfp user has CREATEROLE privilege

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT rolname, rolsuper, rolcreaterole
  FROM pg_roles WHERE rolname = 'cfp';
"
```

**Expected output:**
```
 rolname | rolsuper | rolcreaterole
---------+----------+---------------
 cfp     | t        | t
```

If `rolsuper` or `rolcreaterole` is false, role creation in exercises will fail. The cfp user in the standard setup is a superuser.

---

## Check 3: No leftover practice roles from a previous run

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT rolname FROM pg_roles
  WHERE rolname IN ('lib_readonly', 'lib_agent')
  ORDER BY rolname;
"
```

**Expected output:**
```
(0 rows)
```

If roles already exist from a previous session, drop them before starting:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  DROP ROLE IF EXISTS lib_agent;
  DROP ROLE IF EXISTS lib_readonly;
"
```

---

## Setup passed

If all checks show expected output, setup is complete.
Open `exercises.md` and begin.
