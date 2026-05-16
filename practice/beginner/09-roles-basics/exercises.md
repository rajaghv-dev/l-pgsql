# Exercises: Roles Basics

Level: Beginner

Work through each exercise in order. Do not look at `solutions.md` until you have tried.

Note: Run all commands as the `cfp` user (which has SUPERUSER privilege). After creating the `lib_agent` role, some exercises connect as that role.

---

## Exercise 1: Create a Read-Only Group Role

**Goal:** Create a group role (no login) that has SELECT on the library_books table and the public schema.

**First-principles question:** Why create a group role without login access? (Group roles are templates — you attach them to login roles. This lets you change permissions for all members by changing the group once.)

**Task:**
1. Create a role named `lib_readonly` (no login, no password).
2. Grant CONNECT on the `cfp` database to it.
3. Grant USAGE on the `public` schema to it.
4. Grant SELECT on the `library_books` table to it.

**Your SQL:**
```sql
CREATE ROLE lib_readonly;
GRANT CONNECT ON DATABASE cfp TO lib_readonly;
GRANT USAGE ON SCHEMA public TO lib_readonly;
GRANT SELECT ON TABLE library_books TO lib_readonly;
```

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE ROLE lib_readonly;
  GRANT CONNECT ON DATABASE cfp TO lib_readonly;
  GRANT USAGE ON SCHEMA public TO lib_readonly;
  GRANT SELECT ON TABLE library_books TO lib_readonly;
"
```

**Verification:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT grantee, privilege_type, table_name
  FROM information_schema.role_table_grants
  WHERE grantee = 'lib_readonly'
  ORDER BY table_name, privilege_type;
"
```

**Expected output:**
```
   grantee    | privilege_type |  table_name
--------------+----------------+---------------
 lib_readonly | SELECT         | library_books
(1 row)
```

**Critical-thinking question:** The role has SELECT on `library_books` but not on other tables. If you run `SELECT * FROM books` as `lib_readonly`, will it succeed? (No — only the granted tables are accessible.)

**Ontology-thinking question:** `lib_readonly` is a group role — it has no login. What is it conceptually? (A named set of permissions — a template for access.)

**What this teaches:** A group role collects permissions. Login roles that are members of the group inherit those permissions.

---

## Exercise 2: Create a Login Role (Agent Account)

**Goal:** Create a login role `lib_agent` that inherits permissions from `lib_readonly`.

**First-principles question:** Why use role inheritance instead of granting permissions directly to `lib_agent`? (Separation: the group role `lib_readonly` defines *what* is allowed; the login role `lib_agent` defines *who* can log in. Change permissions once in the group — all members are updated.)

**Task:**
1. Create a role named `lib_agent` with LOGIN, a password, and membership in `lib_readonly`.
2. Verify it appears in pg_roles.

**Command:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE ROLE lib_agent LOGIN PASSWORD 'agent_pass' IN ROLE lib_readonly;
"

docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT rolname, rolcanlogin, rolinherit
  FROM pg_roles
  WHERE rolname IN ('lib_readonly', 'lib_agent')
  ORDER BY rolname;
"
```

**Expected output:**
```
   rolname    | rolcanlogin | rolinherit
--------------+-------------+------------
 lib_agent    | t           | t
 lib_readonly | f           | t
(2 rows)
```

`lib_agent` has `rolcanlogin = t` (can connect), `lib_readonly` has `rolcanlogin = f` (cannot connect directly).

**Critical-thinking question:** `rolinherit = t` means `lib_agent` inherits `lib_readonly`'s permissions automatically. What would happen if `rolinherit = f`? (The role would need to `SET ROLE lib_readonly` explicitly before accessing permissions. This is the `NOINHERIT` option — used for privilege escalation auditing.)

**What this teaches:** `IN ROLE group_role` creates membership. `INHERIT` is the default — the login role automatically has the group role's permissions.

---

## Exercise 3: Verify SELECT Works as lib_agent

**Goal:** Connect as `lib_agent` and verify it can SELECT from library_books.

**Task:** Run a SELECT as the `lib_agent` role.

**Command:**
```bash
docker exec cfp_postgres psql -U lib_agent -d cfp -c "
  SELECT title, available FROM library_books ORDER BY title;
"
```

If password auth is required:
```bash
docker exec cfp_postgres psql -U lib_agent -d cfp -W -c "
  SELECT title, available FROM library_books ORDER BY title;
"
# Password prompt: agent_pass
```

**Expected output:**
```
               title                | available
------------------------------------+-----------
 Database Design for Mere Mortals   | f
 PostgreSQL: Up and Running         | t
 The Art of PostgreSQL              | t
(3 rows)
```

**Agent/MCP angle:**
- Agent scenario: A library catalog bot displays available books to patrons.
- MCP tool name: `list_available_books`
- Connection: Uses `lib_agent` credentials (stored in a secret manager, not hard-coded).
- PostgreSQL operation: `SELECT title, author FROM library_books WHERE available = true ORDER BY title LIMIT 20`
- Required permission: `SELECT` on `library_books` for `lib_agent` (via `lib_readonly` group)
- What the agent CANNOT do: INSERT, UPDATE, DELETE, DROP, CREATE — all rejected at the DB level.

**What this teaches:** The login role `lib_agent` inherits SELECT from `lib_readonly`. The connection succeeds; the query succeeds.

---

## Exercise 4: Verify INSERT is Rejected

**Goal:** Confirm that `lib_agent` cannot INSERT, UPDATE, or DELETE.

**First-principles question:** Why is it better to have the database enforce this rather than relying on the application to "not call DELETE"?

**Task:** Attempt INSERT, UPDATE, and DELETE as `lib_agent`. All should fail with a permission error.

**Commands:**
```bash
# Attempt INSERT (should fail)
docker exec cfp_postgres psql -U lib_agent -d cfp -c "
  INSERT INTO library_books (title, author) VALUES ('Hacked Book', 'Attacker');
"

# Attempt UPDATE (should fail)
docker exec cfp_postgres psql -U lib_agent -d cfp -c "
  UPDATE library_books SET available = false WHERE id = 1;
"

# Attempt DELETE (should fail)
docker exec cfp_postgres psql -U lib_agent -d cfp -c "
  DELETE FROM library_books WHERE id = 1;
"
```

**Expected output for each:**
```
ERROR:  permission denied for table library_books
```

**Critical-thinking question:** The error message says "permission denied for table library_books." This is the database enforcing the permission, independent of the application. What must an attacker compromise to bypass this? (The database superuser — not just the application.)

**Creative-thinking question:** What if the `lib_agent` needs to INSERT into a `patron_requests` table (for logging patron book requests) but should still be READ-ONLY on `library_books`? How would you design this?

**Systems-thinking question:** A common mistake: a developer uses the superuser `cfp` for all connections in the application, reasoning "it's easier." List three specific risks of this practice.

**What this teaches:** The database enforces permissions regardless of the application. A read-only role cannot write — this is defense in depth, not just an application convention.

---

## Exercise 5: REVOKE and Cleanup

**Goal:** Revoke SELECT from the role and clean up.

**Task:**
1. Revoke SELECT on `library_books` from `lib_readonly`.
2. Verify `lib_agent` can no longer SELECT (it inherits from `lib_readonly`).
3. Drop both roles.

**Commands:**
```bash
# Revoke SELECT from the group role
docker exec cfp_postgres psql -U cfp -d cfp -c "
  REVOKE SELECT ON TABLE library_books FROM lib_readonly;
"

# Verify lib_agent can no longer select
docker exec cfp_postgres psql -U lib_agent -d cfp -c "
  SELECT * FROM library_books;
"
# Expected: ERROR: permission denied for table library_books

# Clean up: drop login role first (must drop members before groups in PostgreSQL)
docker exec cfp_postgres psql -U cfp -d cfp -c "
  DROP ROLE lib_agent;
  DROP ROLE lib_readonly;
"

# Verify cleanup
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT rolname FROM pg_roles WHERE rolname IN ('lib_readonly', 'lib_agent');
"
# Expected: 0 rows
```

**Critical-thinking question:** You revoked SELECT from `lib_readonly`. Did you need to also revoke it from `lib_agent` directly? (No — `lib_agent` only had permission through inheritance. Revoking from the group immediately revoked it from all members.)

**What this teaches:** REVOKE from a group role immediately removes the permission from all member roles — this is why group roles are powerful for access management.

---

## Exercise 6 (stretch): Grant Access to a View Only

**Goal:** Create a new role that can SELECT from a view but NOT from the underlying tables.

**Difficulty:** Stretch — only attempt after completing exercises 1–5.

**First-principles question:** If a view selects from `library_books`, and a role has SELECT on the view but not on `library_books`, can the role see the data? (Yes — view ownership determines access to underlying tables. The view runs with the view owner's permissions on the base tables, not the caller's.)

**Task:**
1. Create a view `available_books_view` that shows only available books.
2. Create a role `catalog_reader` with SELECT on the view only.
3. Verify: can SELECT from the view, cannot SELECT from the base table.

**Commands:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp << 'EOF'
-- Create view
CREATE OR REPLACE VIEW available_books_view AS
SELECT title, author FROM library_books WHERE available = true;

-- Create role
CREATE ROLE catalog_reader LOGIN PASSWORD 'catalog_pass';
GRANT CONNECT ON DATABASE cfp TO catalog_reader;
GRANT USAGE ON SCHEMA public TO catalog_reader;
GRANT SELECT ON available_books_view TO catalog_reader;
-- Note: NOT granting SELECT on library_books itself
EOF

# Test: view access works
docker exec cfp_postgres psql -U catalog_reader -d cfp -c "
  SELECT * FROM available_books_view;
"
# Expected: shows available books

# Test: table access fails
docker exec cfp_postgres psql -U catalog_reader -d cfp -c "
  SELECT * FROM library_books;
"
# Expected: ERROR: permission denied for table library_books

# Cleanup
docker exec cfp_postgres psql -U cfp -d cfp -c "
  DROP ROLE catalog_reader;
  DROP VIEW available_books_view;
"
EOF
```

**What this teaches:** Views act as an access control layer. Agents can access data through a view without having direct table access — the view owner's permissions are used for the base table access. This is "security through views."
