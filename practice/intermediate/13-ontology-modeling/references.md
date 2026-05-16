# References — Ontology-Driven Schema Design

## PostgreSQL official documentation
- ltree: https://www.postgresql.org/docs/16/ltree.html
- WITH RECURSIVE: https://www.postgresql.org/docs/16/queries-with.html
- pgvector: https://github.com/pgvector/pgvector
- GENERATED columns: https://www.postgresql.org/docs/16/ddl-generated-columns.html
- JSONB: https://www.postgresql.org/docs/16/datatype-json.html

## Ontology and domain modeling
- Eric Evans, *Domain-Driven Design* (Addison-Wesley) — entity, value object, aggregate, event
- Vaughn Vernon, *Implementing Domain-Driven Design* (Addison-Wesley) — practical DDD
- Martin Fowler, "Patterns of Enterprise Application Architecture" (Addison-Wesley)
- Alberto Brandolini, "Event Storming": https://www.eventstorming.com/
- W3C OWL 2 Overview: https://www.w3.org/TR/owl2-overview/ — formal ontology language
- RDF Schema: https://www.w3.org/TR/rdf-schema/ — class and property declarations

## Blog posts
- Martin Fowler, "Ubiquitous Language": https://martinfowler.com/bliki/UbiquitousLanguage.html
- Martin Fowler, "Value Object": https://martinfowler.com/bliki/ValueObject.html
- "Event Sourcing with PostgreSQL": https://www.postgresql.org/docs/current/sql-createtable.html

## Related concepts in this repo
- `concepts/intermediate/21-ontology-driven-schema-design.md`
- `concepts/intermediate/13-hierarchical-data-with-ltree-and-recursive-cte.md`
- `concepts/intermediate/10-jsonb-modeling-tradeoffs.md`
- `concepts/intermediate/15-vector-search-with-pgvector.md`
- `concepts/intermediate/11-full-text-search-design.md`
