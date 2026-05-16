# Ontology Notes — Practice 01: Basic SQL

---

## Concept Map

```
[[SQL]] (declarative language)
    ├── [[DQL]] (Data Query Language)
    │       └── [[SELECT]]
    │               ├── [[FROM clause]] → names the [[Table]]
    │               ├── [[WHERE clause]] → filters [[Row]]s
    │               ├── [[ORDER BY clause]] → sorts result
    │               ├── [[LIMIT clause]] → caps result size
    │               └── [[Aggregate Function]] → collapses many rows to one
    │                       ├── [[COUNT]]
    │                       ├── [[MIN]] / [[MAX]]
    │                       └── [[AVG]]
    │
    ├── [[DML]] (Data Manipulation Language)
    │       ├── [[INSERT]] → creates new [[Row]]s
    │       │       └── [[RETURNING clause]] → returns generated values
    │       ├── [[UPDATE]] → modifies existing [[Row]]s
    │       │       └── [[RETURNING clause]]
    │       └── [[DELETE]] → removes [[Row]]s
    │               └── [[RETURNING clause]]
    │
    └── [[Table]] (books)
            ├── [[Column]]: id (BIGSERIAL, PK)
            ├── [[Column]]: title (TEXT, NOT NULL)
            ├── [[Column]]: author (TEXT, NOT NULL)
            ├── [[Column]]: year (INTEGER, NOT NULL)
            └── [[Column]]: available (BOOLEAN, DEFAULT true)
```

---

## Key relationships

| Concept | Relation | Concept |
|---------|----------|---------|
| [[SELECT]] | filters | [[Row]] |
| [[WHERE]] | evaluates | [[Predicate]] |
| [[INSERT]] | creates | [[Row]] |
| [[UPDATE]] | modifies | [[Row]] |
| [[DELETE]] | removes | [[Row]] |
| [[RETURNING]] | returns | [[Column]] values |
| [[Aggregate]] | collapses | many [[Row]]s → one value |
| [[ORDER BY]] | sorts | [[Result Set]] |

---

## Wikilinks for Obsidian

- [[SELECT]]
- [[INSERT]]
- [[UPDATE]]
- [[DELETE]]
- [[WHERE]]
- [[ORDER BY]]
- [[LIMIT]]
- [[RETURNING]]
- [[Aggregate Function]]
- [[COUNT]]
- [[FILTER clause]]
- [[BOOLEAN]]
- [[BIGSERIAL]]
- [[TEXT]]
- [[INTEGER]]
- [[DML]]
- [[DQL]]
- [[Primary Key]]
- [[NULL]]
