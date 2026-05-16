# Ontology Entry: <!-- Concept Name -->

> File location: `ontology/<!-- concept-name -->.md`
>
> **How to use this template:**
> One file per concept. Keep definitions precise and short.
> Fill in the relationship fields carefully — the graph depends on them.
> Obsidian wikilinks (`[[concept]]`) become graph edges when the repo is opened as a vault.
> Run the SQL examples with: `docker exec cfp_postgres psql -U cfp -d cfp -c "..."`

---

## Concept name

`<!-- concept name, e.g., index, transaction, RLS policy, trigger, constraint -->`

---

## Definition

<!-- TODO: fill in for this specific concept -->
One to three sentences. Precise enough to distinguish this concept from its siblings.
Avoid circular definitions (don't use the concept name in the definition).

Example (index): "A data structure maintained by PostgreSQL alongside a table that allows the query executor to locate rows matching a condition without reading every row in the table."

---

## Related concepts

<!-- TODO: fill in for this specific concept -->
Concepts at the same level of abstraction — neither parent nor child, but meaningfully connected:

- `[[<!-- related concept 1 -->]]` — <!-- one sentence explaining how they connect -->
- `[[<!-- related concept 2 -->]]` — <!-- one sentence explaining how they connect -->
- `[[<!-- related concept 3 -->]]` — <!-- one sentence explaining how they connect -->

---

## Parent concepts

<!-- TODO: fill in for this specific concept -->
The broader categories this concept belongs to.
List from immediate parent to most general:

- `[[<!-- immediate parent -->]]` — <!-- this concept IS A ... -->
- `[[<!-- broader parent -->]]` — <!-- which IS A ... -->

---

## Child concepts

<!-- TODO: fill in for this specific concept -->
Specializations or sub-types of this concept:

- `[[<!-- child 1 -->]]` — <!-- how it specializes the parent concept -->
- `[[<!-- child 2 -->]]` — <!-- how it specializes the parent concept -->
- `[[<!-- child 3 -->]]` — <!-- how it specializes the parent concept -->

---

## Contrasting concepts

<!-- TODO: fill in for this specific concept -->
Concepts that are often confused with this one or that represent an alternative approach:

- `[[<!-- contrast 1 -->]]` — <!-- key difference: "unlike X, this concept does Y" -->
- `[[<!-- contrast 2 -->]]` — <!-- key difference -->

---

## SQL representation

<!-- TODO: fill in for this specific concept -->
How do you create, inspect, and remove this concept in PostgreSQL?

### Create

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: DDL to create this concept, e.g., CREATE INDEX / CREATE TRIGGER / ALTER TABLE -->
"
```

### Inspect

```bash
# Find it in the system catalog
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT <!-- relevant columns -->
  FROM <!-- pg_class / pg_indexes / pg_policies / pg_triggers / information_schema view -->
  WHERE <!-- filter to find this specific concept -->;
"
```

### Modify (if applicable)

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: ALTER / REPLACE command if concept is mutable -->
"
```

### Remove

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: DROP command, e.g., DROP INDEX / DROP TRIGGER / ALTER TABLE DROP CONSTRAINT -->
"
```

---

## PostgreSQL view

<!-- TODO: fill in for this specific concept -->
How PostgreSQL represents this concept internally:

- **System catalog table:** `<!-- pg_class / pg_index / pg_constraint / pg_trigger / pg_policy -->`
- **Key catalog columns:** `<!-- e.g., relname, relkind, indisprimary, contype, tgtype -->`
- **Statistics view:** `<!-- pg_stat_<!-- view --> -->` — what to look for
- **Version introduced:** PostgreSQL <!-- version -->

```bash
# Inspect the system catalog entry
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT <!-- key catalog columns -->
  FROM <!-- catalog table -->
  WHERE <!-- filter -->;
"
```

---

## MCP and agent view

<!-- TODO: fill in for this specific concept -->
How this concept affects an AI agent or MCP tool:

- **Agent reads this concept as:** <!-- what the agent perceives, e.g., "a list of available indexes on a table" -->
- **Agent writes via this concept:** <!-- e.g., "the agent INSERTs rows; indexes are maintained automatically by PostgreSQL" -->
- **What the agent must know:** <!-- e.g., "the index exists and will accelerate the query" vs. "the agent must not manage index creation" -->
- **What must NOT be exposed to the agent:** <!-- e.g., "index internals, page layout, OIDs" -->
- **Safety implication:** <!-- e.g., "dropping an index can cause performance degradation — should require human approval" -->
- **Permission required:** <!-- e.g., "CREATE INDEX requires CONNECT + the owning role; SELECT does not" -->

---

## Practical implication

<!-- TODO: fill in for this specific concept -->
When should a practitioner think about this concept?

| Situation | Implication |
|-----------|-------------|
| <!-- situation 1, e.g., "table exceeds 10k rows" --> | <!-- implication, e.g., "create an index on frequently filtered columns" --> |
| <!-- situation 2 --> | <!-- implication --> |
| <!-- situation 3 --> | <!-- implication --> |

**Common mistake:** <!-- the most frequent misunderstanding about this concept -->
**Corrected understanding:** <!-- the precise version of the concept -->

---

## Concept cluster

How this concept fits in the broader ontology graph:

```
<!-- ASCII hierarchy / cluster map -->
<!-- example for index:
database object
  └── index
       ├── B-tree index    ← default, equality and range
       ├── GIN index       ← full-text search, JSONB, arrays
       ├── GiST index      ← geometric, full-text, exclusion
       ├── BRIN index      ← large tables with natural ordering
       └── Hash index      ← equality only
-->
```

---

## References

<!-- TODO: fill in for this specific concept -->

| Title | URL | Type | Level | Time |
|-------|-----|------|-------|------|
| PostgreSQL docs — <!-- concept --> | https://www.postgresql.org/docs/current/<!-- page --> | Official docs | <!-- level --> | <!-- time --> |
| <!-- TODO: additional reference --> | <!-- URL --> | <!-- type --> | <!-- level --> | <!-- time --> |

> If a reference cannot be verified, write: `TODO: Find verified reference for this concept.`
