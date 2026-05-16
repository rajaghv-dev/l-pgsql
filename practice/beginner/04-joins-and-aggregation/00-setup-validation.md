# Setup Validation: JOINs and Aggregation

Run each check after executing `setup.sql`. All checks must pass before starting exercises.

---

## Check 1: All three tables exist

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name IN ('authors', 'books', 'checkouts')
  ORDER BY table_name;
"
```

**Expected output:**
```
 table_name
------------
 authors
 books
 checkouts
(3 rows)
```

**Common error:** Missing tables — setup.sql did not complete. Check for error output from the `docker exec` run.
**Ontology note:** Three tables = three relations. The FK columns (books.author_id, checkouts.book_id) make them a joined schema. `[[foreign-key]]` → `[[join]]`

---

## Check 2: Row counts

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT 'authors' AS tbl, COUNT(*) FROM authors
  UNION ALL
  SELECT 'books', COUNT(*) FROM books
  UNION ALL
  SELECT 'checkouts', COUNT(*) FROM checkouts;
"
```

**Expected output:**
```
   tbl    | count
----------+-------
 authors  |     6
 books    |    14
 checkouts|    14
```

**Common error:** `0 rows` in any table — INSERT block failed. Check for constraint violations in setup.sql output.

---

## Check 3: NULL author_id row exists (for LEFT JOIN exercise)

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT id, title, author_id FROM books WHERE author_id IS NULL;
"
```

**Expected output:**
```
 id |      title       | author_id
----+------------------+-----------
 14 | Anonymous Classic|
(1 row)
```

**Why this exists:** Exercise 2 uses LEFT JOIN to include books with no matching author. This row triggers the NULL case.

---

## Check 4: Books with no checkouts exist (for LEFT JOIN exercise)

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT b.id, b.title
  FROM books b
  LEFT JOIN checkouts c ON c.book_id = b.id
  WHERE c.id IS NULL
  ORDER BY b.id;
"
```

**Expected output:**
```
 id |          title
----+-------------------------
  9 | Rendezvous with Rama
 11 | The Man in the High Castle
 14 | Anonymous Classic
(3 rows)
```

**Why this exists:** Exercise 3 asks learners to find these books independently.

---

## Setup passed

If all checks above show expected output, setup is complete.
Open `exercises.md` and begin.
