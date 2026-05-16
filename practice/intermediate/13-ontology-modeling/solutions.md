# Solutions — Ontology-Driven Schema Design

**Status: blocked — Docker not accessible in this session**

## Exercise 1 solution
ltree `<@` (is descendant of) finds all topics under `tech.db`: Databases, PostgreSQL, Performance, Security. The hierarchy is encoded in the path — no recursive CTE needed.

Talks in `tech.db.postgres` subtopic: all talks whose topic's ltree path is `<@` (under) `tech.db.postgres`. This single operator replaces a recursive CTE that would otherwise traverse the topic tree.

## Exercise 2 solution
The GENERATED ALWAYS AS stored column auto-updates the tsvector when title or abstract changes. The GIN index makes FTS queries efficient. `websearch_to_tsquery` parses "pgvector RAG embedding" into a multi-term AND query: `'pgvector' & 'rag' & 'embed'`.

## Exercise 3 solution
Cosine distance between talks measures how semantically similar their topics are in the (toy) embedding space. The performance talk (`[0.10, 0.82, 0.35]`) is closest to the RLS talk (`[0.18, 0.75, 0.38]`) in the technical cluster.

In production with real embeddings: talks with similar keywords and abstracts would cluster, enabling "recommend similar talks" features without explicit topic tagging.

## Exercise 4 solution
Multi-hop: Conference → Talks → PresentationRoles → Speakers, with Topics joined in. This query traverses the ontological graph following the defined relationships. The ontology-driven schema makes these joins natural — each JOIN follows a declared entity relationship.

## Exercise 5 solution
The FK inspection query returns the ontological graph:
- `talks` → `conferences` (a talk belongs to a conference)
- `talks` → `topics` (a talk is categorized in a topic)
- `submissions` → `talks` and `speakers` (submission links them)
- `presentation_roles` → `talks` and `speakers` (role relationship)
- `registrations` → `conferences` and `speakers` (participation event)

This graph IS the ontology, expressed in SQL constraints.

## Exercise 6 solution
`@>` on a JSONB array checks if the array contains a specific element. `'{"specialties": ["PostgreSQL"]}'::jsonb @>` checks if the specialties array contains "PostgreSQL" as an element.

`jsonb_array_elements_text()` unnests the array, enabling relational queries over JSONB array data. This is the bridge between the JSONB (open-world) and relational (closed-world) layers.

## Exercise 7 solution
Orphan check: talks with no presentation role indicate a data integrity gap — accepted talks should always have at least one presenter. This is a cross-table constraint that can't be expressed as a simple CHECK — it requires a trigger or periodic CHECK query.

Consistency check: accepted talks should always have an accepted submission. If this query returns rows, the submission workflow has a bug (talk was accepted without a formal submission decision being recorded).

## Reflection answers
1. `submissions` is an event because it records the fact that a speaker submitted a talk at a specific point in time. If a speaker withdraws and resubmits, these are two separate events with separate timestamps. Modeling submission status as a column on `talks` would lose the event history.
2. `presentation_roles` is a role relationship: it records WHO presents WHAT in WHAT capacity — a durable fact about the presentation assignment. `submissions` is an event: it records that a speaker APPLIED at a point in time. The role is about the conference's decision; the submission is about the speaker's action.
3. `bio_data` is JSONB because speaker biographies are variable (different speakers list different fields — GitHub, Twitter, company, certifications). The attribute set is open-ended and not uniformly queried. If `company` became universally required and queried, it would be promoted to a typed column.
4. To model the same talk at two conferences, create two separate `talks` rows (one per conference) referencing the appropriate `conference_id`. A "template talk" pattern: add a `source_talk_id UUID REFERENCES talks(id)` to track which talks are re-runs of a prior talk. Alternatively, create a `talk_templates` table (the Platonic ideal) and link each concrete `talk` instance to its template.
