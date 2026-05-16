# Ontology Notes: Views and Functions Basics

These notes map the concepts in this practice session to the broader PostgreSQL concept graph.

---

## Concept map

```
database object
  ├── table (base relation — stores data)
  ├── view (derived relation — named SELECT, no stored data)
  │     ├── IS A: derived relation
  │     ├── BASED ON: base tables (or other views)
  │     ├── CONTRASTS WITH: materialized view (stores data)
  │     └── ENABLES: access control, query reuse, abstraction
  └── function (named computation)
        ├── LANGUAGE sql (body is a SQL statement)
        ├── LANGUAGE plpgsql (body is PL/pgSQL procedural code)
        ├── VOLATILITY: IMMUTABLE / STABLE / VOLATILE
        │     ├── IMMUTABLE — same input, always same output (no table access)
        │     ├── STABLE    — same input = same output within one transaction
        │     └── VOLATILE  — may return different result each call
        └── USED IN: SELECT, WHERE, HAVING, JOIN, indexes (IMMUTABLE only)

materialized view
  ├── IS A: persistent derived relation (stores query result)
  ├── CONTRASTS WITH: view (no data stored)
  └── REQUIRES: REFRESH to update stored result
```

---

## Concept definitions

| Concept | Definition | Parent concept | Child concepts |
|---------|-----------|----------------|----------------|
| view | Named SELECT stored in the catalog; recomputed each query | derived relation | materialized view |
| materialized view | View whose result is stored physically and refreshed explicitly | derived relation | — |
| SQL function | Named SQL statement callable with arguments, returns a value | function | — |
| STABLE | Function volatility: same inputs = same output within a transaction | function property | — |
| IMMUTABLE | Function volatility: same inputs always = same output (pure function) | function property | — |
| VOLATILE | Function volatility: may return different results each call | function property | — |
| `pg_depend` | System catalog recording object dependencies | system catalog | — |
| CASCADE | Drop an object and all objects that depend on it | DROP option | — |

---

## Key relationships

- **View IS A** derived relation — its content is derived from base relations, not stored.
- **View REQUIRES** base tables to exist — dropping a base table without CASCADE fails if views depend on it.
- **Function CONTRASTS WITH** view — a view is a named query; a function is a named computation that can take arguments.
- **Materialized view CONTRASTS WITH** view — materialized stores data (fast reads, stale); regular does not (always current, recomputed).
- **STABLE CONTRASTS WITH** IMMUTABLE — STABLE can access tables; IMMUTABLE cannot (it must be a pure computation).
- **SQL function ENABLES** abstraction — callers do not need to know the underlying query logic.
- **View ENABLES** access control — GRANT SELECT on view without granting SELECT on base tables.

---

## Obsidian graph links

- `[[view]]`
- `[[materialized-view]]`
- `[[derived-relation]]`
- `[[sql-function]]`
- `[[immutable]]`
- `[[stable]]`
- `[[volatile]]`
- `[[pg-depend]]`
- `[[cascade]]`
- `[[access-control]]`
- `[[query-reuse]]`

---

## Questions for deeper concept mapping

1. Is a view a relation? (Yes — it is a derived relation. Can you JOIN a view to a table? Yes.)
2. What concept is logically upstream of a view? (The base tables and the recurring query pattern that made the view worth naming.)
3. What concepts does a function make possible downstream? (Index expressions, computed columns, abstraction for agents and applications, stored procedures.)
