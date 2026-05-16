# ltree (ltree)

Level: Intermediate
Available locally: Yes

## One-line purpose

Store and query hierarchical label paths (e.g., `org.engineering.backend.auth`) with fast ancestor/descendant/pattern lookups using GiST or GIN indexes.

## Why this exists

Representing tree structures in SQL is notoriously awkward. The classic adjacency list (`parent_id`) requires recursive CTEs for traversal and cannot be indexed for ancestor queries. The closure table pattern is verbose. `ltree` solves this by encoding the full path from root to node as a dot-separated label string and providing first-class operators and index support for that path — making ancestor, descendant, and pattern queries fast and readable.

## Install

```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS ltree;
SELECT extname, extversion FROM pg_extension WHERE extname = 'ltree';
```

## Core operations

### Define a table with ltree

```sql
-- blocked: Docker not accessible
CREATE TABLE categories (
    id       SERIAL PRIMARY KEY,
    path     ltree NOT NULL,    -- e.g., 'electronics.computers.laptops'
    label    TEXT
);

INSERT INTO categories (path, label) VALUES
    ('electronics',                   'Electronics'),
    ('electronics.computers',         'Computers'),
    ('electronics.computers.laptops', 'Laptops'),
    ('electronics.computers.desktops','Desktops'),
    ('electronics.phones',            'Phones');
```

Labels must match `[A-Za-z0-9_]+` (alphanumeric and underscore only). Use underscores for spaces.

### Ancestor and descendant operators

| Operator | Meaning | Example |
|----------|---------|---------|
| `@>`     | Is ancestor of (or equal) | `'electronics' @> path` |
| `<@`     | Is descendant of (or equal) | `path <@ 'electronics'` |
| `=`      | Exact match | `path = 'electronics.computers'` |
| `<>` | Not equal | |

```sql
-- blocked: Docker not accessible
-- All descendants of 'electronics.computers'
SELECT path, label
FROM categories
WHERE path <@ 'electronics.computers';
-- Returns: laptops, desktops (and computers itself)

-- All ancestors of 'electronics.computers.laptops'
SELECT path, label
FROM categories
WHERE path @> 'electronics.computers.laptops';
-- Returns: electronics, electronics.computers, electronics.computers.laptops
```

### Pattern matching with lquery

`lquery` is a pattern language for ltree paths. Use `~` to match.

```sql
-- blocked: Docker not accessible
-- Match exactly 3 levels deep under electronics
SELECT path FROM categories WHERE path ~ 'electronics.*.*';

-- Match any path containing 'computers' at any depth
SELECT path FROM categories WHERE path ~ '*.computers.*';

-- * matches any single label; {n,m} matches n to m labels
SELECT path FROM categories WHERE path ~ 'electronics.{1,2}';

-- Case-insensitive: append 'i' modifier
SELECT path FROM categories WHERE path ~ '*.Computers.*:i';
```

### Full-text pattern matching with ltxtquery

`@` operator matches against an `ltxtquery` — boolean combinations of labels.

```sql
-- blocked: Docker not accessible
-- Paths containing both 'electronics' and 'computers' anywhere
SELECT path FROM categories WHERE path @ 'electronics & computers';

-- Paths containing 'laptops' or 'desktops'
SELECT path FROM categories WHERE path @ 'laptops | desktops';
```

### Path manipulation functions

```sql
-- blocked: Docker not accessible
-- Number of labels in a path
SELECT nlevel('electronics.computers.laptops');  -- 3

-- Subpath: extract a portion
SELECT subpath('electronics.computers.laptops', 0, 2);  -- 'electronics.computers'
SELECT subpath('electronics.computers.laptops', 2);      -- 'laptops'

-- Find index of a label
SELECT index('electronics.computers.laptops', 'computers');  -- 1

-- Concatenate paths
SELECT 'electronics' || '.' || 'phones'::ltree;  -- 'electronics.phones'

-- Get parent (remove last label)
SELECT subpath('electronics.computers.laptops', 0,
               nlevel('electronics.computers.laptops') - 1);
-- 'electronics.computers'
```

## Index types

### GiST index — recommended default

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_categories_path_gist ON categories USING GiST (path);
```

- Supports: `<@`, `@>`, `@`, `~`, `=`
- Best for: mixed workload (ancestor, descendant, and pattern queries)
- Slightly lossy (recheck): exact match verified after index scan

### GIN index — best for `@` (ltxtquery)

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_categories_path_gin ON categories USING GIN (path);
```

- Best for: `@` (ltxtquery boolean match) and `~` (lquery pattern)
- Exact (no recheck needed)
- Larger index size than GiST; slower updates

### Which to choose

| Use case | Index |
|----------|-------|
| Ancestor/descendant traversal | GiST |
| Pattern matching (`~`) | GiST or GIN |
| ltxtquery boolean (`@`) | GIN preferred |
| Mixed | GiST (simpler ops, one index covers most queries) |

## Performance characteristics

- Index lookup for `<@` and `@>` is O(log n) with GiST
- Deep trees (> 10 levels) are fine — path length is the only constraint (max 256 labels, 65535 bytes total)
- `nlevel()` is O(path length), not O(tree size)
- For very large trees, partition by top-level label (e.g., one partition per root node)
- `lquery` with leading wildcard (`'*.label'`) can be slow — prefer anchored patterns or GIN

## When to use

- Category/taxonomy trees (e-commerce, content management)
- Organizational hierarchies (org charts, reporting lines)
- Permission/role trees: `WHERE user_role_path <@ 'org.admin'` — check if a role is under admin
- File system path simulation
- Geographic hierarchy: `country.state.city.district`
- Forum thread nesting (breadcrumb navigation)

## When NOT to use

- Frequently restructured trees (reparenting requires rewriting all descendant paths)
- Graphs with multiple parents — `ltree` is strictly a tree (single parent per node)
- Labels with special characters (only `[A-Za-z0-9_]` allowed)
- When you need referential integrity on the hierarchy — `ltree` paths are strings, not foreign keys; maintain integrity in application code or triggers
- Very flat data (1–2 levels) — a simple enum or `parent_id` is simpler

## Alternatives

| Alternative | When to prefer |
|-------------|---------------|
| Adjacency list + recursive CTE | Simpler schema; hierarchy changes are cheaper |
| Nested sets (left/right bounds) | Fast subtree reads; complex writes |
| Closure table | Full ancestor/descendant with FK integrity; more storage |
| JSONB array of ancestor IDs | Simple path storage without ltree operators |
| `pg_trgm` | Path search by partial string match (no tree semantics) |

## MCP and agent perspective

- **Permission tree navigation**: `WHERE user_path <@ 'org.admin.superuser'` — check if a user's role path is under a required permission node in a single indexed query; no recursive CTE needed
- **Role ancestry check**: `SELECT 'org.engineering.backend' <@ 'org.engineering'` returns `true` — agents can verify permission containment without loading the full tree
- **Scoped queries**: `WHERE resource_path <@ $agent_scope` limits an agent to operate only within its assigned subtree — a clean, indexable authorization pattern
- Agents must validate that label values match `[A-Za-z0-9_]+` before constructing ltree literals; invalid characters cause a parse error, not silent truncation

## Ontology connection

- Lives under `extensions/data-types/` — a specialized column type with tree semantics
- Connects to: `hstore` (metadata on tree nodes), `pg_trgm` (fuzzy search on path labels), GiST indexes (shared index type with PostGIS, `btree_gist`)
- Concept map: ltree → label paths → GiST index → ancestor/descendant operators → permission hierarchies

## References

- [PostgreSQL ltree docs](https://www.postgresql.org/docs/16/ltree.html)
- [ltree operator reference](https://www.postgresql.org/docs/16/ltree.html#LTREE-OPS-TABLE)
- [Hierarchy patterns in PostgreSQL](https://www.postgresql.org/docs/16/queries-with.html) (recursive CTEs for comparison)
