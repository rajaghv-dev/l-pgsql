# Domain Example Template

> File location: `examples/<level>/<domain>/`
>
> **How to use this template:**
> One folder per domain example. Each folder contains a README.md (this file) plus any supplementary `.sql` files.
> All data is synthetic — no real names, real emails, real addresses, or real financial data.
> Every SQL block must be runnable with the local setup.
>
> Regulated domain reminder: examples in legal, financial, medical, pharma, or compliance domains
> must focus on workflow, retrieval, audit, and permissions — never on advice logic, diagnosis, or regulatory claims.

---

# <!-- Domain Name --> Example

Level: Beginner / Intermediate / Advanced

## Domain overview

<!-- TODO: fill in for this specific domain example -->
Two to four sentences describing the domain and the scenario.

- **Domain:** <!-- e.g., task management, inventory, compliance audit, medical record retrieval -->
- **Scenario:** <!-- e.g., "A small team uses a database to track project tasks. Agents can create, update, and query tasks on behalf of users." -->
- **Why this domain:** <!-- what PostgreSQL features this scenario exercises naturally -->
- **Synthetic data note:** All names, emails, IDs, and values in this example are fictional.

---

## Schema

> Schema design rationale: <!-- one sentence explaining the key design decision -->

```bash
# Create schema (idempotent)
docker exec cfp_postgres psql -U cfp -d cfp -c "
  -- Drop existing objects for clean re-run
  DROP TABLE IF EXISTS <!-- table1 --> CASCADE;
  DROP TABLE IF EXISTS <!-- table2 --> CASCADE;

  -- Table 1
  CREATE TABLE <!-- table1 --> (
    id          SERIAL PRIMARY KEY,
    <!-- col1 --> <!-- type -->  NOT NULL,
    <!-- col2 --> <!-- type -->  DEFAULT <!-- default -->,
    <!-- col3 --> <!-- type -->  REFERENCES <!-- other_table --> (id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  COMMENT ON TABLE <!-- table1 --> IS '<!-- one-line purpose -->';

  -- Table 2
  CREATE TABLE <!-- table2 --> (
    id          SERIAL PRIMARY KEY,
    <!-- col1 --> <!-- type -->  NOT NULL,
    <!-- col2 --> <!-- type -->,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  COMMENT ON TABLE <!-- table2 --> IS '<!-- one-line purpose -->';
"
```

Schema design notes:
- `<!-- table1 -->` stores <!-- what it stores and why it is a separate table -->
- `<!-- table2 -->` stores <!-- what it stores and why it is normalized -->
- The `created_at` / `updated_at` columns support <!-- audit / temporal queries / soft deletes -->

---

## Seed data

> All values below are synthetic. No real individuals or organizations are represented.

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  -- Synthetic seed data for <!-- table1 -->
  INSERT INTO <!-- table1 --> (<!-- col1 -->, <!-- col2 -->)
  VALUES
    ('<!-- synthetic_val1a -->', <!-- synthetic_val1b -->),
    ('<!-- synthetic_val2a -->', <!-- synthetic_val2b -->),
    ('<!-- synthetic_val3a -->', <!-- synthetic_val3b -->),
    ('<!-- synthetic_val4a -->', <!-- synthetic_val4b -->),
    ('<!-- synthetic_val5a -->', <!-- synthetic_val5b -->);

  -- Synthetic seed data for <!-- table2 -->
  INSERT INTO <!-- table2 --> (<!-- col1 -->, <!-- col2 -->)
  VALUES
    (1, '<!-- val1 -->'),
    (2, '<!-- val2 -->'),
    (3, '<!-- val3 -->');
"
```

Verify seed data:
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT '<!-- table1 -->' AS tbl, COUNT(*) FROM <!-- table1 -->
  UNION ALL
  SELECT '<!-- table2 -->', COUNT(*) FROM <!-- table2 -->;
"
```

Expected output:
```
   tbl       | count
-------------+-------
 <!-- t1 --> |     5
 <!-- t2 --> |     3
```

---

## Example queries

### Query 1: <!-- Name — e.g., "List all open items" -->

**Scenario:** <!-- why a user or agent would run this query -->

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: Query 1 SQL -->
"
```

**Output:**
```
<!-- expected output -->
```

**What this shows:** <!-- the PostgreSQL concept this demonstrates -->

---

### Query 2: <!-- Name — e.g., "Filter by status with index" -->

**Scenario:** <!-- why this query matters -->

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: Query 2 SQL, preferably with a JOIN or aggregation -->
"
```

**Output:**
```
<!-- expected output -->
```

---

### Query 3: <!-- Name — e.g., "EXPLAIN a common access pattern" -->

**Scenario:** <!-- what this diagnoses or demonstrates -->

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  EXPLAIN ANALYZE <!-- TODO: Query 3 SQL -->;
"
```

**What to look for in the plan:**
- `<!-- node type -->` — what it means in this context
- `cost=...` — whether it is within acceptable range
- `actual time=...` — whether it matches the estimate

---

### Query 4 (intermediate/advanced): <!-- Name -->

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: More complex query: CTE, window function, JSONB, FTS, or vector -->
"
```

**What this shows:** <!-- the intermediate or advanced concept -->

---

## Validation queries

Run these to confirm the schema and data are in the expected state:

```bash
# Table structure
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT column_name, data_type, is_nullable, column_default
  FROM information_schema.columns
  WHERE table_name = '<!-- table1 -->'
  ORDER BY ordinal_position;
"

# Constraints
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT conname, contype, pg_get_constraintdef(oid)
  FROM pg_constraint
  WHERE conrelid = '<!-- table1 -->'::regclass;
"

# Indexes
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT indexname, indexdef
  FROM pg_indexes
  WHERE tablename = '<!-- table1 -->';
"
```

---

## Practice tasks

These tasks extend the example. Solutions are not provided — work them out from the queries above.

### Task 1 (beginner): <!-- Short title -->

<!-- TODO: specific task appropriate to the level -->

Hint: <!-- one sentence that points in the right direction without giving the answer -->

---

### Task 2 (intermediate): <!-- Short title -->

<!-- TODO: a task requiring a JOIN, aggregation, or index creation -->

Hint: <!-- one sentence -->

---

### Task 3 (advanced): <!-- Short title -->

<!-- TODO: a task requiring EXPLAIN analysis, RLS setup, or a trigger -->

Hint: <!-- one sentence -->

---

## MCP and agent angle

<!-- TODO: fill in for this specific domain example -->

**Scenario:** <!-- describe the agent's role in this domain -->

```markdown
## Agent/MCP angle

- Agent scenario: <!-- e.g., "An AI assistant helps a team lead track overdue tasks across projects" -->
- MCP tool name: `<!-- e.g., list_overdue_tasks -->`
- Tool input: `{ "team_id": "...", "days_overdue": 7 }`
- PostgreSQL operation:
  ```sql
  SELECT <!-- cols -->
  FROM <!-- table1 -->
  WHERE <!-- overdue condition -->
    AND team_id = $1
  ORDER BY due_date;
  ```
- Required permission: `SELECT` on `<!-- table1 -->` for role `<!-- role -->`
- Validation before execution: `team_id` must be a non-null UUID belonging to the authenticated user
- Audit log entry: query logged to `agent_query_log` with team_id, agent_id, timestamp
- Human approval needed: No — read-only query
- Failure mode: Stale statistics → planner chooses seq scan → slow for large tables. Fix: `ANALYZE <!-- table1 -->`.
- Recovery: No write to recover; re-run query
- Ontology connection: `[[query]]` → `[[index]]` → `[[pg_stat_statements]]`
```

---

## Teardown

Remove all objects created by this example:

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  DROP TABLE IF EXISTS <!-- table2 --> CASCADE;
  DROP TABLE IF EXISTS <!-- table1 --> CASCADE;
  -- DROP EXTENSION IF EXISTS <!-- extension_name -->;
"
```

---

## References

<!-- TODO: fill in for this specific domain example -->

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|-----------|
| <!-- title --> | <!-- URL --> | <!-- type --> | <!-- level --> | <!-- time --> | <!-- why relevant to this domain example --> |

> If a reference cannot be verified, write: `TODO: Find verified reference for this topic.`
