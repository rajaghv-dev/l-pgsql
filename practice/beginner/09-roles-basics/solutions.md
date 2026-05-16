# Solutions: Roles Basics

Level: Beginner

Read `exercises.md` and attempt the exercises before opening this file.

---

## Solution: Exercise 1 — Create Group Role

```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
CREATE ROLE lib_readonly;
GRANT CONNECT ON DATABASE cfp TO lib_readonly;
GRANT USAGE ON SCHEMA public TO lib_readonly;
GRANT SELECT ON TABLE library_books TO lib_readonly;
EOF

docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT grantee, privilege_type, table_name
  FROM information_schema.role_table_grants
  WHERE grantee = 'lib_readonly';
"
```

**Why this works:** Three layers of permission are needed:
1. `CONNECT` on the database — allows the role to open a connection.
2. `USAGE` on the schema — allows the role to see and reference objects in the schema.
3. `SELECT` on the table — allows the role to read rows from the specific table.

Missing any layer causes an error (e.g., without USAGE on schema: "permission denied for schema public").

---

## Solution: Exercise 2 — Create Login Role

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE ROLE lib_agent LOGIN PASSWORD 'agent_pass' IN ROLE lib_readonly;
"
```

**Alternative syntax (explicit GRANT):**
```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
CREATE ROLE lib_agent LOGIN PASSWORD 'agent_pass';
GRANT lib_readonly TO lib_agent;
EOF
```

Both forms are equivalent. `IN ROLE lib_readonly` at CREATE time is shorthand for `GRANT lib_readonly TO lib_agent`.

**Key learning:** Group role + login role separation means: to change what all library agents can do, change `lib_readonly`'s permissions. All login roles that are members are updated instantly.

---

## Solution: Exercise 3 — Verify SELECT

```bash
docker exec cfp_postgres psql -U lib_agent -d cfp -c "
  SELECT title, available FROM library_books ORDER BY title;
"
```

**Output:**
```
               title                | available
------------------------------------+-----------
 Database Design for Mere Mortals   | f
 PostgreSQL: Up and Running         | t
 The Art of PostgreSQL              | t
```

**Key learning:** `lib_agent` inherits `SELECT` from `lib_readonly`. No direct grant to `lib_agent` was needed.

---

## Solution: Exercise 4 — Verify INSERT Rejected

```bash
# All three should fail with "permission denied for table library_books"
docker exec cfp_postgres psql -U lib_agent -d cfp -c "
  INSERT INTO library_books (title, author) VALUES ('Hacked', 'Attacker');
"
docker exec cfp_postgres psql -U lib_agent -d cfp -c "
  UPDATE library_books SET available = false WHERE id = 1;
"
docker exec cfp_postgres psql -U lib_agent -d cfp -c "
  DELETE FROM library_books WHERE id = 1;
"
```

**Key learning:** PostgreSQL enforces permissions independently of the application. Even if an attacker modifies the application code to attempt a DELETE, the database rejects it. The attack surface is limited to what the role is allowed to do.

**Three risks of superuser connections in applications:**
1. An SQL injection attack has full write/delete/drop access.
2. A buggy migration script that runs with the app connection can drop tables.
3. No audit trail distinguishes application queries from admin queries.

**Design for write access (creative thinking answer):**
```sql
-- patron_requests: agents can INSERT only
GRANT INSERT ON patron_requests TO lib_readonly;
GRANT USAGE ON SEQUENCE patron_requests_id_seq TO lib_readonly;
-- library_books: agents still SELECT only
-- No UPDATE/DELETE granted anywhere
```

---

## Solution: Exercise 5 — REVOKE and Cleanup

```bash
# Revoke from group (immediately removes from all members)
docker exec cfp_postgres psql -U cfp -d cfp -c "
  REVOKE SELECT ON TABLE library_books FROM lib_readonly;
"

# Verify denied
docker exec cfp_postgres psql -U lib_agent -d cfp -c "
  SELECT * FROM library_books;
"
# ERROR: permission denied for table library_books

# Cleanup (must drop login role before group role if using membership)
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
DROP ROLE lib_agent;
DROP ROLE lib_readonly;
EOF

# Confirm clean
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT rolname FROM pg_roles WHERE rolname IN ('lib_readonly', 'lib_agent');
"
# (0 rows)
```

**Key learning:** REVOKE from a group role is a single operation that updates all members instantly. This is the power of role inheritance — centralized permission management.

---

## Solution: Exercise 6 (stretch) — View-Based Access

```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
CREATE OR REPLACE VIEW available_books_view AS
SELECT title, author FROM library_books WHERE available = true;

CREATE ROLE catalog_reader LOGIN PASSWORD 'catalog_pass';
GRANT CONNECT ON DATABASE cfp TO catalog_reader;
GRANT USAGE ON SCHEMA public TO catalog_reader;
GRANT SELECT ON available_books_view TO catalog_reader;
EOF

# View works
docker exec cfp_postgres psql -U catalog_reader -d cfp -c "
  SELECT * FROM available_books_view;
"

# Table blocked
docker exec cfp_postgres psql -U catalog_reader -d cfp -c "
  SELECT * FROM library_books;
"

# Cleanup
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
DROP ROLE catalog_reader;
DROP VIEW available_books_view;
EOF
```

**Key learning:** Views run under the view owner's permissions for accessing base tables. `catalog_reader` can query `available_books_view` (which the `cfp` owner has access to), but cannot query `library_books` directly (because `catalog_reader` has no direct SELECT on it). This is called "security through views" — a powerful pattern for limiting agent data exposure.
