# Practice Session: Ontology-Driven Schema Design

Level: Intermediate  
Prerequisites: `concepts/intermediate/21-ontology-driven-schema-design.md`

## Goal

Practice translating an ontology (concept map) into a PostgreSQL schema. Build a schema from an ontology model for a content management system, then verify the schema reflects the ontology correctly.

## Quick start

```bash
# blocked: Docker not accessible; validate when Docker Desktop WSL2 integration is enabled
docker exec cfp_postgres psql -U cfp -d cfp -f practice/intermediate/13-ontology-modeling/setup.sql
```

## Files

| File | Purpose |
|------|---------|
| setup.sql | CMS schema: authors, articles, tags, article_tags; derived from ontology |
| exercises.md | Map CMS ontology to tables, add constraints that enforce ontology rules, query to verify |
| solutions.md | Full schema with ontology annotations in COMMENT ON |
| reflection.md | Questions on ontology-schema mapping, when to break the model |
| ontology-notes.md | [[entity-relationship-ontology]] [[schema-design-ontology]] |
| troubleshooting.md | Schema doesn't match ontology, missing FK, wrong cardinality |
| references.md | Ontology resources, PostgreSQL COMMENT ON docs |

## What you'll learn

- Translating entities → tables, relationships → FK constraints
- Using `COMMENT ON TABLE` and `COMMENT ON COLUMN` as ontology annotations
- Detecting ontology gaps in existing schemas
- How Obsidian graph view visualizes the concept connections for this repo

## MCP and agent perspective

Ontology-driven schema design helps agents understand the data model. Well-named tables and columns with `COMMENT ON` descriptions can be exposed to agents via a schema-introspection MCP tool.
