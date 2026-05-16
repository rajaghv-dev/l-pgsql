# Aggregation — Intuition

Level: Beginner

## One-line intuition

Aggregate functions collapse many rows into one summary value — count, sum, average, min, max.

## Why this exists

Raw data is rows. Business questions are summaries: "how many?", "what is the total?", "what is the average?". Aggregation bridges the gap between stored rows and summary answers.

## First-principles explanation

An aggregate function takes a set of rows and returns a single value. To produce multiple summary values (one per group), use GROUP BY to partition rows into groups first — then the aggregate runs on each group independently.

Logical execution order:

```
FROM → WHERE → GROUP BY → HAVING → SELECT (aggregates) → ORDER BY → LIMIT
```

Aggregates run after WHERE (which filters individual rows) and after GROUP BY (which forms groups). HAVING filters groups after aggregation.

## Micro-concepts

| Function | What it returns |
|----------|----------------|
| `COUNT(*)` | Number of rows in the group |
| `COUNT(col)` | Number of non-NULL values in col |
| `SUM(col)` | Sum of values |
| `AVG(col)` | Arithmetic mean (NULLs excluded) |
| `MIN(col)` | Smallest value |
| `MAX(col)` | Largest value |

| Clause | Role |
|--------|------|
| `GROUP BY col` | Partition rows into groups before aggregating |
| `HAVING condition` | Filter groups after aggregation (like WHERE but for groups) |

## Beginner view

Library catalog: you have checkout records with book_id and patron_id.

- "How many total checkouts?" → `COUNT(*)`
- "How many checkouts per patron?" → `GROUP BY patron_id` + `COUNT(*)`
- "Which patrons have more than 5 checkouts?" → `HAVING COUNT(*) > 5`

```sql
-- Total checkouts
SELECT COUNT(*) AS total
FROM checkouts;

-- Checkouts per patron
SELECT patron_id, COUNT(*) AS checkout_count
FROM checkouts
GROUP BY patron_id
ORDER BY checkout_count DESC;

-- Patrons with more than 5 checkouts
SELECT patron_id, COUNT(*) AS checkout_count
FROM checkouts
GROUP BY patron_id
HAVING COUNT(*) > 5;
```

## Intermediate view

**The most common beginner error**: selecting a non-aggregated, non-grouped column:

```sql
-- WRONG — title is not in GROUP BY and not aggregated
SELECT author_id, title, COUNT(*) FROM books GROUP BY author_id;

-- RIGHT
SELECT author_id, COUNT(*) FROM books GROUP BY author_id;
-- or
SELECT author_id, STRING_AGG(title, ', ') FROM books GROUP BY author_id;
```

**COUNT(*) vs COUNT(col)**: COUNT(*) counts rows including NULLs. COUNT(col) counts non-NULL values in that column. Use COUNT(*) for row counts; use COUNT(col) when you want to know how many rows have a value.

**FILTER clause** (PostgreSQL-specific): conditional aggregation without CASE:

```sql
SELECT
    COUNT(*) FILTER (WHERE returned_at IS NULL) AS currently_out,
    COUNT(*) FILTER (WHERE returned_at IS NOT NULL) AS returned
FROM checkouts;
```

## Advanced view

- **Window functions** (later stage) are aggregate-like but do not collapse rows — each row keeps its own line while also seeing the aggregate value.
- **ROLLUP / CUBE / GROUPING SETS**: advanced GROUP BY extensions for multidimensional summaries.
- `AVG` on integer columns returns NUMERIC — precision is preserved, not truncated.
- `SUM` on an empty set returns NULL, not 0. Use `COALESCE(SUM(col), 0)` if you need 0 for empty groups.

## Mental model

Think of GROUP BY as sorting rows into labeled bins (one bin per unique value of the GROUP BY column). Then aggregate functions are applied inside each bin. HAVING is the filter that decides which bins to keep in the final output.

## PostgreSQL view

PostgreSQL allows grouping by any expression, not just columns:

```sql
GROUP BY DATE_TRUNC('month', checked_out_at)
```

This groups by month — useful for time-series summaries.

## SQL view

```sql
-- Average checkout duration (in days) per book
SELECT
    b.title,
    ROUND(AVG(EXTRACT(EPOCH FROM (c.returned_at - c.checked_out_at)) / 86400), 1) AS avg_days
FROM checkouts c
INNER JOIN books b ON b.id = c.book_id
WHERE c.returned_at IS NOT NULL
GROUP BY b.title
HAVING AVG(EXTRACT(EPOCH FROM (c.returned_at - c.checked_out_at)) / 86400) > 7
ORDER BY avg_days DESC;
```

## Non-SQL or hybrid view

In pandas: `df.groupby('patron_id')['id'].count()` — same concept. `groupby` = GROUP BY, aggregation method (`.count()`, `.sum()`, etc.) = aggregate function, `.filter(...)` after groupby = HAVING.

## Design principle

**Push aggregation to the database, not the application.** Fetching 100,000 rows to count them in Python wastes network, memory, and CPU. Let the database aggregate and return one row.

## Critical thinking

- Why can't you use a column alias in HAVING? Because HAVING is evaluated before SELECT in the logical pipeline. Use the full expression or a subquery.
- What is the result of `AVG(NULL, NULL, NULL)`? NULL — aggregate functions on all-NULL inputs return NULL (except COUNT(*) which returns 0 for empty sets).

## Creative thinking

Combine aggregation with a self-join to compute "year-over-year growth":

```sql
SELECT
    this_year.yr,
    this_year.cnt AS this_year_checkouts,
    last_year.cnt AS last_year_checkouts,
    this_year.cnt - last_year.cnt AS growth
FROM (SELECT EXTRACT(YEAR FROM checked_out_at) AS yr, COUNT(*) AS cnt FROM checkouts GROUP BY yr) AS this_year
LEFT JOIN (SELECT EXTRACT(YEAR FROM checked_out_at) AS yr, COUNT(*) AS cnt FROM checkouts GROUP BY yr) AS last_year
  ON this_year.yr = last_year.yr + 1;
```

## Systems thinking

Aggregations power dashboards and reports. They are also the most common source of slow queries on large tables. Add indexes on GROUP BY and WHERE columns, and consider materialized views (see lesson 15) for expensive recurring aggregations.

## MCP and agent perspective

An agent answering "which author has the most checkouts this month?" runs:

```sql
SELECT a.name, COUNT(c.id) AS total
FROM checkouts c
JOIN books b ON b.id = c.book_id
JOIN authors a ON a.id = b.author_id
WHERE c.checked_out_at >= DATE_TRUNC('month', now())
GROUP BY a.name
ORDER BY total DESC
LIMIT 1;
```

The tool returns one row. No row-level data leaves the database. No PII is exposed (author name is not personal data).

## Ontology perspective

- Aggregation is a **reduction** — many values → one value.
- GROUP BY is a **partition** — one set → many subsets.
- HAVING is a **predicate on groups** — symmetric to WHERE, which is a predicate on rows.
- Aggregate functions and scalar functions are both functions, but aggregates are **set-valued** inputs while scalars are **row-valued** inputs.

## Practice session

`practice/beginner/04-joins-and-aggregation/` — exercises include COUNT per author, AVG checkout duration, HAVING to filter busy patrons.

## References

| Resource | URL | Why |
|----------|-----|-----|
| PostgreSQL docs — Aggregate Functions | https://www.postgresql.org/docs/current/functions-aggregate.html | Full function list with notes |
| PostgreSQL docs — GROUP BY | https://www.postgresql.org/docs/current/queries-table-expressions.html#QUERIES-GROUP | GROUP BY / HAVING reference |
| SQLBolt — Lesson 10–12 | https://sqlbolt.com/lesson/select_queries_with_aggregates | Interactive aggregate exercises |
| Mode Analytics SQL Tutorial — Aggregations | https://mode.com/sql-tutorial/sql-aggregate-functions/ | Clear beginner explanation |
