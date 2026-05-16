# SQL Query Lifecycle

What happens inside PostgreSQL from the moment a query string arrives to the moment results are returned.

```mermaid
flowchart TD
    IN["Receive query text\nover wire protocol"]
    PARSE["Parse\nLex → tokens → AST\nSyntax errors caught here"]
    ANALYZE["Analyze / Validate\nResolve table & column names\nType-check expressions\nSemantic errors caught here"]
    REWRITE["Rewrite\nApply rules & views\nExpand view definitions"]
    PLAN["Plan\nGenerate candidate plans\nEstimate cost of each plan\nChoose cheapest plan"]

    subgraph STATS["Planner uses statistics"]
        PGSTAT["pg_statistic\n(column histograms, NDV)"]
        PGCLASS["pg_class\n(table row count estimate)"]
        PGIX["pg_index\n(index availability)"]
    end

    subgraph SCAN["Scan type chosen by planner"]
        SEQSCAN["Sequential Scan\n(no index, small table\nor low selectivity)"]
        IXSCAN["Index Scan\n(B-tree: equality/range\nhigh selectivity)"]
        BITMAPSCAN["Bitmap Index Scan\n(medium selectivity\nmultiple indexes)"]
        IDXONLY["Index Only Scan\n(all columns in index\nno heap access needed)"]
    end

    EXEC["Execute\nFetch pages, apply predicates\nMVCC visibility check\nAggregate / sort / limit"]
    RETURN["Return results\nStream rows back to client\nover wire protocol"]

    IN --> PARSE
    PARSE --> ANALYZE
    ANALYZE --> REWRITE
    REWRITE --> PLAN
    PLAN --> STATS
    PLAN --> SCAN
    SCAN --> EXEC
    EXEC --> RETURN

    IXSCAN -->|"Index speeds up:\nrow lookup by key\nrange scans\nORDER BY without sort"| EXEC
    SEQSCAN -->|"No index benefit:\nreads all pages sequentially"| EXEC
```

## Where indexes make a difference

```mermaid
flowchart LR
    Q["SELECT * FROM orders\nWHERE user_id = 42\nORDER BY created_at DESC\nLIMIT 10"]

    subgraph WITHOUT["Without index"]
        SS["Sequential scan:\nread all N rows\nfilter in memory\nsort all matches\nreturn top 10"]
    end

    subgraph WITH["With index on (user_id, created_at DESC)"]
        IS["Index scan:\nnavigate B-tree to user_id=42\nread pages in order\nstop after 10 rows\nno sort needed"]
    end

    Q --> WITHOUT
    Q --> WITH
```

## Planner cost model (simplified)

| Factor | Default cost unit |
|--------|------------------|
| Sequential page read | 1.0 (seq_page_cost) |
| Random page read (index) | 4.0 (random_page_cost) |
| Per-row CPU processing | 0.01 (cpu_tuple_cost) |
| Per-row operator evaluation | 0.0025 (cpu_operator_cost) |

The planner multiplies estimated rows by these costs and picks the plan with the lowest total. This is why a large table with a highly selective index wins over a sequential scan, but a small table often favors a sequential scan even with an available index.

## How to inspect the chosen plan

```sql
EXPLAIN SELECT * FROM orders WHERE user_id = 42 ORDER BY created_at DESC LIMIT 10;
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;  -- run the query and show actual times and buffer hits
```
