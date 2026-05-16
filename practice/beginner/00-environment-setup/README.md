# Practice 00: Environment Setup

Level: Beginner

---

## Goal

Connect to the `cfp_postgres` Docker container, verify the connection, and run your first PostgreSQL commands. No tables are required — this practice is about confirming the environment works.

---

## Prerequisites

- Docker Desktop (or Docker Engine) installed and running
- Container `cfp_postgres` is running (`docker ps | grep cfp_postgres`)
- Basic familiarity with a terminal

---

## How to Connect

### Option 1 — psql inside the container (primary method for this repo)

```bash
docker exec -it cfp_postgres psql -U cfp -d cfp
```

You should see:
```
psql (16.x)
Type "help" for help.

cfp=#
```

### Option 2 — One-off SQL command without entering psql

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "SELECT version();"
```

### Option 3 — pgAdmin (GUI)

Connect to `localhost:5050` if pgAdmin is included in the stack. Credentials are in the docker-compose file.

---

## Connection parameters

| Parameter | Value |
|-----------|-------|
| Host | `localhost` (from host machine) / `cfp_postgres` (from another container) |
| Port | `5432` |
| Database | `cfp` |
| User | `cfp` |
| Password | See `docker-compose.yml` in repo root |

---

## What this practice covers

1. Checking Docker container status
2. Connecting via psql
3. Running `SELECT version()`
4. Listing databases (`\l`)
5. Listing extensions
6. Confirming the `cfp` database and user exist

---

## Files in this folder

| File | Purpose |
|------|---------|
| `README.md` | This file — goals, prerequisites, how to connect |
| `setup.sql` | Connection test query (idempotent) |
| `00-setup-validation.md` | Step-by-step setup check instructions |
| `exercises.md` | 5 exercises for environment familiarization |
| `solutions.md` | Full solutions with explanations |
| `reflection.md` | Thinking questions |
| `ontology-notes.md` | Concept map for this practice |
| `troubleshooting.md` | Common connection errors and fixes |
| `references.md` | Docs and resources |

---

## Notes

> All SQL in this practice is marked: blocked: Docker not accessible; validate against cfp_postgres when available
