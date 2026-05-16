# Troubleshooting: Roles Basics

Common errors encountered in this practice session and how to fix them.

---

## Error 1: `ERROR: role "lib_readonly" already exists`

**Trigger:** Running `CREATE ROLE lib_readonly` when the role already exists from a previous session.

**Fix:**
```bash
# Drop existing roles (in order: login roles first, then group roles)
docker exec cfp_postgres psql -U cfp -d cfp -c "
  DROP ROLE IF EXISTS lib_agent;
  DROP ROLE IF EXISTS lib_readonly;
"
# Then re-run the CREATE ROLE commands
```

**Prevention:** Use `CREATE ROLE IF NOT EXISTS` (PostgreSQL 14+):
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE ROLE IF NOT EXISTS lib_readonly;
"
```

---

## Error 2: `FATAL: password authentication failed for user "lib_agent"`

**Trigger:** Connecting as `lib_agent` with the wrong password or after recreating the role with a different password.

**Fix:** Reset the password:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  ALTER ROLE lib_agent PASSWORD 'agent_pass';
"
```

Or drop and recreate:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  DROP ROLE IF EXISTS lib_agent;
  CREATE ROLE lib_agent LOGIN PASSWORD 'agent_pass' IN ROLE lib_readonly;
"
```

---

## Error 3: `ERROR: permission denied for schema public`

**Trigger:** `lib_agent` can connect but gets an error accessing tables.

**Cause:** `USAGE` on the `public` schema was not granted to `lib_readonly`.

**Fix:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  GRANT USAGE ON SCHEMA public TO lib_readonly;
"
```

**Why three GRANTs are needed:**
1. `CONNECT ON DATABASE` — allows connection to the database.
2. `USAGE ON SCHEMA` — allows referencing objects within the schema.
3. `SELECT ON TABLE` — allows reading rows from the specific table.
All three must be in place. Missing any one causes a permission error at that layer.

---

## Error 4: `ERROR: role "lib_agent" cannot be dropped because some objects depend on it`

**Trigger:** `DROP ROLE lib_agent` fails because `lib_agent` owns objects or has grants.

**Fix:** Reassign objects to another role first, then drop:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  REASSIGN OWNED BY lib_agent TO cfp;
  DROP OWNED BY lib_agent;
  DROP ROLE lib_agent;
"
```

---

## Error 5: `lib_agent` can still SELECT after REVOKE

**Symptom:** You revoked SELECT from `lib_readonly`, but `lib_agent` can still run SELECT.

**Cause:** `lib_agent` may have a direct SELECT grant (separate from the group role inheritance). Check:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT grantee, privilege_type, table_name
  FROM information_schema.role_table_grants
  WHERE grantee IN ('lib_readonly', 'lib_agent')
  ORDER BY grantee, table_name;
"
```

**Fix:** Revoke from the specific role that still has the grant:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  REVOKE SELECT ON TABLE library_books FROM lib_agent;
"
```

---

## Error 6: `ERROR: must be superuser to create role`

**Trigger:** The current user (`cfp`) does not have CREATEROLE privilege.

**Cause:** The cfp user was created without CREATEROLE.

**Diagnosis:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT rolname, rolsuper, rolcreaterole FROM pg_roles WHERE rolname = 'cfp';
"
```

**Fix:** In the standard cfp_postgres setup, `cfp` is a superuser. If not, connect as postgres:
```bash
docker exec cfp_postgres psql -U postgres -c "
  ALTER ROLE cfp CREATEROLE;
"
```

---

## Setup troubleshooting

**Problem:** Container is not running
**Fix:**
```bash
docker compose -f /mnt/d/wsl/l-pgsql/tools/dashboards/docker-compose.yml up -d cfp_postgres
```

**Problem:** `library_books` table does not exist
**Fix:** Re-run setup.sql:
```bash
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/practice/beginner/09-roles-basics/setup.sql
```
