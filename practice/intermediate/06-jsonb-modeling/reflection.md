# Reflection — JSONB Modeling

## Key takeaways
- JSONB is best for genuinely variable-structure data, not as a workaround for avoiding schema design.
- GIN indexes make JSONB containment queries fast but have significant storage overhead.
- Generated columns with B-tree indexes are the right tool when a JSONB key becomes a frequently-queried field.
- The `jsonb_field_registry` pattern (a data dictionary for JSONB fields) prevents schema-in-schema chaos in large teams.

## When to use JSONB vs columns
| Use JSONB | Use real columns |
|---|---|
| Variable attributes per row | Fixed, known attributes |
| Schema evolves rapidly | Schema is stable |
| Attributes are rarely queried directly | Attributes are in WHERE/JOIN |
| Storing external API payloads | Core domain data |
| EAV replacement | Type-safe constraints needed |

## Common mistakes
- Using JSONB for all columns to "avoid schema changes" — loses type safety, constraint enforcement, and query efficiency
- Not indexing JSONB columns used in WHERE clauses
- Using `->` when `->>` is needed (JSON type vs text type confusion)
- Storing nested objects 5+ levels deep — becomes unreadable and hard to query

## What to explore next
- Concept 11: Full-text search — building search vectors from JSONB text fields
- Practice 13: Ontology modeling — JSONB as an ontology extension mechanism
