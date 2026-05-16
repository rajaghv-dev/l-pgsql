# Ontology Notes — Practice 03: Keys and Constraints

---

## Concept Map

```
[[Constraint]] (database axiom — must be true for every row)
    ├── [[NOT NULL Constraint]]
    │       └── "every instance must have this property"
    │           (mandatory property in ontology terms)
    │
    ├── [[UNIQUE Constraint]]
    │       ├── creates a [[UNIQUE Index]] automatically
    │       └── "no two instances share this value"
    │           (functional property in ontology terms)
    │
    ├── [[CHECK Constraint]]
    │       ├── [[chk_products_price_pos]]   → price > 0
    │       ├── [[chk_products_status_valid]] → status IN (...)
    │       └── "property value restricted to a range"
    │           (datatype restriction in ontology terms)
    │
    ├── [[PRIMARY KEY]]
    │       ├── = NOT NULL + UNIQUE combined
    │       ├── creates a [[Primary Index]]
    │       └── "this property uniquely identifies each instance"
    │           (inverse-functional + mandatory in ontology terms)
    │
    └── [[FOREIGN KEY]]
            ├── [[ON DELETE RESTRICT]] → block orphaning
            ├── [[ON DELETE CASCADE]]  → remove children
            ├── [[ON DELETE SET NULL]] → anonymize reference
            └── "this property's value must be an instance of that class"
                (object property range restriction in ontology terms)

[[ON CONFLICT]] clause (INSERT behavior on constraint violation)
    ├── DO NOTHING    → silent skip (idempotent write)
    └── DO UPDATE     → upsert (insert or update)

[[pg_constraint]] (system catalog)
    ├── contype: p (PK), u (UNIQUE), c (CHECK), f (FK)
    ├── conname: constraint name
    └── pg_get_constraintdef(oid) → reconstructed SQL

[[pg_attribute]] (stores NOT NULL per column)
    └── attnotnull: true/false per column
```

---

## Key relationships

| Concept | Relation | Concept |
|---------|----------|---------|
| [[PRIMARY KEY]] | implies | [[NOT NULL]] + [[UNIQUE]] |
| [[UNIQUE Constraint]] | creates | [[UNIQUE Index]] |
| [[FOREIGN KEY]] | references | [[PRIMARY KEY]] of parent table |
| [[CHECK Constraint]] | evaluates | boolean [[Expression]] per row |
| [[ON CONFLICT DO UPDATE]] | uses | [[EXCLUDED]] pseudo-table |
| [[pg_constraint]] | describes | all [[Constraint]]s except NOT NULL |

---

## Wikilinks for Obsidian

- [[Constraint]]
- [[NOT NULL Constraint]]
- [[UNIQUE Constraint]]
- [[CHECK Constraint]]
- [[PRIMARY KEY]]
- [[FOREIGN KEY]]
- [[ON DELETE RESTRICT]]
- [[ON DELETE CASCADE]]
- [[ON DELETE SET NULL]]
- [[ON CONFLICT]]
- [[EXCLUDED]]
- [[pg_constraint]]
- [[pg_attribute]]
- [[BIGSERIAL]]
- [[Sequence]]
- [[NOT VALID]]
- [[VALIDATE CONSTRAINT]]
- [[Referential Integrity]]
- [[Upsert]]
- [[Idempotent Write]]
