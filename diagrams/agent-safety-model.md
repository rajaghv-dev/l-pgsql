# Agent Safety Model

How a bad agent action is blocked at each layer before it can corrupt data. Each layer is an independent safety gate — a bypass at one layer should be caught by the next.

```mermaid
flowchart TD
    AGENT["AI Agent\n(LLM-generated action)"]
    MCP["MCP Tool Layer\nTyped input schema validation\nJSON Schema / Pydantic\nRejects: wrong types, missing fields,\nvalues outside allowed range"]
    APPCODE["Application Code\nBusiness logic validation\nPermission check (is this user allowed?)\nRate limiting"]
    RLS["PostgreSQL: Row Level Security\nCREATE POLICY tenant_isolation\nON orders FOR ALL\nUSING (tenant_id = current_setting('app.tenant_id')::int)\n→ Agent can only see/write its own tenant's rows"]
    CHECK["PostgreSQL: CHECK Constraints\nCHECK (total > 0)\nCHECK (status IN ('pending','paid','cancelled'))\n→ Invalid business values rejected at storage layer"]
    NOTNULL["PostgreSQL: NOT NULL + FK\nNOT NULL prevents silent nullification\nFOREIGN KEY prevents orphaned references\n→ Referential integrity enforced by engine"]
    TRIGGER["PostgreSQL: TRIGGER\nCREATE TRIGGER audit_writes\nAFTER INSERT OR UPDATE OR DELETE ON orders\nFOR EACH ROW EXECUTE FUNCTION log_change();\n→ Every write is recorded with xact_id, user, timestamp"]
    TX["PostgreSQL: TRANSACTION\nAll operations in one atomic unit\nAny constraint violation → full ROLLBACK\n→ Partial writes cannot persist"]
    SUCCESS["Commit\nAll layers passed\nChange is durable"]
    BLOCKED["Rejected\nError returned to agent\nNo partial state committed"]

    AGENT --> MCP
    MCP -->|"Schema invalid"| BLOCKED
    MCP -->|"Schema valid"| APPCODE
    APPCODE -->|"Logic violation"| BLOCKED
    APPCODE -->|"Logic valid"| RLS
    RLS -->|"Policy violation"| BLOCKED
    RLS -->|"Policy passed"| CHECK
    CHECK -->|"Constraint violated"| TX
    TX -->|"Rollback"| BLOCKED
    CHECK -->|"Constraint passed"| NOTNULL
    NOTNULL -->|"Violation"| TX
    NOTNULL -->|"Passed"| TRIGGER
    TRIGGER --> TX
    TX -->|"All passed → COMMIT"| SUCCESS
```

## What each layer stops

| Layer | What it prevents |
|-------|-----------------|
| MCP typed input validation | Malformed requests — wrong data types, missing required fields, out-of-range values. Stops bad input before it ever reaches the database. |
| Application code | Business rule violations — e.g., an agent trying to cancel an already-shipped order. |
| RLS policies | Cross-tenant data access — an agent acting as tenant A cannot read or write tenant B's rows even if it constructs a direct SQL query. |
| CHECK constraints | Invalid domain values — negative prices, invalid status strings, impossible date ranges. |
| NOT NULL + FK | Incomplete or dangling data — cannot create an order with no user_id, cannot reference a non-existent product. |
| TRIGGER (audit log) | Not a blocking layer, but ensures every write has an immutable audit trail. The trigger fires inside the same transaction. |
| TRANSACTION | All-or-nothing semantics — if any constraint fails mid-operation, the entire transaction is rolled back and no partial state persists. |

## Human approval gate (recommended for destructive operations)

For MCP tools that perform `DELETE`, `TRUNCATE`, bulk `UPDATE`, or `DROP`, add an explicit human approval step before the SQL is executed. This is a process control above the database layer:

```
Agent proposes: DELETE FROM orders WHERE created_at < '2020-01-01'
→ MCP tool estimates rows affected (SELECT count(*))
→ Returns count to human operator
→ Human confirms or rejects
→ Only on explicit approval does the DELETE execute
```
