# Event Sourcing and Audit Example

Level: Advanced
Domain: Append-only event store with state replay, snapshots, and full audit capability
Synthetic data: Yes

## Overview

An event-sourced system for a fictional order management service called "Ledgerly
Orders". In event sourcing, state is never stored directly — instead, every change
to an entity (aggregate) is recorded as an immutable event. The current state of
any aggregate is derived by replaying its events from the beginning, or from the
most recent snapshot.

Key concepts:
- **Events table** — append-only; a trigger blocks UPDATE and DELETE.
- **Sequence numbers** — each aggregate has a monotonically increasing `sequence_num`
  to detect concurrency conflicts (optimistic locking).
- **State replay** — a query that re-materialises the current state from events.
- **Snapshots** — periodic captures of computed state to speed up replay on
  high-volume aggregates.
- **Time travel** — replay events up to any point in time to inspect historical state.

## Schema

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

-- The event store: immutable append-only log
CREATE TABLE events (
    id              BIGSERIAL   PRIMARY KEY,
    aggregate_id    UUID        NOT NULL,
    aggregate_type  TEXT        NOT NULL,  -- e.g. 'Order', 'Customer', 'Shipment'
    event_type      TEXT        NOT NULL,  -- e.g. 'OrderPlaced', 'OrderShipped'
    payload         JSONB       NOT NULL DEFAULT '{}',
    sequence_num    BIGINT      NOT NULL,  -- monotone per aggregate; starts at 1
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_events_aggregate_seq UNIQUE (aggregate_id, sequence_num)
);

CREATE INDEX idx_events_aggregate_id   ON events (aggregate_id);
CREATE INDEX idx_events_aggregate_type ON events (aggregate_type);
CREATE INDEX idx_events_created_at     ON events (created_at);

-- Append-only enforcement
CREATE OR REPLACE FUNCTION fn_events_immutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION
        'events table is append-only: % is not permitted', TG_OP;
END;
$$;

CREATE TRIGGER trg_events_immutable
BEFORE UPDATE OR DELETE ON events
FOR EACH ROW EXECUTE FUNCTION fn_events_immutable();

-- Snapshots: periodic materialised state to avoid full replay
CREATE TABLE snapshots (
    id              BIGSERIAL   PRIMARY KEY,
    aggregate_id    UUID        NOT NULL,
    aggregate_type  TEXT        NOT NULL,
    state           JSONB       NOT NULL,  -- full serialised state at snapshot_seq
    snapshot_seq    BIGINT      NOT NULL,  -- sequence_num of last event included
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (aggregate_id, snapshot_seq)
);

CREATE INDEX idx_snapshots_aggregate_id ON snapshots (aggregate_id);
```

## Seed data

We model three synthetic orders going through different lifecycle stages.
Each INSERT into `events` represents a domain event; state is never stored
directly in any application table.

```sql
-- Helper: generate a fixed UUID for each synthetic order
-- Order A: ORD-001
-- Order B: ORD-002
-- Order C: ORD-003

-- ---- Order A: placed, confirmed, shipped, delivered ----
INSERT INTO events (aggregate_id, aggregate_type, event_type, payload, sequence_num, created_at) VALUES

('a1b2c3d4-0000-0000-0000-000000000001', 'Order', 'OrderPlaced', '{
    "customer_id": "CUST-101",
    "items": [{"sku": "SKU-001", "qty": 2, "unit_price": 29.99},
              {"sku": "SKU-042", "qty": 1, "unit_price": 14.50}],
    "total": 74.48,
    "shipping_address": "42 Elm St, Northford, NF1 1AA"
}', 1, NOW() - INTERVAL '10 days'),

('a1b2c3d4-0000-0000-0000-000000000001', 'Order', 'OrderConfirmed', '{
    "confirmed_by": "payment-service",
    "payment_ref": "PAY-88821"
}', 2, NOW() - INTERVAL '10 days' + INTERVAL '5 minutes'),

('a1b2c3d4-0000-0000-0000-000000000001', 'Order', 'OrderShipped', '{
    "carrier": "FastPost",
    "tracking_number": "FP-999001",
    "estimated_delivery": "2024-06-08"
}', 3, NOW() - INTERVAL '8 days'),

('a1b2c3d4-0000-0000-0000-000000000001', 'Order', 'OrderDelivered', '{
    "delivered_at": "2024-06-08T14:23:00Z",
    "signed_by": "resident"
}', 4, NOW() - INTERVAL '6 days');

-- ---- Order B: placed, confirmed, then cancelled ----
INSERT INTO events (aggregate_id, aggregate_type, event_type, payload, sequence_num, created_at) VALUES

('b2c3d4e5-0000-0000-0000-000000000002', 'Order', 'OrderPlaced', '{
    "customer_id": "CUST-202",
    "items": [{"sku": "SKU-007", "qty": 1, "unit_price": 199.00}],
    "total": 199.00,
    "shipping_address": "7 Oak Ave, Ashbridge, AB2 2BB"
}', 1, NOW() - INTERVAL '7 days'),

('b2c3d4e5-0000-0000-0000-000000000002', 'Order', 'OrderConfirmed', '{
    "confirmed_by": "payment-service",
    "payment_ref": "PAY-88822"
}', 2, NOW() - INTERVAL '7 days' + INTERVAL '3 minutes'),

('b2c3d4e5-0000-0000-0000-000000000002', 'Order', 'OrderCancelled', '{
    "reason": "customer_request",
    "refund_ref": "REF-55501"
}', 3, NOW() - INTERVAL '6 days');

-- ---- Order C: placed only (pending confirmation) ----
INSERT INTO events (aggregate_id, aggregate_type, event_type, payload, sequence_num, created_at) VALUES

('c3d4e5f6-0000-0000-0000-000000000003', 'Order', 'OrderPlaced', '{
    "customer_id": "CUST-303",
    "items": [{"sku": "SKU-015", "qty": 3, "unit_price": 8.99}],
    "total": 26.97,
    "shipping_address": "99 Pine Rd, Northford, NF3 3CC"
}', 1, NOW() - INTERVAL '1 day');

-- ---- Snapshot for Order A (after sequence 3, before delivery) ----
INSERT INTO snapshots (aggregate_id, aggregate_type, state, snapshot_seq) VALUES
('a1b2c3d4-0000-0000-0000-000000000001', 'Order',
'{
    "status": "shipped",
    "customer_id": "CUST-101",
    "total": 74.48,
    "tracking_number": "FP-999001",
    "items": [{"sku": "SKU-001", "qty": 2}, {"sku": "SKU-042", "qty": 1}]
}', 3);
```

## Example queries

### Full event stream for a specific aggregate (in order)

```sql
SELECT id,
       event_type,
       sequence_num,
       created_at,
       payload
FROM   events
WHERE  aggregate_id = 'a1b2c3d4-0000-0000-0000-000000000001'
ORDER  BY sequence_num;
```

### Replay current state from events (JSONB accumulation)

```sql
-- Build current state by merging all payloads in sequence order
-- (simplified: last event_type wins for status; payload fields accumulate)
SELECT aggregate_id,
       MAX(sequence_num) AS latest_seq,
       (ARRAY_AGG(event_type ORDER BY sequence_num DESC))[1] AS current_status,
       jsonb_object_agg(event_type, payload)                  AS all_payloads
FROM   events
WHERE  aggregate_id = 'a1b2c3d4-0000-0000-0000-000000000001'
GROUP  BY aggregate_id;
```

### Current state using snapshot + replay of subsequent events

```sql
WITH latest_snapshot AS (
    SELECT state, snapshot_seq
    FROM   snapshots
    WHERE  aggregate_id = 'a1b2c3d4-0000-0000-0000-000000000001'
    ORDER  BY snapshot_seq DESC
    LIMIT  1
),
subsequent_events AS (
    SELECT e.event_type, e.payload, e.sequence_num
    FROM   events e
    CROSS  JOIN latest_snapshot s
    WHERE  e.aggregate_id = 'a1b2c3d4-0000-0000-0000-000000000001'
      AND  e.sequence_num > s.snapshot_seq
    ORDER  BY e.sequence_num
)
SELECT s.state         AS snapshot_state,
       s.snapshot_seq,
       se.event_type   AS next_event,
       se.payload      AS next_payload,
       se.sequence_num
FROM   latest_snapshot s
LEFT   JOIN subsequent_events se ON TRUE;
```

### Time travel: state of Order A at a specific point in time

```sql
-- Replay only events up to 8 days ago
SELECT event_type, sequence_num, created_at, payload
FROM   events
WHERE  aggregate_id = 'a1b2c3d4-0000-0000-0000-000000000001'
  AND  created_at  <= NOW() - INTERVAL '8 days'
ORDER  BY sequence_num;
-- Result: shows the order was in 'shipped' state 8 days ago
```

### List all aggregates with their latest event

```sql
SELECT DISTINCT ON (aggregate_id)
       aggregate_id,
       aggregate_type,
       event_type AS last_event,
       sequence_num AS at_seq,
       created_at   AS event_time
FROM   events
ORDER  BY aggregate_id, sequence_num DESC;
```

### Event type frequency (audit overview)

```sql
SELECT event_type,
       COUNT(*)                           AS occurrences,
       MIN(created_at)::DATE             AS first_seen,
       MAX(created_at)::DATE             AS last_seen
FROM   events
GROUP  BY event_type
ORDER  BY occurrences DESC;
```

### Optimistic concurrency: append next event safely

```sql
-- Append event to Order C only if we expect sequence_num to be 2
-- (protects against concurrent appends)
INSERT INTO events (aggregate_id, aggregate_type, event_type, payload, sequence_num)
SELECT 'c3d4e5f6-0000-0000-0000-000000000003',
       'Order',
       'OrderConfirmed',
       '{"confirmed_by": "payment-service", "payment_ref": "PAY-88823"}',
       MAX(sequence_num) + 1
FROM   events
WHERE  aggregate_id = 'c3d4e5f6-0000-0000-0000-000000000003'
HAVING MAX(sequence_num) = 1;   -- will insert 0 rows if seq has advanced past 1
```

### Prove immutability

```sql
-- Both of these should raise: "events table is append-only: DELETE is not permitted"

-- DELETE FROM events WHERE id = 1;
-- UPDATE events SET payload = '{}' WHERE id = 1;
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

SELECT COUNT(*) FROM events;
-- Expected: 9

SELECT COUNT(*) FROM snapshots;
-- Expected: 1

-- All sequence numbers are unique per aggregate
SELECT aggregate_id, COUNT(*), COUNT(DISTINCT sequence_num)
FROM events GROUP BY aggregate_id;
-- count = count(distinct sequence_num) for each

-- Trigger exists
SELECT trigger_name FROM information_schema.triggers
WHERE event_object_table = 'events';

-- Order A has 4 events, sequence 1-4
SELECT sequence_num FROM events
WHERE aggregate_id = 'a1b2c3d4-0000-0000-0000-000000000001'
ORDER BY sequence_num;
```

## Practice tasks

1. **Add an OrderReturned event.** Append `event_type = 'OrderReturned'` to Order A
   with `sequence_num = 5`. Include a `reason` and `refund_amount` in the payload.
   Confirm it appears in the event stream.

2. **Prove immutability.** Try to DELETE event id=1 and UPDATE event id=2.
   Document the error messages.

3. **Optimistic concurrency conflict.** Simulate two concurrent appends to Order C
   both expecting `sequence_num = 2`. Run both INSERTs. The second should fail with
   a unique constraint violation. How would a real system handle this (retry)?

4. **Write a state-machine validator.** Write a SQL query (or PL/pgSQL function)
   that reads the event stream for an aggregate and raises an error if an invalid
   state transition is detected (e.g., OrderShipped after OrderCancelled).

5. **Snapshot strategy.** For Order B (which has 3 events), write a query to
   compute the materialised state after all events, then INSERT it as a snapshot.
   When would you choose to snapshot: every N events, every N minutes, or after
   specific event types?

## MCP and agent perspective

An AI agent using this event store via MCP would:

- **Every action is an event** — the agent never UPDATEs state directly. It
  appends an event (e.g., `OrderConfirmed`) and the state is derived from the log.
- **Full audit trail** — because events are immutable and sequenced, a human can
  inspect every action the agent took, in order, at any time.
- **Time travel for debugging** — if the agent makes a mistake, the human can replay
  events up to the point just before the error to understand what went wrong.
- **Concurrency safety** — the unique constraint on `(aggregate_id, sequence_num)`
  prevents two agent instances from simultaneously appending conflicting events.
- **Snapshot for efficiency** — for high-volume aggregates (thousands of events),
  the agent reads from the latest snapshot and replays only subsequent events,
  keeping query latency low.

## Teardown

```sql
DROP TRIGGER  IF EXISTS trg_events_immutable ON events;
DROP FUNCTION IF EXISTS fn_events_immutable();
DROP TABLE    IF EXISTS snapshots;
DROP TABLE    IF EXISTS events;
```

## References

- Event Sourcing pattern: https://martinfowler.com/eaaDev/EventSourcing.html
- JSONB: https://www.postgresql.org/docs/current/datatype-json.html
- UUID type: https://www.postgresql.org/docs/current/datatype-uuid.html
- DISTINCT ON: https://www.postgresql.org/docs/current/sql-select.html#SQL-DISTINCT
- Optimistic Locking: https://en.wikipedia.org/wiki/Optimistic_concurrency_control
