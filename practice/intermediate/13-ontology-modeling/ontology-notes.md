# Ontology Notes — Ontology-Driven Schema Design

## The conference schema as a formal ontology
This practice's schema is a direct implementation of an ontology:

**Classes (entities):**
- Conference — bounded in time and space, has identity
- Speaker — a person with expertise and identity
- Talk — an intellectual contribution with topic, abstract, and searchable content
- Topic — a node in the knowledge taxonomy

**Properties (attributes):**
- Speaker::bio_data — open-world attributes (JSONB)
- Talk::title, abstract — textual properties with FTS index
- Talk::embedding — semantic coordinate (vector)
- Topic::path — hierarchical position (ltree)

**Relations (FKs, join tables):**
- Talk *belongsTo* Conference (FK)
- Talk *categorizedAs* Topic (FK)
- Speaker *submits* Talk (via Submission event)
- Speaker *presents* Talk (via PresentationRole, with role attribute)
- Speaker *attends* Conference (via Registration event)

## Separation of event from entity
The most important ontological distinction in this schema: `submissions` and `registrations` are event tables, not status columns on entity tables. This distinction:
1. Preserves event history (who submitted when, with what decision)
2. Allows multiple events per entity (a talk can be submitted to multiple conferences)
3. Enables event-sourcing queries (replay events to reconstruct state)
4. Makes the causal chain explicit (submission → decision → role assignment)

## ltree as ontological taxonomy
The `topics.path` column is an operationalized ontological taxonomy. The `<@` (is-descendant-of) operator implements the `rdfs:subClassOf` transitive closure in ontology terms. A query for talks in `tech.db.*` retrieves all talks whose topic is a specialization of Databases.

## pgvector as emergent ontology
The `talks.embedding` column encodes an emergent ontology — the similarity structure learned by the embedding model from training data. Two talks are semantically related if their embeddings are geometrically close, regardless of whether they share an explicit topic tag. This supplements the explicit ontology (ltree taxonomy) with implicit semantic relationships.

## Obsidian graph of this schema
- Conference → node: Entity/ConferenceEdition
- Speaker → node: Entity/Person
- Talk → node: Entity/Contribution
- Topic → node: Entity/Concept (hierarchical)
- Submission → edge type: submitted (Speaker → Talk, with timestamp and decision)
- PresentationRole → edge type: presents (Speaker → Talk, with role attribute)
- Registration → edge type: attends (Speaker → Conference)
- Talk --categorizedAs--> Topic (edge via FK)
- Talk --belongsTo--> Conference (edge via FK)
