# Practice 03: Keys and Constraints

Level: Beginner

---

## Goal

Add NOT NULL, UNIQUE, CHECK, PRIMARY KEY, and FOREIGN KEY constraints to the e-commerce schema. Observe constraint violations and recover from errors. Understand how constraints protect data quality.

---

## Prerequisites

- Completed Practice 02 (store schema exists)
- Read concepts: `05-primary-keys-and-identity.md`, `06-foreign-keys-and-relationships.md`, `07-constraints-as-rules.md`

---

## How to Connect

```bash
docker exec -it cfp_postgres psql -U cfp -d cfp
```

Run setup:
```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < practice/beginner/03-keys-and-constraints/setup.sql
```

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Domain model: constrained e-commerce

Same `store` schema as Practice 02, with added constraints:

```
store.customers
    id          BIGSERIAL PRIMARY KEY
    name        TEXT      NOT NULL
    email       TEXT      NOT NULL UNIQUE
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()

store.products
    id          BIGSERIAL PRIMARY KEY
    name        TEXT      NOT NULL
    sku         VARCHAR(20) NOT NULL UNIQUE
    price       NUMERIC(10,2) NOT NULL CHECK (price > 0)
    status      TEXT NOT NULL CHECK (status IN ('active','discontinued','draft')) DEFAULT 'active'
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()

store.orders
    id          BIGSERIAL PRIMARY KEY
    customer_id BIGINT NOT NULL REFERENCES store.customers(id) ON DELETE RESTRICT
    status      TEXT NOT NULL CHECK (status IN ('pending','completed','cancelled')) DEFAULT 'pending'
    ordered_at  TIMESTAMPTZ NOT NULL DEFAULT now()
```

---

## What this practice covers

1. Observing PK violation errors
2. Observing NOT NULL violation errors
3. Observing UNIQUE violation and using ON CONFLICT
4. Observing CHECK violation errors
5. Observing FK violation (INSERT child with bad parent)
6. Observing FK violation (DELETE parent with children)
7. Adding a constraint to an existing table with ALTER TABLE
8. Listing all constraints via pg_constraint

---

## Files in this folder

| File | Purpose |
|------|---------|
| `README.md` | This file |
| `setup.sql` | Idempotent constrained schema + seed |
| `00-setup-validation.md` | Verify constraints are in place |
| `exercises.md` | 8 exercises on constraint behavior |
| `solutions.md` | Full solutions with error messages |
| `reflection.md` | Thinking questions |
| `ontology-notes.md` | Concept map |
| `troubleshooting.md` | Constraint errors and recovery |
| `references.md` | Docs and resources |
