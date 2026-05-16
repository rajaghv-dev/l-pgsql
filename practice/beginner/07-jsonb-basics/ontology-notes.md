# Ontology Notes: JSONB Basics

These notes map the concepts in this practice session to the broader PostgreSQL concept graph.

---

## Concept map

```
data model
  ├── structured (relational columns) — fixed schema, typed, indexed efficiently
  └── semi-structured (JSONB) — flexible schema per row, indexed with GIN

JSONB (binary JSON)
  ├── IS A: column data type (stores one JSON document per row)
  ├── CONTRASTS WITH: json (text storage, slower, no indexing)
  ├── OPERATORS:
  │     ├── ->  (navigate, returns JSONB)
  │     ├── ->> (extract leaf as text)
  │     ├── #>  (path navigate, returns JSONB)
  │     ├── #>> (path navigate, returns text)
  │     ├── @>  (containment, GIN-indexable)
  │     ├── ?   (key exists, GIN-indexable)
  │     └── ||  (merge two JSONB objects)
  ├── FUNCTIONS:
  │     ├── jsonb_set(col, path, value, create) — update/add key
  │     ├── jsonb_each(col) — expand to rows
  │     ├── jsonb_object_keys(col) — return key names
  │     └── jsonb_pretty(col) — formatted string output
  └── INDEXED BY: GIN index (inverted index on keys and values)

GIN index (for JSONB)
  ├── IS A: inverted index
  ├── SUPPORTS: @>, ?, ?|, ?&
  ├── DOES NOT SUPPORT: ->>, ->> with =  (use expression index for that)
  └── VARIANTS: jsonb_ops (default), jsonb_path_ops (smaller, @> only)
```

---

## Concept definitions

| Concept | Definition | Parent concept | Child concepts |
|---------|-----------|----------------|----------------|
| JSONB | Binary-encoded JSON stored as a column value | data type | operators, GIN index |
| `->` operator | Navigate JSON: returns JSONB value at key | JSONB operator | — |
| `->>` operator | Extract JSON value as text | JSONB operator | — |
| `@>` operator | Containment: left JSONB contains right JSONB | JSONB operator | GIN index |
| `jsonb_set()` | Return new JSONB with one key modified | JSONB function | — |
| GIN index | Inverted index: maps values to the rows that contain them | index | JSONB, FTS, arrays |
| `||` operator | Merge two JSONB objects (right-hand keys win on conflict) | JSONB operator | — |

---

## Key relationships

- **JSONB IS A** column type — it stores one complete JSON document per row value.
- **`->` CONTRASTS WITH** `->>`  — same navigation, different return type (JSONB vs text).
- **`@>` REQUIRES** GIN index for efficiency at scale.
- **GIN index IS AN** inverted index — maps JSONB values to row IDs.
- **`jsonb_set()` CONTRASTS WITH** `||` — `jsonb_set` modifies one key at a path; `||` merges all top-level keys.
- **JSONB CONTRASTS WITH** relational columns — JSONB is flexible but loses FK constraints, per-column indexing, and type safety.
- **JSONB IS A** hybrid between fully structured (relational) and unstructured (text blob).

---

## Obsidian graph links

- `[[jsonb]]`
- `[[gin-index]]`
- `[[inverted-index]]`
- `[[jsonb-set]]`
- `[[containment-operator]]`
- `[[semi-structured-data]]`
- `[[data-type]]`
- `[[index]]`
- `[[pgvector]]`

---

## Questions for deeper concept mapping

1. Is JSONB a relation? (No — it is a value stored in a column within a row of a relation. But `jsonb_each()` produces a relation from a JSONB value.)
2. What concept is logically upstream of JSONB? (The decision to allow variable structure — if all rows have the same structure, use proper columns instead.)
3. What concepts does JSONB make possible downstream? (Schema-flexible applications, semi-structured storage without migrations, hybrid relational+document queries, RAG payload storage.)
