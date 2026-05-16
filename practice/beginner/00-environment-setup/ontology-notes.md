# Ontology Notes — Practice 00: Environment Setup

Concept map for the environment setup domain. Use these links in Obsidian.

---

## Concept Map

```
[[PostgreSQL Server]]
    ├── hosts many [[Database]]
    │       ├── default: [[postgres database]]
    │       ├── template: [[template0]] (immutable)
    │       ├── template: [[template1]] (mutable default)
    │       └── user: [[cfp database]]
    │
    ├── managed by [[Postmaster Process]]
    │       └── spawns [[Backend Process]] per connection
    │
    └── accessed via [[psql]] (CLI client)
            └── uses [[PostgreSQL wire protocol]] (TCP port 5432)

[[cfp database]]
    ├── owned by [[cfp role]]
    ├── contains [[public schema]]
    └── has [[Extensions]]
            └── [[plpgsql]] (always present)

[[Docker Container]] (cfp_postgres)
    └── runs [[PostgreSQL Server]]
            └── accessible via docker exec or port mapping
```

---

## Key relationships

| Concept | Relation | Concept |
|---------|----------|---------|
| [[Server]] | hosts many | [[Database]] |
| [[Database]] | contains many | [[Schema]] |
| [[Schema]] | contains many | [[Table]] |
| [[Connection]] | authenticates as | [[Role]] |
| [[Role]] | has privileges on | [[Database]] |
| [[Extension]] | adds capabilities to | [[Database]] |

---

## Wikilinks for Obsidian

- [[PostgreSQL]]
- [[psql]]
- [[Docker]]
- [[Connection]]
- [[Database]]
- [[Schema]]
- [[Role]]
- [[Extension]]
- [[pg_extension]]
- [[pg_database]]
- [[current_user]]
- [[current_database]]
- [[version()]]
- [[TIMESTAMPTZ]]
- [[now()]]
