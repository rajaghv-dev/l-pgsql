# Reflection — Ontology-Driven Schema Design

## Key takeaways
- Classify domain nouns before modeling: entity, event, role, value object — each maps to a different table pattern.
- Events are append-only; entities are mutable; roles are relationships with attributes; value objects are JSONB.
- The FK graph IS the ontology — every FK is a declared relationship in the domain.
- ltree encodes taxonomic hierarchies without recursive CTEs.
- FTS + pgvector together provide both keyword recall and semantic similarity.

## The conference ontology map
| Domain concept | Modeling approach | Table |
|---|---|---|
| Conference | Entity (identity, lifecycle) | `conferences` |
| Speaker | Entity (identity, bio) | `speakers` |
| Talk | Entity (identity, FTS, embedding) | `talks` |
| Topic | Entity + hierarchy (ltree) | `topics` |
| Submission | Event (append-only, timestamped) | `submissions` |
| Registration | Event (attendance fact) | `registrations` |
| Presenter | Role (talk ↔ speaker with role type) | `presentation_roles` |
| Bio data | Value object (variable attributes) | JSONB in speakers |

## What this practice integrates
- ltree (Concept 13) — topic hierarchy
- FTS (Concept 11) — talk search
- pgvector (Concept 15) — semantic similarity
- JSONB (Concept 10) — bio_data
- Ontology principles (Concept 21) — schema design methodology

## What to explore next
- Stage 12 (Advanced): WAL, replication, partitioning
- Practice 12: Observability — measure which ontology queries are most expensive
- RLS (Practice 10) — add conference-scoped access control
