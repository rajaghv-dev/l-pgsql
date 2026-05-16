# Ontology for Database Learning

Level: Beginner

## One-line intuition

An ontology is a structured map of concepts and relationships — it tells you what things are, how they relate, and why the distinctions matter.

## Why this exists

Databases are large concept spaces. You can memorize syntax, but you understand a system when you can navigate its concept map: "a table IS A relation, a relation HAS MANY columns, a column HAS ONE type, a type HAS constraints." This mental graph is an ontology. Building it deliberately accelerates learning.

## First-principles explanation

In philosophy, ontology is the study of what exists and how things relate. In knowledge engineering and database learning, it is a **concept map** — a directed graph where nodes are concepts and edges are named relationships (IS A, HAS, REQUIRES, CONTRASTS WITH).

A concept map for PostgreSQL looks like:

```
database
  └── schema (contains)
        └── table (contains)
              ├── column (has many)
              │    ├── type (has one)
              │    └── constraint (has many)
              ├── index (can have many)
              │    └── access method (has one: B-tree, GIN, GiST...)
              └── row (has many at runtime)

transaction
  ├── BEGIN
  ├── COMMIT
  └── ROLLBACK

query
  ├── SELECT (projection)
  ├── FROM + JOIN (join)
  ├── WHERE (filter)
  ├── GROUP BY (partition)
  ├── HAVING (filter on groups)
  └── ORDER BY / LIMIT (presentation)
```

## Micro-concepts

| Relationship type | Meaning | Example |
|-------------------|---------|---------|
| IS A | Specialization | A view IS A relation |
| HAS | Composition | A table HAS columns |
| REQUIRES | Dependency | An index REQUIRES a table to exist |
| CONTRASTS WITH | Distinction | ivfflat CONTRASTS WITH hnsw |
| EXTENDS | Extension | pgvector EXTENDS PostgreSQL |
| IMPLEMENTS | Realization | MVCC IMPLEMENTS isolation |

## Beginner view

When you learn a new concept, ask:

1. **What IS IT?** ("A view is a named SELECT query stored in the database.")
2. **What does it HAVE?** ("A view has a name, a definition, and columns.")
3. **What does it REQUIRE?** ("A view requires at least one base table.")
4. **What does it enable?** ("A view enables reuse, simplification, and access control.")
5. **What does it contrast with?** ("A view contrasts with a materialized view — one stores data, the other does not.")

Answering these five questions for every concept builds a concept graph in your head.

## Intermediate view

**The Obsidian graph view** turns this repo into a visual concept map. Every `[[wikilink]]` in a markdown file becomes an edge in the graph. The `ontology-notes.md` files in each practice folder are designed to add edges to this graph.

Open this repo as an Obsidian vault:

1. Open Obsidian → Open folder as vault → select `/mnt/d/wsl/l-pgsql`
2. Open Graph View (Ctrl+G)
3. Zoom to see concept clusters: SQL clauses cluster around `query`, index types cluster around `index`, ACID properties cluster around `transaction`

As you add more notes and link them, the graph grows. Dense clusters show where you have strong understanding. Isolated nodes show gaps.

**Naming things precisely** is not pedantry — it is clarity. "The primary key" vs "a unique index" vs "a candidate key" are different things. Sloppy naming leads to sloppy reasoning. When in doubt, look up the PostgreSQL documentation's own terminology and use it.

## Advanced view

Formal ontologies (OWL, RDF, SKOS) are machine-readable concept maps used in knowledge graphs and semantic web applications. PostgreSQL itself is not an ontology store, but:

- `ltree` extension stores hierarchical paths (category trees — a simple form of ontology).
- JSONB can store graph-like data (nodes and edges), but with limited traversal capabilities.
- Apache AGE (PostgreSQL extension) adds a graph database layer with Cypher query language.

For this learning repo, "ontology" means: your personal concept map, not formal OWL/RDF.

## Mental model

Think of your understanding of PostgreSQL as a city map:

- **Concepts** are buildings (table, index, transaction, role...).
- **Relationships** are roads between buildings (table HAS columns, index REQUIRES a table...).
- A **mental model** is being able to navigate the city without a GPS — you know which road connects which buildings.
- **Learning** is adding new buildings and roads.
- **Understanding** is knowing the fastest route between any two buildings.

## PostgreSQL view

The PostgreSQL system catalog (tables prefixed with `pg_`) is PostgreSQL's own ontology — it records what objects exist and how they relate:

```sql
-- What tables exist?
SELECT relname FROM pg_class WHERE relkind = 'r';

-- What indexes exist on what tables?
SELECT i.relname AS index_name, t.relname AS table_name
FROM pg_index ix
JOIN pg_class i ON i.oid = ix.indexrelid
JOIN pg_class t ON t.oid = ix.indrelid;

-- What columns does each table have?
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;
```

The system catalog is queryable with SQL — PostgreSQL knows its own ontology.

## SQL view

```sql
-- Explore PostgreSQL's self-knowledge (its ontology)
-- Tables and their row counts
SELECT relname, reltuples::bigint AS estimated_rows, relkind
FROM pg_class
WHERE relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND relkind IN ('r', 'v', 'm')  -- tables, views, materialized views
ORDER BY relname;

-- Index → table → column relationships
SELECT
    t.relname AS table_name,
    i.relname AS index_name,
    a.attname AS column_name,
    am.amname AS index_type
FROM pg_index ix
JOIN pg_class t ON t.oid = ix.indrelid
JOIN pg_class i ON i.oid = ix.indexrelid
JOIN pg_am am ON am.oid = i.relam
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
ORDER BY t.relname, i.relname;
```

## Non-SQL or hybrid view

Obsidian's graph view, mind maps (Miro, Mermaid diagrams), and concept mapping tools (CmapTools) all implement ontologies visually. For this repo, use Obsidian wikilinks (`[[table]]`, `[[index]]`, `[[transaction]]`) in markdown files — they build the graph automatically.

## Design principle

**Name things precisely, link them explicitly, review the graph.** A concept you cannot place in your concept map is a concept you have not yet understood. A concept with no connections is a concept you do not know how to use.

## Critical thinking

- An ontology is a model — a simplification of reality. PostgreSQL's own design choices (why a role is not a user, why a view is not a table) reflect design decisions, not natural laws. Understanding the design choices deepens understanding of the tool.
- "Understanding" is not binary. You can understand a concept at a surface level (syntax), a mechanical level (what it does), or a principled level (why it exists, what it contrasts with, when not to use it). This lesson format targets principled understanding.

## Creative thinking

Build a "vocabulary deck" in Obsidian or Anki: one card per concept, with the five questions (IS, HAS, REQUIRES, ENABLES, CONTRASTS) on the back. Review it when starting each new stage. Spaced repetition on a concept graph builds durable understanding.

## Systems thinking

Your mental model of PostgreSQL IS a system — a graph with feedback loops:

- Learning a new concept adds a node.
- Linking it to existing concepts adds edges.
- A dense graph means you can reason about unfamiliar situations by traversal (analogy).
- A sparse graph means each new situation requires memorizing a new fact.

Invest in edges, not just nodes. Every new concept should connect to at least two existing concepts.

## MCP and agent perspective

An AI agent (like Claude) uses an implicit ontology during every response. When you describe your database schema, the agent infers:

- `books.author_id IS A foreign key → it references authors.id`
- `A JOIN connects books and authors via author_id → author_id`
- `An index on author_id speeds up the JOIN`

The clearer your schema names and comments, the better the agent can navigate its ontology to answer your questions. Self-documenting schemas (with `COMMENT ON TABLE/COLUMN`) are an investment in agent-assisted reasoning.

## Ontology perspective

This lesson is recursive — it is an ontology lesson about ontology:

- **Ontology** IS A knowledge representation tool.
- **Concept map** IS A graph (nodes = concepts, edges = relationships).
- **Obsidian graph view** IMPLEMENTS concept map visualization.
- **System catalog** IS A machine-readable ontology of a PostgreSQL database.
- **Mental model** IS A cognitive ontology — the concept map inside your head.
- **Learning** BUILDS mental models.
- **Teaching** TRANSMITS mental models.

## Practice session

Every `ontology-notes.md` file in this repo is a practice of ontological thinking. Revisit the completed practice folders and check their `ontology-notes.md` files after completing a new stage — connections become visible that were not visible when you first wrote them.

## References

| Resource | URL | Why |
|----------|-----|-----|
| Obsidian | https://obsidian.md | Graph view for this repo's concept map |
| PostgreSQL docs — System Catalogs | https://www.postgresql.org/docs/current/catalogs.html | PostgreSQL's own ontology |
| Wikipedia — Ontology (information science) | https://en.wikipedia.org/wiki/Ontology_(information_science) | Background on formal ontologies |
| Concept Maps (Novak) | https://www.sciencedirect.com/science/article/pii/S0959475206000339 | Original concept mapping research |
