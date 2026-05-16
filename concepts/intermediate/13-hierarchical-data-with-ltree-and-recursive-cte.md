# Hierarchical Data with ltree and Recursive CTE
Level: Intermediate

## One-line intuition
ltree stores hierarchy paths as labeled strings with fast ancestor/descendant indexing; recursive CTEs traverse graphs dynamically — choose ltree for tree read performance, CTEs for flexible graph queries.

## Why this exists
Hierarchical data (org charts, category trees, file systems, comment threads) is common but awkward in flat relational tables. Two classic patterns — adjacency list (parent_id column) and nested sets — each have drawbacks. PostgreSQL provides ltree for materialized path trees and recursive CTEs for any graph traversal.

## First-principles explanation

### ltree
ltree represents a tree path as dot-separated labels: `"Technology.Programming.Python"`. Each node's full ancestry is encoded in its path.

Key operators:

| Operator | Meaning | Example |
|---|---|---|
| `@>` | Is ancestor | `'A' @> 'A.B.C'` → true |
| `<@` | Is descendant | `'A.B.C' <@ 'A'` → true |
| `~` | Matches lquery pattern | `path ~ '*.Python.*'` |
| `?` | Matches any lquery in array | `path ? array['*.Python','*.Ruby']` |
| `@` | Matches ltxtquery | full-text style tree query |

GiST and BTREE indexes on ltree paths make ancestor/descendant queries fast.

### Recursive CTE
SQL recursion via `WITH RECURSIVE`. Structure:
```sql
WITH RECURSIVE cte AS (
    -- Base case: starting nodes
    SELECT id, name, parent_id, 0 AS depth
    FROM nodes WHERE parent_id IS NULL

    UNION ALL

    -- Recursive case: join children to current frontier
    SELECT n.id, n.name, n.parent_id, cte.depth + 1
    FROM nodes n
    JOIN cte ON n.parent_id = cte.id
)
SELECT * FROM cte ORDER BY depth, id;
```

Recursive CTEs work for any graph (not just trees), but they iterate: PostgreSQL materializes each level before processing the next, which is efficient for shallow trees but can be slow for deep or wide graphs.

## Micro-concepts
- **ltree** — PostgreSQL extension; `label.label.label` path type
- **lquery** — pattern matching language for ltree paths: `*` matches any sequence of labels
- **ltxtquery** — full-text style matching on ltree labels
- **GiST index on ltree** — enables fast ancestor/descendant and pattern queries
- **adjacency list** — parent_id foreign key; simple but N queries to traverse N levels
- **nested sets** — left/right integers encoding subtree bounds; fast reads but expensive writes
- **materialized path** — store full path string; ltree is PostgreSQL's implementation
- **CYCLE detection** — `WITH RECURSIVE ... CYCLE id SET is_cycle USING path` prevents infinite loops on graphs
- **depth limiting** — add `WHERE depth < N` or use the `depth` counter to prevent runaway recursion

## Beginner view
Think of an org chart: every employee knows their manager (parent_id). A recursive CTE is like walking up the org chart: start at one person, then repeatedly ask "who is your manager?" until you reach the CEO. ltree is like printing each person's full chain of command as a path: "CEO.VP-Engineering.Director.Engineer".

## Intermediate view
Choose ltree when: the hierarchy is relatively static, you need fast subtree reads, you want ancestor/descendant queries without recursion. Choose recursive CTE when: the hierarchy changes frequently, the structure is a graph (not just a tree), or you need dynamic depth-limited traversal.

For comment threads with infinite nesting, ltree works well. For a bill-of-materials where parts can appear in multiple assemblies (a DAG, not a tree), use recursive CTE with cycle detection.

## Advanced view
ltree paths must be maintained on every move (updating a node requires updating all descendant paths). Use a trigger or application-layer batch update. For very deep trees (>20 levels), ltree paths can become long and index size grows. Recursive CTEs with bounded depth (`WHERE depth < 50`) are safer for arbitrary depth graphs.

`SEARCH BREADTH FIRST BY` / `SEARCH DEPTH FIRST BY` clauses (PostgreSQL 14+) allow controlling CTE traversal order and detecting cycles with the `CYCLE` clause.

## Mental model
ltree: pre-computed GPS coordinates for every node in the tree. Ancestor/descendant queries look up coordinates rather than walking the tree. Moving a node requires updating all coordinates that start with the old prefix.

Recursive CTE: a BFS/DFS algorithm expressed in SQL. Each iteration of UNION ALL is one step in the traversal. The working table grows with each step until no new rows are added.

## PostgreSQL view
```sql
CREATE EXTENSION IF NOT EXISTS ltree;

-- Category tree with ltree
CREATE TABLE categories (
    id      SERIAL PRIMARY KEY,
    name    TEXT NOT NULL,
    path    LTREE NOT NULL UNIQUE
);

CREATE INDEX ON categories USING gist(path);

INSERT INTO categories (name, path) VALUES
    ('Root',         'root'),
    ('Technology',   'root.tech'),
    ('Programming',  'root.tech.prog'),
    ('Python',       'root.tech.prog.python'),
    ('Web',          'root.tech.web'),
    ('Science',      'root.science');

-- Find all descendants of Technology
SELECT name, path FROM categories
WHERE path <@ 'root.tech'
ORDER BY path;

-- Find ancestors of Python
SELECT name, path FROM categories
WHERE path @> 'root.tech.prog.python'
ORDER BY path;

-- Pattern: all .web. nodes at any depth
SELECT name FROM categories WHERE path ~ '*.web.*';

-- ----------------------------------------------------------------
-- Recursive CTE — org chart
-- ----------------------------------------------------------------
CREATE TABLE employees (
    id        SERIAL PRIMARY KEY,
    name      TEXT NOT NULL,
    parent_id INT REFERENCES employees(id)
);

INSERT INTO employees VALUES
    (1, 'CEO',      NULL),
    (2, 'VP-Eng',   1),
    (3, 'VP-Sales', 1),
    (4, 'Dir-Eng',  2),
    (5, 'Engineer', 4);

WITH RECURSIVE org_tree AS (
    SELECT id, name, parent_id, 0 AS depth,
           ARRAY[id] AS path_ids
    FROM employees WHERE parent_id IS NULL

    UNION ALL

    SELECT e.id, e.name, e.parent_id, ot.depth + 1,
           ot.path_ids || e.id
    FROM employees e
    JOIN org_tree ot ON e.parent_id = ot.id
)
SELECT depth, REPEAT('  ', depth) || name AS org_chart, path_ids
FROM org_tree
ORDER BY path_ids;

-- Cycle-safe graph traversal (PostgreSQL 14+)
WITH RECURSIVE graph AS (
    SELECT id, parent_id FROM employees
    UNION ALL
    SELECT e.id, e.parent_id FROM employees e
    JOIN graph g ON e.parent_id = g.id
)
CYCLE id SET is_cycle USING visited_path
SELECT * FROM graph WHERE NOT is_cycle;
```

## SQL view
The SQL standard (SQL:1999) defines recursive CTEs. Most databases support them (MySQL 8+, SQL Server, SQLite). ltree is PostgreSQL-specific. Nested sets and closure tables are portable but require more complex application logic.

## Non-SQL or hybrid view
Graph databases (Neo4j) handle arbitrary graph traversal natively and more efficiently than recursive SQL for deep, complex graphs. For PostgreSQL-based apps, recursive CTE handles most practical hierarchies. For complex recommendation graphs or social networks, a dedicated graph database is more appropriate.

## Design principle
**Model hierarchies explicitly.** Avoid the common mistake of using adjacency lists and doing N+1 queries in application code. Use ltree for read-heavy category trees, recursive CTE for dynamic or graph-shaped data. Document the maximum expected depth and test with realistic data volumes — recursive CTEs can be surprisingly slow on large, deep trees.

## Critical thinking
- ltree path updates on subtree moves are O(n) in the subtree size. For frequently reorganized hierarchies, this is expensive. Recursive CTE + adjacency list has cheaper writes but more expensive reads.
- Recursive CTEs in PostgreSQL are always executed using a "working table" approach (not true tail recursion). Each level materializes fully before the next starts. This limits scalability for very wide trees.
- Closure tables (a separate table storing all ancestor-descendant pairs) offer a middle ground: read performance close to ltree, write performance better than path materialization.

## Creative thinking
Use ltree for multi-tenant permission inheritance: `org.division.team.user`. A policy like "grant access to root.marketing and all descendants" becomes a single `<@` query. Combined with RLS (row-level security), this creates a powerful permission model.

## Systems thinking
Hierarchical data and recursive queries interact with query planning in complex ways. The PostgreSQL planner cannot use indexes inside recursive CTEs for the recursive step — it always does a hash or merge join against the working table. For very deep hierarchies, this can be slow. Consider pre-computing subtree information in a materialized view and refreshing it on hierarchy changes.

## MCP and agent perspective
An MCP agent navigating a category tree should use ltree `<@` for subtree queries rather than recursive CTEs — it is consistently faster for read-heavy access patterns. When building permission-checking logic, the agent can use ltree path comparisons as a fast filter before applying more expensive RLS policies.

## Ontology perspective
Hierarchical data is a fundamental ontological structure — `is-a` (taxonomies), `part-of` (mereologies), `contains` (spatial hierarchies). ltree paths are a materialized form of the ontological hierarchy: each node's path is its complete lineage in the ontology. Recursive CTEs are dynamic traversals of the ontology graph, following edges from node to node. The choice between ltree and recursive CTE mirrors the choice between a pre-computed ontology index and a live inference query.

## Practice session
See `practice/intermediate/06-jsonb-modeling/` (JSONB with hierarchical attributes) and `practice/intermediate/13-ontology-modeling/` (ontology-driven schema using ltree).

## References
- PostgreSQL docs — ltree: https://www.postgresql.org/docs/16/ltree.html
- PostgreSQL docs — WITH queries (Recursive): https://www.postgresql.org/docs/16/queries-with.html
- PostgreSQL docs — CYCLE clause: https://www.postgresql.org/docs/16/queries-with.html#QUERIES-WITH-CYCLE
- "Trees in SQL: Slides and Discussion": https://www.slideshare.net/billkarwin/sql-antipatterns-strike-back
- Joe Celko, *SQL for Smarties*, Chapter on Hierarchical Data (Morgan Kaufmann)
