# Setup Validation — Practice 00

Follow each step in order. Confirm each check before moving to the next.

---

## Step 1 — Docker container is running

```bash
docker ps --filter name=cfp_postgres --format "table {{.Names}}\t{{.Status}}"
```

Expected output:
```
NAMES           STATUS
cfp_postgres    Up X minutes
```

If the container is not listed: `docker start cfp_postgres`

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Step 2 — Connect to psql

```bash
docker exec -it cfp_postgres psql -U cfp -d cfp
```

Expected prompt: `cfp=#`

If you see `FATAL: password authentication failed` — check the password in `docker-compose.yml`.

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Step 3 — Run the version query

Inside psql:
```sql
SELECT version();
```

Expected output (version numbers may differ):
```
                          version
-------------------------------------------------------------
 PostgreSQL 16.x on x86_64-pc-linux-gnu, compiled by gcc...
```

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Step 4 — Confirm current database and user

```sql
SELECT current_database(), current_user;
```

Expected:
```
 current_database | current_user
------------------+-------------
 cfp              | cfp
```

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Step 5 — List databases

In psql:
```
\l
```

Expected: a list of databases including `cfp`, `postgres`, `template0`, `template1`.

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Step 6 — List installed extensions

```sql
SELECT extname, extversion FROM pg_extension ORDER BY extname;
```

Expected: at minimum `plpgsql`. If `pg_stat_statements` was set up, it should appear here too.

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Step 7 — Exit psql

```
\q
```

---

## Checklist

- [ ] Container `cfp_postgres` is running
- [ ] Can connect with `psql -U cfp -d cfp`
- [ ] `SELECT version()` returns PostgreSQL 16.x
- [ ] `current_database()` returns `cfp`
- [ ] `current_user` returns `cfp`
- [ ] `\l` shows the `cfp` database
- [ ] `pg_extension` lists `plpgsql`
