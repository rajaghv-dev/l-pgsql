# Ontology Notes — Indexing Strategies

---

## Index as a materialized access path

An index is a pre-computed, materialized answer to a class of questions. Each index type materializes a different access algebra:

| Index type | Access algebra | Query class answered |
|---|---|---|
| B-tree | Ordered comparison | "Which entities have property P in range [a, b]?" |
| GIN | Inverted set membership | "Which entities contain element e?" |
| GiST | Spatial/topological | "Which entities are within region R?" |
| BRIN | Block range statistics | "Which block ranges contain entities with P in range [a, b]?" |
| Expression | Derived property | "Which entities have derived property f(P) = v?" |
| Partial | Sub-domain | "Which entities in sub-class S have property P = v?" |

---

## The event as an entity

`idx_events` represents events — occurrences in time. In ontological terms, an event is a **perdurant** (something that exists through time, with temporal parts), as opposed to a continuant (something that persists through time, like a customer).

This ontological distinction matters for indexing: events are append-only (they happened; they can't un-happen), making them ideal for BRIN indexes. Continuants (customers, products) are updated in place — BRIN would not help.

---

## JSONB as an open-world attribute store

The `payload` JSONB column uses an open-world model: any key can appear, and the schema does not constrain which keys exist. GIN indexes the payload's key-value pairs — building an inverted index over the open-world attribute space.

This is structurally equivalent to an RDF triple store where each JSONB key-value pair is a triple `(entity, property, value)`. GIN is the relational analog of a SPARQL index over a triple store.

---

## The expression index as property reification

An expression index on `LOWER(email)` reifies a derived property: "lowercase email." The index materializes the derived property as if it were a first-class attribute stored in the schema — but only for query performance, not for storage.

In Description Logics, this is analogous to a **derived role** defined by a property chain or transformation. The expression index makes the derived property queryable without storing it explicitly.

---

## Covering index as query-specific intensional structure

A covering index with INCLUDE pre-computes the answer to a specific class of queries (SELECT specific columns WHERE specific condition). It is a **query-specific intensional structure** — an intensional definition (the index condition and projection) that is materialized extensionally (as index pages).

This is the database equivalent of a cached view pre-computed for a specific query pattern, with automatic maintenance on writes.
