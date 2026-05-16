# Solutions: JOINs and Aggregation

Level: Beginner

Read `exercises.md` and attempt each exercise before opening this file.

---

## Solution: Exercise 1 — INNER JOIN Books with Authors

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT b.title, a.name AS author
  FROM books b
  INNER JOIN authors a ON b.author_id = a.id
  ORDER BY a.name, b.title;
"
```

**Why this works:**
INNER JOIN matches each books row with the authors row where `books.author_id = authors.id`. The book with `author_id IS NULL` (Anonymous Classic) has no matching author row — INNER JOIN excludes it automatically. The result has exactly 13 rows.

**Key learning:** INNER JOIN = only rows with a match in both tables.

**Variation:** To also show the author's birth year: add `a.birth_year` to the SELECT list. No change to the JOIN is needed.

---

## Solution: Exercise 2 — LEFT JOIN All Books Including No-Author

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT b.title, COALESCE(a.name, 'Unknown') AS author_name
  FROM books b
  LEFT JOIN authors a ON b.author_id = a.id
  ORDER BY b.title;
"
```

**Why this works:**
LEFT JOIN keeps all rows from `books` (the left table). For book 14 (Anonymous Classic, author_id IS NULL), there is no matching authors row — PostgreSQL fills the authors columns with NULL. `COALESCE(a.name, 'Unknown')` converts NULL to the string 'Unknown'.

**Key learning:** LEFT JOIN = all left rows present; right columns are NULL when no match exists.

**Variation using CASE:**
```sql
CASE WHEN a.name IS NULL THEN 'Unknown' ELSE a.name END AS author_name
```

---

## Solution: Exercise 3 — Books Never Checked Out

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT b.id, b.title, COALESCE(a.name, 'Unknown') AS author_name
  FROM books b
  LEFT JOIN authors a ON b.author_id = a.id
  LEFT JOIN checkouts c ON c.book_id = b.id
  WHERE c.id IS NULL
  ORDER BY b.id;
"
```

**Why this works:**
Two LEFT JOINs: one to get the author name (same as exercise 2), one to find checkouts. For books with no checkout, every column from `checkouts` is NULL after the LEFT JOIN. `WHERE c.id IS NULL` keeps only those books.

**Key learning:** LEFT JOIN + IS NULL on the right table's PK is the standard pattern for "no matching record" (anti-join).

**NOT EXISTS alternative:**
```sql
SELECT b.id, b.title
FROM books b
WHERE NOT EXISTS (
    SELECT 1 FROM checkouts c WHERE c.book_id = b.id
);
```
Both approaches produce the same result. NOT EXISTS is sometimes more readable; LEFT JOIN + IS NULL can be combined with other JOINs more easily.

---

## Solution: Exercise 4 — GROUP BY + COUNT Checkouts per Author

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT a.name, COUNT(c.id) AS checkout_count
  FROM authors a
  INNER JOIN books b ON b.author_id = a.id
  INNER JOIN checkouts c ON c.book_id = b.id
  GROUP BY a.name
  ORDER BY checkout_count DESC, a.name ASC;
"
```

**Why this works:**
The query chains two INNER JOINs: authors → books → checkouts. After the joins, each row represents one checkout attributed to one author. GROUP BY `a.name` groups by author; COUNT(c.id) counts checkouts in each group.

**Key learning:** GROUP BY collapses many rows into one per group; aggregate functions summarize each group.

**Variation:** Use `GROUP BY a.id, a.name` instead of `GROUP BY a.name` to avoid grouping errors if two authors share the same name.

---

## Solution: Exercise 5 — HAVING Authors with More Than One Book

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT a.name, COUNT(b.id) AS book_count
  FROM authors a
  INNER JOIN books b ON b.author_id = a.id
  GROUP BY a.name
  HAVING COUNT(b.id) > 1
  ORDER BY book_count DESC, a.name;
"
```

**Why this works:**
GROUP BY groups rows by author. HAVING filters after grouping — it discards any group where the book count is 1 or fewer. WHERE cannot be used here because COUNT is not yet known at the WHERE stage (WHERE runs before GROUP BY).

**Key learning:** HAVING is the filter for groups; WHERE is the filter for rows.

**WHERE + HAVING combination:**
```sql
SELECT a.name, COUNT(b.id) AS book_count
FROM authors a
INNER JOIN books b ON b.author_id = a.id
WHERE b.published_year >= 1960      -- filter individual rows (before grouping)
GROUP BY a.name
HAVING COUNT(b.id) > 1             -- filter groups (after grouping)
ORDER BY book_count DESC;
```

---

## Solution: Exercise 6 (stretch) — Average Checkout Duration

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT
    b.title,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (c.returned_at - c.checked_out_at)) / 86400
    ), 1) AS avg_days
  FROM books b
  INNER JOIN checkouts c ON c.book_id = b.id
  WHERE c.returned_at IS NOT NULL
  GROUP BY b.title
  ORDER BY avg_days DESC;
"
```

**Why this works:**
`returned_at - checked_out_at` produces an INTERVAL. `EXTRACT(EPOCH FROM interval)` converts it to seconds. Dividing by 86400 gives days. `AVG` averages across all returned checkouts for each book. `ROUND(..., 1)` rounds to one decimal.

**Key learning:** Date arithmetic in PostgreSQL produces INTERVALs. EXTRACT(EPOCH FROM ...) converts to numeric seconds — then you can do arithmetic.

**Variation:** Include currently checked-out books using COALESCE:
```sql
AVG(EXTRACT(EPOCH FROM (COALESCE(c.returned_at, now()) - c.checked_out_at)) / 86400)
```
This includes still-checked-out books as if they were returned right now — useful for "how long has this book been out?" reports.
