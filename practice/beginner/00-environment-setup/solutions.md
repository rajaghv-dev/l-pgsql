# Solutions — Practice 00: Environment Setup

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Exercise 1 — Print the server version

```sql
SELECT version();
```

**Explanation:** `version()` is a built-in PostgreSQL function. It returns a string describing the compiled binary version, platform, and compiler. The first token in the string is always `PostgreSQL X.Y.Z`.

To extract just the version number:
```sql
SELECT current_setting('server_version');
-- or
SHOW server_version;
```

---

## Exercise 2 — Show connection facts

```sql
SELECT
    current_database()  AS database,
    current_user        AS db_user,
    inet_server_addr()  AS server_ip,
    inet_server_port()  AS server_port,
    now()               AS server_time;
```

**Explanation:**
- `current_database()` — the database your session is connected to
- `current_user` — the role PostgreSQL authenticated you as (not the OS user)
- `inet_server_addr()` / `inet_server_port()` — network address the server is listening on
- `now()` — server clock at start of current transaction (stable within a transaction)

**Note:** `now()` returns a `TIMESTAMPTZ`. To see UTC explicitly: `now() AT TIME ZONE 'UTC'`.

---

## Exercise 3 — List all databases

```sql
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM   pg_database
ORDER  BY datname;
```

**Explanation:**
- `pg_database` is a system catalog table listing every database on the server
- `pg_database_size(datname)` returns size in bytes
- `pg_size_pretty()` formats bytes as human-readable (KB, MB, GB)
- `template0` and `template1` are system templates; `postgres` is the default maintenance database

**Alternative in psql:** `\l+` lists databases with size information.

---

## Exercise 4 — List installed extensions

```sql
SELECT extname, extversion, obj_description(oid, 'pg_extension') AS description
FROM   pg_extension
ORDER  BY extname;
```

**Explanation:**
- `pg_extension` is the system catalog for installed extensions
- `obj_description(oid, 'pg_extension')` reads the extension's description from the catalog
- `plpgsql` is always present — it is the built-in procedural language

To see what extensions are available to install (but not yet installed):
```sql
SELECT name, default_version, comment
FROM   pg_available_extensions
ORDER  BY name;
```

---

## Exercise 5 — Run setup.sql

```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < practice/beginner/00-environment-setup/setup.sql
```

**Explanation:**
- `-i` (not `-it`) is used when redirecting stdin from a file (no interactive terminal)
- `< file.sql` pipes the file contents into psql as stdin
- The output should match `SELECT version(), current_database(), current_user, now()`

**Alternative — specify the file path inside the container:**
```bash
# Copy the file into the container first
docker cp practice/beginner/00-environment-setup/setup.sql cfp_postgres:/tmp/setup.sql
# Then run it
docker exec cfp_postgres psql -U cfp -d cfp -f /tmp/setup.sql
```
