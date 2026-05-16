# Exercises — Practice 00: Environment Setup

Complete the setup validation in `00-setup-validation.md` before these exercises.

All SQL: `docker exec cfp_postgres psql -U cfp -d cfp -c "..."`
> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Exercise 1 — Print the server version

**Goal:** Confirm PostgreSQL version is 16.x.

**SQL:**
```sql
SELECT version();
```

**Expected result:**
```
                         version
------------------------------------------------------------------
 PostgreSQL 16.x on x86_64-pc-linux-gnu, ...
```

**Agent/MCP angle:** An MCP server reporting database capabilities would start by querying version to know which features are available (e.g. MERGE was added in PG 15, UUIDv7 in PG 17).

---

## Exercise 2 — Show connection facts

**Goal:** Confirm you are connected to the right database as the right user.

**SQL:**
```sql
SELECT
    current_database()  AS database,
    current_user        AS db_user,
    inet_server_addr()  AS server_ip,
    inet_server_port()  AS server_port,
    now()               AS server_time;
```

**Expected result:**
```
 database | db_user | server_ip | server_port |         server_time
----------+---------+-----------+-------------+------------------------------
 cfp      | cfp     | 0.0.0.0   |        5432 | 2024-xx-xx xx:xx:xx+00
```

**Agent/MCP angle:** An agent connecting to a database should always self-verify its connection context before executing writes.

---

## Exercise 3 — List all databases on the server

**Goal:** See what databases exist; confirm `cfp` is present.

**SQL:**
```sql
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM   pg_database
ORDER  BY datname;
```

**Expected result:** A table including `cfp`, `postgres`, `template0`, `template1`.

**Agent/MCP angle:** An agent discovering the data landscape would list databases first, then schemas, then tables — this query is step one of that discovery.

---

## Exercise 4 — List installed extensions

**Goal:** Know which extensions are available in the `cfp` database.

**SQL:**
```sql
SELECT extname, extversion, obj_description(oid, 'pg_extension') AS description
FROM   pg_extension
ORDER  BY extname;
```

**Expected result:** At minimum `plpgsql`. If `pg_stat_statements` was set up, it appears here.

**Agent/MCP angle:** Extensions add capabilities. An agent using `pgvector` for embeddings would first verify `pgvector` is installed. This query is the capability check.

---

## Exercise 5 — Run the setup.sql file

**Goal:** Run `setup.sql` from the command line and confirm the output.

**Command:**
```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < practice/beginner/00-environment-setup/setup.sql
```

**Expected result:** The setup query output (version, database name, user, server time).

**Agent/MCP angle:** An agent running setup scripts treats the output as a structured health check. If any column is unexpected (wrong database, wrong user), the agent should abort further writes.
