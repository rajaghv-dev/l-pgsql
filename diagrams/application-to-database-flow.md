# Application-to-Database Flow

Sequence diagram tracing a query from user action to database response, including connection pooling, query planning, index lookup, MVCC snapshot check, and result return.

```mermaid
sequenceDiagram
    actor User
    participant App as Application
    participant Pool as Connection Pool<br/>(pgBouncer)
    participant BE as PostgreSQL Backend<br/>(per-connection process)
    participant Parser as Parser
    participant Planner as Planner / Optimizer
    participant Exec as Executor
    participant Store as Storage<br/>(Shared Buffers + Disk)

    User->>App: "Show me orders for user 42"
    App->>Pool: Acquire connection
    Pool-->>App: Connection granted (from pool)

    App->>BE: SELECT * FROM orders WHERE user_id = 42
    BE->>Parser: Tokenize and parse query text
    Parser-->>BE: Parse tree (AST)

    BE->>Planner: Plan the parse tree
    Note over Planner: Check pg_statistic for row estimates<br/>Decide: index scan vs seq scan<br/>Choose join strategy if needed
    Planner-->>BE: Query plan (Index Scan on orders_user_id_idx)

    BE->>Exec: Execute plan
    Exec->>Store: Fetch pages via index on user_id
    Note over Store: Index lookup: B-tree on user_id = 42<br/>→ heap TIDs for matching rows
    Store-->>Exec: Candidate row versions (heap tuples)

    Exec->>Exec: WHERE filter pass<br/>(any remaining predicates)
    Note over Exec: MVCC snapshot check:<br/>Is xmin <= my snapshot xmax?<br/>Is xmax NULL or > my snapshot?<br/>Only return visible rows.

    Exec-->>BE: Visible, filtered result rows
    BE-->>App: Result set (wire protocol)
    App->>Pool: Release connection back to pool
    App-->>User: Rendered orders list
```

## Notes on each step

| Step | What happens |
|------|-------------|
| Connection Pool | Reuses existing backend connections instead of spawning a new process per request. Critical for high-concurrency apps. |
| Parser | Converts SQL text into an internal AST. Syntax errors are caught here. |
| Planner | Chooses the cheapest plan based on table statistics (`pg_statistic`). Uses cost estimates (seq_page_cost, random_page_cost, cpu_tuple_cost). |
| Index lookup | The executor navigates the B-tree to find heap TIDs matching `user_id = 42`, then fetches those pages from shared buffers or disk. |
| WHERE filter | Remaining predicates not satisfied by the index are re-evaluated on the fetched rows. |
| MVCC snapshot check | Each row version has `xmin` (inserted by transaction) and `xmax` (deleted by transaction). The executor checks visibility against its snapshot to ensure read consistency without locking. |
| Result return | Rows are sent back over the PostgreSQL wire protocol (libpq). The pool reclaims the connection for the next query. |
