# MCP Tool Design Principles

Eight principles for designing MCP tools that are safe, auditable, and maintainable when backed by PostgreSQL. Each principle maps directly to a PostgreSQL enforcement mechanism.

> Stage 28 addition: principles aligned with pending_actions human-approval pattern, idempotency, and fail-safe timeouts. Earlier principles preserved below.

---

## Principle 1: Prefer narrow tools over broad ones

### One-line rule
Each MCP tool should do one well-defined operation — avoid tools that accept arbitrary SQL or generic "execute anything" interfaces.

### Rationale
A tool that accepts arbitrary SQL cannot be safely sandboxed, audited, or granted minimal permissions. A narrow tool (`get_order_by_id`, `cancel_order`) can be given exactly the permissions it needs, can validate its inputs precisely, and produces predictable audit log entries.

### Example (correct)
```python
# MCP tool: get_order_by_id
@tool
def get_order(order_id: int, tenant_id: int) -> dict:
    """Return a single order visible to the given tenant."""
    # Only runs: SELECT id, status, total FROM orders WHERE id = $1 AND tenant_id = $2
    ...
```

### Counter-example (incorrect)
```python
@tool
def run_sql(query: str) -> list:
    """Execute any SQL query against the database."""
    # Accepts: DROP TABLE users; SELECT * FROM all_tenants; etc.
    return db.execute(query)
```

### When this principle applies
All MCP tool design. No exceptions for "internal" or "trusted" agents.

### When to break it (with justification)
A read-only SQL sandbox tool for data exploration by a trusted human analyst is acceptable — with strict role-level grants (SELECT only), RLS enabled, and statement_timeout set.

### Agent/MCP implications
Narrow tools make agent behavior auditable: the audit log entry says "called `cancel_order(order_id=42)`" rather than "executed arbitrary SQL".

---

## Principle 2: Validate all inputs with a typed schema at the MCP layer

### One-line rule
Define JSON Schema or Pydantic models for every MCP tool parameter — reject invalid inputs before touching the database.

### Rationale
The database will reject badly typed inputs with a cryptic error. A typed MCP schema provides a human-readable error immediately, prevents SQL injection through type safety, and makes tool behavior self-documenting.

### Example (correct)
```python
class CancelOrderInput(BaseModel):
    order_id: int = Field(gt=0, description="The order to cancel (must be positive)")
    reason:   str = Field(min_length=1, max_length=500, description="Cancellation reason")

@tool
def cancel_order(input: CancelOrderInput, tenant_id: int) -> dict:
    # By the time we reach here, order_id is a valid positive int
    # and reason is a non-empty string no longer than 500 chars
    ...
```

### Counter-example (incorrect)
```python
@tool
def cancel_order(order_id, reason):
    # order_id could be "'; DROP TABLE orders;--"
    db.execute(f"UPDATE orders SET status='cancelled' WHERE id={order_id}")
```

### When to break it (with justification)
Never. Input validation is the first line of defense and has no valid justification to skip.

---

## Principle 3: Every MCP tool must set the tenant context before executing queries

### One-line rule
Set `SET LOCAL app.tenant_id = $tenant_id` at the start of every MCP database operation — rely on RLS to enforce isolation.

### Rationale
MCP tools share a connection pool. Without setting the tenant context, RLS policies may apply the wrong tenant's filter (or no filter at all) if the previous request's context is still set on a reused connection.

### Example (correct)
```python
def execute_as_tenant(conn, tenant_id: int, query: str, params: tuple):
    with conn.transaction():
        conn.execute("SET LOCAL app.tenant_id = %s", (tenant_id,))
        return conn.execute(query, params).fetchall()
```

### Counter-example (incorrect)
```python
def execute(conn, query: str, params: tuple):
    # No tenant context set — RLS policy reads stale app.tenant_id from pool
    return conn.execute(query, params).fetchall()
```

---

## Principle 4: Write an audit log entry for every MCP tool write operation

### One-line rule
Log every INSERT, UPDATE, and DELETE executed by an MCP tool — include the tool name, agent ID, tenant ID, and timestamp.

### Rationale
When an agent causes a problem (wrong data modified, unexpected deletion), the audit log is the forensic record that identifies what the agent did and when. Without it, debugging agent behavior is guesswork.

### Example (correct)
```python
@tool
def update_order_status(order_id: int, new_status: str, agent_id: str, tenant_id: int):
    with conn.transaction():
        conn.execute("SET LOCAL app.tenant_id = %s", (tenant_id,))
        conn.execute("SET LOCAL app.agent_id = %s", (agent_id,))
        conn.execute("""
            UPDATE orders SET status = %s WHERE id = %s
        """, (new_status, order_id))
        # audit_trigger fires automatically via AFTER UPDATE trigger
        # which reads app.agent_id from session settings
```

---

## Principle 5: Require human approval for destructive MCP operations

### One-line rule
MCP tools that delete, bulk-update, or truncate must estimate affected row count and await human confirmation before executing.

### Rationale
LLM agents can misinterpret intent or receive ambiguous instructions. A "clean up old data" instruction could delete records the user intended to keep. A mandatory estimation + confirmation step gives a human a chance to catch misaligned intent before damage is done.

### Example (correct)
```python
@tool
def delete_old_sessions(before_date: date, tenant_id: int) -> dict:
    """Estimate how many sessions would be deleted. Returns count for human review."""
    count = conn.execute(
        "SELECT count(*) FROM sessions WHERE created_at < %s AND tenant_id = %s",
        (before_date, tenant_id)
    ).fetchone()[0]
    return {
        "estimated_rows": count,
        "action_required": "Call confirm_delete_old_sessions() to proceed",
        "before_date": str(before_date)
    }

@tool
def confirm_delete_old_sessions(before_date: date, tenant_id: int) -> dict:
    """Execute the deletion after human approval."""
    # Only called explicitly by human or after explicit confirmation step
    ...
```

### Counter-example (incorrect)
```python
@tool
def delete_old_sessions(before_date: date, tenant_id: int):
    # Immediately deletes, no preview, no confirmation
    conn.execute("DELETE FROM sessions WHERE created_at < %s", (before_date,))
```

---

## Principle 6: Set statement_timeout on all MCP tool connections

### One-line rule
Configure `statement_timeout` on the MCP tool's database connection — never let an agent-generated query run indefinitely.

### Rationale
An agent may construct a query that is accidentally expensive (large join, missing index, wrong parameter). Without a timeout, this query can run for minutes, saturating CPU and blocking other operations.

### Example (correct)
```python
# Set timeout on connection initialization
conn.execute("SET statement_timeout = '10s'")
conn.execute("SET lock_timeout = '2s'")
```

### When to break it (with justification)
Scheduled background tasks (nightly aggregations, bulk exports) that legitimately need more than 10 seconds. Use a separate connection role with a higher timeout, not the application user.

---

## Principle 7: Return structured errors, not raw PostgreSQL error messages

### One-line rule
Catch database errors in MCP tools and return structured, actionable messages — never expose raw psycopg or libpq stack traces to the agent.

### Rationale
Raw PostgreSQL errors (e.g., `ERROR:  duplicate key value violates unique constraint "users_email_key"`) contain schema information that should not be exposed to an LLM or logged in agent traces. Structured errors also give the agent actionable information to recover gracefully.

### Example (correct)
```python
try:
    conn.execute("INSERT INTO users (email) VALUES (%s)", (email,))
except psycopg.errors.UniqueViolation:
    return {"error": "email_already_exists", "field": "email",
            "message": "A user with this email address already exists."}
```

### Counter-example (incorrect)
```python
# Let the raw psycopg exception propagate to the agent
conn.execute("INSERT INTO users (email) VALUES (%s)", (email,))
# Agent sees: psycopg.errors.UniqueViolation: duplicate key value violates
#             unique constraint "users_email_key" DETAIL: Key (email)=(alice@example.com) already exists.
```

---

## Principle 8: Use read-only connections for MCP read tools

### One-line rule
Connect read-only MCP tools with a role that has only SELECT privileges, or connect to a read replica.

### Rationale
A read-only connection cannot accidentally modify data even if the agent constructs a DML statement. Errors fail loudly at the permission check rather than silently modifying data.

### Example (correct)
```python
# Read tool uses read-only role
read_conn = connect(dsn=READ_REPLICA_DSN, role='app_readonly')

@tool
def search_orders(user_id: int) -> list:
    return read_conn.execute(
        "SELECT id, status, total FROM orders WHERE user_id = %s", (user_id,)
    ).fetchall()
```

### PostgreSQL implementation
```sql
CREATE ROLE app_readonly NOLOGIN;
GRANT CONNECT ON DATABASE myapp TO app_readonly;
GRANT USAGE ON SCHEMA public TO app_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_readonly;
```

---

## Stage 28 Additions

### Principle 9: Idempotent by Design

**Every write tool must be safe to call twice with the same inputs.**

Agents retry on failure. If the first call succeeded but the response was lost, the agent retries. An idempotent tool produces the same outcome on the second call.

Implementation:
```sql
-- blocked: Docker not accessible
-- Idempotent insert: duplicate call is silently ignored
INSERT INTO approval_requests(id, invoice_id, requested_by)
VALUES ($1, $2, $3)
ON CONFLICT (id) DO NOTHING;
```

**Why**: Retries are inevitable in distributed systems. Non-idempotent tools create duplicate records or double-charges when retried.

---

### Principle 10: Human Approval Gateway for Destructive Operations

**Route irreversible operations through `pending_actions`, not direct execution.**

When a tool's action cannot be undone (archive, bulk-delete, status transition in regulated domain), insert a pending_action row instead of executing directly. Return the `pending_action_id` to the agent. A human approves; a worker executes.

**Why**: The cost of an agent mistake on an irreversible operation exceeds the cost of a 24-hour review delay.

---

### Summary Matrix

| # | Principle | Database enforcement |
|---|-----------|---------------------|
| 1 | Narrow interface | One function per operation |
| 2 | Typed validation | Application layer + CHECK constraints |
| 3 | Set tenant context | SET LOCAL + current_setting in RLS |
| 4 | Audit every write | AFTER trigger on all write tables |
| 5 | Human approval for destructive ops | pending_actions state machine |
| 6 | statement_timeout | SET LOCAL statement_timeout |
| 7 | Structured errors | Application error mapping |
| 8 | Read-only role for read tools | GRANT SELECT only |
| 9 | Idempotent by design | ON CONFLICT + idempotency_key |
| 10 | Human approval gateway | pending_actions INSERT; agent cannot execute |
