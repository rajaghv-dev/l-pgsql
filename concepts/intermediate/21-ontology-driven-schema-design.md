# Ontology-Driven Schema Design

Level: Intermediate

## One-line intuition
Ontology-driven design asks "what is this thing really?" before asking "what table should it go in?" — aligning your schema with the true structure of your domain.

## Why this exists
Most schema problems stem from mistaking implementation convenience for domain truth. A table named `user_data` that stores orders, preferences, and login history conflates three different domain concepts into one container. Over time, this creates fragile joins, ambiguous column semantics, and migration pain. Ontology-driven design forces you to name and bound your entities precisely before you write a single CREATE TABLE.

## First-principles explanation
Ontology, borrowed from philosophy, is the study of what exists and how things relate. In schema design, it means: before modeling, define your domain entities (the things that exist independently), their attributes (properties that describe them), their relationships (how they connect), and their lifecycle (how they come to exist and cease to exist). A well-designed schema is a faithful projection of the ontology onto relational tables. When the ontology is clear, the schema is natural. When ontology is confused, schemas become baroque and hard to evolve. The key discipline: distinguish between an entity (a conference), an event (a talk at that conference), a role (a speaker at that talk), and a value (the speaker's bio). Each is a different kind of thing and deserves a different modeling approach.

## Micro-concepts
- **Entity**: a thing with independent identity that persists over time (`Person`, `Order`, `Event`)
- **Value object**: a thing defined entirely by its attributes, with no independent identity (`Address`, `Money`)
- **Relationship**: how entities connect — 1:1, 1:N, M:N, with or without attributes
- **Lifecycle**: when an entity is created, transitions through states, and is retired
- **Ubiquitous language**: the shared vocabulary between domain experts and engineers — your column names should use this language

## Beginner view
Before building a house, you make a blueprint. Ontology-driven design is the blueprint stage for your database: you draw the map of your domain before you start laying tables.

## Intermediate view
Start with a domain noun list from your product requirements. Classify each noun: Is it an entity (has identity, persists)? Is it a value object (defined by attributes only)? Is it a role (a relationship type)? Is it an event (a point-in-time occurrence)? Entities become tables. Value objects become columns or embedded JSONB. Roles become join tables with their own attributes. Events become append-only event tables. The clarity of this classification directly determines the quality of your schema.

## Advanced view
Ontology-driven design connects to Domain-Driven Design (DDD): bounded contexts, aggregates, and ubiquitous language map cleanly onto PostgreSQL schema boundaries (schemas as bounded contexts), primary tables (aggregates), and naming conventions (ubiquitous language as column names). In multi-schema multi-tenant systems, each tenant's schema is a bounded context instantiation. The `ltree` extension models ontological hierarchies directly. JSONB can represent open-world entities — things whose attribute set is not fully known at design time.

## Mental model
Think of your domain as a map. Ontology defines the territories (entities), roads (relationships), and landmarks (events). Schema design is the act of drawing that map precisely enough that the database can navigate it.

## PostgreSQL view
```sql
-- Inspect the ontology of an existing schema
SELECT
  t.table_name,
  c.column_name,
  c.data_type,
  c.is_nullable,
  c.column_default
FROM information_schema.tables t
JOIN information_schema.columns c USING (table_schema, table_name)
WHERE t.table_schema = 'public'
  AND t.table_type = 'BASE TABLE'
ORDER BY t.table_name, c.ordinal_position;

-- Inspect FK relationships (the ontological graph)
SELECT
  tc.table_name AS child_table,
  kcu.column_name AS child_column,
  ccu.table_name AS parent_table,
  ccu.column_name AS parent_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu USING (constraint_name, table_schema)
JOIN information_schema.constraint_column_usage ccu USING (constraint_name, table_schema)
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public';
```

## SQL view
```sql
-- Entity: has identity (UUID PK), lifecycle timestamps, domain noun name
CREATE TABLE speakers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  email       TEXT UNIQUE NOT NULL,
  bio         TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Event: append-only, timestamped, references entities
CREATE TABLE talk_submissions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  speaker_id   UUID NOT NULL REFERENCES speakers (id),
  conference_id UUID NOT NULL REFERENCES conferences (id),
  title        TEXT NOT NULL,
  abstract     TEXT,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status       TEXT NOT NULL DEFAULT 'pending'
             CHECK (status IN ('pending','accepted','rejected','withdrawn'))
);

-- Role: a relationship with its own attributes
CREATE TABLE talk_co_presenters (
  talk_id    UUID NOT NULL REFERENCES talks (id),
  speaker_id UUID NOT NULL REFERENCES speakers (id),
  role       TEXT NOT NULL DEFAULT 'co-presenter',
  PRIMARY KEY (talk_id, speaker_id)
);

-- Value object: embedded, not independently referenceable
-- (e.g., mailing_address stored as JSONB column on speakers)

-- blocked: Docker not accessible; validate against cfp_postgres when available
```

## Non-SQL or hybrid view
Open-world entities — where you don't know all attributes at design time — are well-served by JSONB. But only for their variable attributes; fixed, queried, or constrained attributes should always be typed columns. The ontology tells you which attributes are stable (typed columns) and which are exploratory (JSONB).

## Design principle
Name every table with a domain noun, not a technical descriptor: `orders` not `order_data`, `speakers` not `user_speaker_map`. The name is a claim about the ontological identity of the entity it represents.

## Critical thinking
Two engineers looking at the same domain may produce different ontologies — and therefore different schemas — both technically correct. What processes or artifacts (event storming, domain model reviews, glossaries) can converge ontological disagreements before they become migration debt?

## Creative thinking
Could you store an explicit ontology graph (entities, relationships, cardinalities) as PostgreSQL data itself — using a self-describing schema — and use it to drive automated documentation, validation, and API generation?

## Systems thinking
Ontology-driven design interacts with API design (resource shapes follow entity boundaries), event sourcing (events correspond to lifecycle transitions of entities), RLS policies (tenant_id maps to the bounded context boundary), and search indexing (entities are the units of search).

## MCP and agent perspective
An AI agent operating on a database benefits from an explicit ontology: it can reason about what entities exist, how they relate, and what operations are semantically valid. An agent that understands the ontology knows that deleting a `conference` cascades to `talks` and `submissions` — and can warn the human operator before executing. Agents should be trained on domain glossaries, not just schema dumps.

## Ontology perspective
Ontology-driven design is the meta-level above schema design — it is the discipline of being precise about domain concepts before encoding them in SQL. The ontology is the "theory" of the domain; the schema is the "model" that implements that theory in a database.

The pipeline: conceptual model (domain nouns, relationships, events) → logical model (normalized entities, attributes, cardinalities) → physical schema (CREATE TABLE, indexes, constraints).

Obsidian graph → schema design pipeline:
- Each Obsidian node = a candidate entity or value type
- Each Obsidian edge = a candidate relationship (FK or join table)
- Edge cardinality (one-to-many, many-to-many) = FK vs join table decision
- Temporal edges (event-linked relationships) = event tables with timestamps

The goal of the ontology phase is to surface hidden concepts before they become hidden columns. A schema with good ontological grounding has tables whose names map directly to domain entities, columns whose names use the domain's ubiquitous language, and foreign keys that reflect real domain relationships.

## Practice session
See `practice/intermediate/13-ontology-modeling/` for hands-on exercises building an ontology-grounded schema with ltree, JSONB, and pgvector.

## References
- PostgreSQL docs — Data Definition: https://www.postgresql.org/docs/16/ddl.html
- PostgreSQL docs — information_schema: https://www.postgresql.org/docs/16/information-schema.html
- Eric Evans, *Domain-Driven Design* (Addison-Wesley) — entity, value object, aggregate patterns
- Martin Fowler, "Ubiquitous Language": https://martinfowler.com/bliki/UbiquitousLanguage.html
- Alberto Brandolini, "Event Storming" (domain modeling workshop): https://www.eventstorming.com/
- "Ontology-Driven Data Modeling": https://www.w3.org/TR/owl2-overview/ (OWL as formal ontology language)
