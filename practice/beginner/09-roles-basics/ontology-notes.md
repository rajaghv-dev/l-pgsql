# Ontology Notes: Roles Basics

These notes map the concepts in this practice session to the broader PostgreSQL concept graph.

---

## Concept map

```
access control system
  ├── principal (who) → role
  │     ├── group role  — no login, collects permissions
  │     └── login role  — has login, can connect to database
  │           └── inherits from group role (via membership)
  ├── object (what) → database, schema, table, view, sequence, function...
  ├── privilege (action) → SELECT, INSERT, UPDATE, DELETE, CONNECT, USAGE, CREATE...
  └── grant (assertion) → "principal has privilege on object"

role hierarchy
  lib_readonly (group) ──grants──► SELECT on library_books
       │
       └── member: lib_agent (login) ──inherits──► SELECT on library_books

permission layers (all three required to read a table)
  1. CONNECT on database
  2. USAGE on schema
  3. SELECT on table (or SELECT on view)

principle of least privilege
  ├── each role gets ONLY what it needs
  ├── agents: SELECT (and narrow INSERT if needed)
  ├── no SUPERUSER for application roles
  └── view-based access: grant SELECT on view, not on base table
```

---

## Concept definitions

| Concept | Definition | Parent concept | Child concepts |
|---------|-----------|----------------|----------------|
| role | A named identity in PostgreSQL — user or group | principal | login role, group role |
| login role | A role with LOGIN privilege — can open a connection | role | — |
| group role | A role without LOGIN — a named collection of permissions | role | — |
| GRANT | Assert that a principal has a privilege on an object | access control | privilege, object |
| REVOKE | Remove a previously granted privilege | access control | — |
| privilege | A specific action allowed on an object (SELECT, INSERT, etc.) | access control | — |
| CONNECT | Privilege: allowed to connect to the database | privilege | — |
| USAGE | Privilege: allowed to reference objects in a schema | privilege | — |
| role inheritance | Member role automatically gains group role's permissions | role membership | rolinherit |
| principle of least privilege | Design principle: grant only what is needed | security principle | — |

---

## Key relationships

- **Login role IS A** role with `rolcanlogin = true`.
- **Group role IS A** role with `rolcanlogin = false`.
- **Login role INHERITS FROM** group role via membership.
- **GRANT REQUIRES** three layers: database (CONNECT) + schema (USAGE) + object (SELECT etc.).
- **REVOKE FROM group role AFFECTS** all member login roles immediately.
- **View ENABLES** "security through views" — agents access data through views without direct table access.
- **Principle of least privilege CONTRASTS WITH** superuser connections — broad access = larger blast radius.

---

## Obsidian graph links

- `[[role]]`
- `[[login-role]]`
- `[[group-role]]`
- `[[grant]]`
- `[[revoke]]`
- `[[privilege]]`
- `[[principle-of-least-privilege]]`
- `[[role-inheritance]]`
- `[[connect-privilege]]`
- `[[usage-privilege]]`
- `[[security-through-views]]`
- `[[discretionary-access-control]]`

---

## Questions for deeper concept mapping

1. Is a role a relation? (No — it is a principal, tracked in pg_roles system catalog. But pg_roles IS a relation you can query.)
2. What concept is logically upstream of a role? (Authentication — the role must be authenticated before access control applies. pg_hba.conf controls authentication, roles control authorization.)
3. What concepts does least-privilege role design make possible downstream? (Audit logging by role, Row-Level Security scoped to session role, safe agent access, limited blast radius on breach.)
