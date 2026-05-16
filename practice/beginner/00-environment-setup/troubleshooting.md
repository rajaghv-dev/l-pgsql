# Troubleshooting — Practice 00: Environment Setup

---

## Error 1 — Container not found

**Symptom:**
```
Error response from daemon: No such container: cfp_postgres
```

**Cause:** The Docker container has not been created or was removed.

**Fix:**
```bash
# Check if any postgres containers exist
docker ps -a | grep postgres

# Start the full stack from the repo root
docker compose up -d

# Or start just the postgres container if it exists but is stopped
docker start cfp_postgres
```

---

## Error 2 — Connection refused

**Symptom:**
```
psql: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed:
No such file or directory
```
or
```
psql: error: could not connect to server: Connection refused
```

**Cause:** PostgreSQL inside the container has not finished starting up, or the port mapping is wrong.

**Fix:**
```bash
# Check container logs
docker logs cfp_postgres --tail 20

# Wait for PostgreSQL to be ready
docker exec cfp_postgres pg_isready -U cfp -d cfp

# If port mapping is wrong, check docker-compose.yml for the ports section
```

---

## Error 3 — Authentication failed

**Symptom:**
```
FATAL:  password authentication failed for user "cfp"
```

**Cause:** Wrong password, or the `cfp` role was not created with the expected password.

**Fix:**
```bash
# Check what password was set in docker-compose.yml (POSTGRES_PASSWORD env var)
# Connect as the superuser to reset
docker exec -it cfp_postgres psql -U postgres -c "\password cfp"
```

---

## Error 4 — Database does not exist

**Symptom:**
```
FATAL:  database "cfp" does not exist
```

**Cause:** The `cfp` database was never created, or the wrong database name was specified.

**Fix:**
```bash
# Connect to postgres database and create cfp
docker exec -it cfp_postgres psql -U postgres -c "CREATE DATABASE cfp OWNER cfp;"
```

---

## Error 5 — Role does not exist

**Symptom:**
```
FATAL:  role "cfp" does not exist
```

**Cause:** The `cfp` role was not created (database init scripts may not have run).

**Fix:**
```bash
docker exec -it cfp_postgres psql -U postgres -c "CREATE ROLE cfp WITH LOGIN PASSWORD 'your_password';"
docker exec -it cfp_postgres psql -U postgres -c "CREATE DATABASE cfp OWNER cfp;"
```

---

## Error 6 — psql: command not found (on host)

**Symptom:**
```
bash: psql: command not found
```

**Cause:** `psql` is not installed on the host machine, or you are running the command on the host instead of inside the container.

**Fix:** Always use `docker exec` to run psql inside the container:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "SELECT 1;"
```

If you want to install psql on the host: `sudo apt-get install postgresql-client` (Ubuntu/Debian).

---

## Error 7 — stdin is not a terminal

**Symptom:**
```
stdin: is not a tty
```

**Cause:** Using `-it` flags when redirecting stdin from a file.

**Fix:** Use `-i` without `-t` when piping a file:
```bash
# Wrong (for file input)
docker exec -it cfp_postgres psql -U cfp -d cfp < setup.sql

# Correct
docker exec -i cfp_postgres psql -U cfp -d cfp < setup.sql
```

---

## Error 8 — pg_stat_statements not available

**Symptom:**
```
ERROR:  extension "pg_stat_statements" is not available
```

**Cause:** The extension's shared library is not loaded. Requires `pg_stat_statements` in `shared_preload_libraries` in `postgresql.conf`.

**Fix:** This requires a PostgreSQL restart. See the dashboard stack setup in `arch.md` for the correct docker-compose configuration.
