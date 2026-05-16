# Troubleshooting: Views and Functions Basics

Common errors encountered in this practice session and how to fix them.

---

## Error 1: `ERROR: cannot drop table books because other objects depend on it`

**Trigger:** `DROP TABLE books;` without CASCADE.

**Cause:** Views `available_books` and `active_checkouts` depend on the `books` table. PostgreSQL prevents drops of objects that other objects depend on.

**Fix (development — OK to destroy views):**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "DROP TABLE books CASCADE;"
# Then re-run setup.sql to restore
```

**Fix (production — preserve views):** Drop or recreate the view first, then drop the table:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  DROP VIEW IF EXISTS overdue_checkouts;
  DROP VIEW IF EXISTS available_books;
  DROP TABLE books;
"
```

**Prevention:** Never DROP base tables in production without first auditing what depends on them via `pg_depend`.

---

## Error 2: `ERROR: function days_overdue(date) does not exist`

**Trigger:** Querying `active_checkouts` or calling `days_overdue()` before setup.sql ran.

**Cause:** The function was not created (setup.sql did not complete, or schema was reset without re-running setup.sql).

**Fix:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
CREATE OR REPLACE FUNCTION days_overdue(due DATE)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT (CURRENT_DATE - due)::INT;
$$;
EOF
```

Or re-run setup.sql:
```bash
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/08-views-and-functions-basics/setup.sql
```

---

## Error 3: `ERROR: view "available_books" already exists`

**Trigger:** Running `CREATE VIEW available_books` when it already exists.

**Fix:** Use `CREATE OR REPLACE VIEW`:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE OR REPLACE VIEW available_books AS
  -- new definition here
  SELECT ...;
"
```

Or drop first:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "DROP VIEW IF EXISTS available_books;"
```

**Note:** `CREATE OR REPLACE VIEW` only works if the new definition has the same or more columns than the old one. You cannot remove columns with `CREATE OR REPLACE` — you must DROP and recreate.

---

## Error 4: Materialized view shows stale data

**Symptom:** New checkouts appear in `checkouts` table but not in `checkout_summary_monthly` materialized view.

**Cause:** Materialized views store a snapshot. They do not update automatically.

**Fix:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  REFRESH MATERIALIZED VIEW checkout_summary_monthly;
"

# Or refresh without locking reads (requires a unique index on the materialized view)
# REFRESH MATERIALIZED VIEW CONCURRENTLY checkout_summary_monthly;
```

---

## Error 5: `ERROR: syntax error at or near "$"` when creating a function with dollar quoting

**Trigger:** Shell escaping issues when passing `$$...$$` function body via `-c "..."`.

**Cause:** The shell may interpret `$` characters inside double quotes.

**Fix:** Use a heredoc (single quotes prevent shell expansion):
```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
CREATE OR REPLACE FUNCTION book_summary(p_book_id INT)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT title || ' (' || year::text || ') by ' || author
    FROM books WHERE id = p_book_id;
$$;
EOF
```

---

## Setup troubleshooting

**Problem:** `relation "books" does not exist`
**Fix:** Re-run setup.sql.

**Problem:** Container is not running
**Fix:**
```bash
docker compose -f /mnt/d/wsl/l-pgsql/tools/dashboards/docker-compose.yml up -d cfp_postgres
```
