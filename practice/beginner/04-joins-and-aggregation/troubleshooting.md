# Troubleshooting: JOINs and Aggregation

Common errors encountered in this practice session and how to fix them.

---

## Error 1: `column "title" must appear in the GROUP BY clause or be used in an aggregate function`

**Trigger:** Selecting a non-grouped, non-aggregated column alongside a GROUP BY.

```sql
-- WRONG: title is not in GROUP BY and not aggregated
SELECT author_id, title, COUNT(*) FROM books GROUP BY author_id;
```

**Cause:** PostgreSQL enforces that every SELECT column must either be in the GROUP BY list or wrapped in an aggregate function. Without this, one value would be chosen arbitrarily from the group — PostgreSQL refuses to do this silently.

**Fix:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  -- Option A: add title to GROUP BY (changes meaning — groups by both)
  SELECT author_id, title, COUNT(*) FROM books GROUP BY author_id, title;

  -- Option B: aggregate title
  SELECT author_id, STRING_AGG(title, ', ') AS titles, COUNT(*) FROM books GROUP BY author_id;
"
```

**Prevention:** After writing GROUP BY, check every SELECT column: is it in GROUP BY? Is it wrapped in an aggregate? If neither, add it to GROUP BY or remove it.

---

## Error 2: `WHERE clause cannot contain aggregate functions`

**Trigger:** Using COUNT or other aggregates in WHERE instead of HAVING.

```sql
-- WRONG
SELECT author_id, COUNT(*) FROM books WHERE COUNT(*) > 1 GROUP BY author_id;
```

**Cause:** WHERE runs before GROUP BY. Aggregate functions are not computed until after GROUP BY. At WHERE time, there are no groups and no aggregates.

**Fix:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT author_id, COUNT(*) FROM books GROUP BY author_id HAVING COUNT(*) > 1;
"
```

**Prevention:** Remember the logical order: FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY. Aggregates belong in HAVING (for filter) or SELECT (for output).

---

## Error 3: LEFT JOIN returns duplicate rows

**Symptom:** A query that you expect to return 14 rows (one per book) returns 28 or more.

**Cause:** A book has multiple checkouts. LEFT JOIN produces one row per matching checkout — so a book with 3 checkouts appears 3 times.

**Example:**
```sql
-- This returns 14 rows (not 14 books — 14 checkouts)
SELECT b.title, c.patron_id
FROM books b
LEFT JOIN checkouts c ON c.book_id = b.id;
```

**Fix:** Decide what you actually want:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  -- Count checkouts per book (not one row per checkout)
  SELECT b.title, COUNT(c.id) AS checkout_count
  FROM books b
  LEFT JOIN checkouts c ON c.book_id = b.id
  GROUP BY b.title
  ORDER BY checkout_count DESC;
"
```

**Prevention:** Understand the cardinality of your JOIN before writing it. If books:checkouts is 1:many, the JOIN produces many rows per book. Always verify row counts with a SELECT COUNT(*) first.

---

## Error 4: Silent wrong result — NULL author appears in INNER JOIN count

**Symptom:** `COUNT(*) FROM books` returns 14, but `COUNT(*) FROM books INNER JOIN authors ON ...` returns 13. No error — just a different count.

**Cause:** This is correct behavior, not a bug. INNER JOIN excludes the book with `author_id IS NULL` because NULL never equals anything. The count decrease is intentional.

**Diagnosis query:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT COUNT(*) AS total_books FROM books;
  SELECT COUNT(*) AS books_with_author FROM books WHERE author_id IS NOT NULL;
"
```

**Fix:** If you want all 14 books (including no-author), use LEFT JOIN. If you want only books with a known author, INNER JOIN is correct.

---

## Setup troubleshooting

**Problem:** `setup.sql` fails with `foreign key violation`
**Fix:** Run the DROP TABLE CASCADE block first:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  DROP TABLE IF EXISTS checkouts CASCADE;
  DROP TABLE IF EXISTS books CASCADE;
  DROP TABLE IF EXISTS authors CASCADE;
"
```
Then re-run setup.sql.

**Problem:** `relation "books" does not exist`
**Fix:** setup.sql did not run successfully. Re-run it and watch for errors:
```bash
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/04-joins-and-aggregation/setup.sql
```

**Problem:** Container is not running
**Fix:**
```bash
docker ps | grep cfp_postgres
docker compose -f /mnt/d/wsl/l-pgsql/tools/dashboards/docker-compose.yml up -d cfp_postgres
```
