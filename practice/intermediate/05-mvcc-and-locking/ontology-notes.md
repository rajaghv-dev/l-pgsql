# Ontology Notes — MVCC and Locking

## MVCC as temporal ontology
MVCC makes the database implicitly temporal: every row has a lifespan defined by its birth XID (xmin) and death XID (xmax). This is the informal equivalent of a bi-temporal data model, where each fact has both a valid time (when it was true in the world) and a transaction time (when it was recorded in the database).

PostgreSQL's MVCC only tracks transaction time. To add valid time, you would use explicit `valid_from`/`valid_to` columns alongside the MVCC mechanism. Together they form a fully bi-temporal ontology.

## Dead tuples as retracted facts
In ontological terms, a dead tuple is a **retracted fact** — a claim that was once true but has since been superseded. The physical dead tuple is the retracted form of the claim, not yet garbage-collected. VACUUM performs the ontological cleanup: it removes retractions that no longer need to be visible to any observer.

An event-sourcing system deliberately preserves all retractions (no vacuum), treating history itself as the primary source of truth. PostgreSQL's approach is pragmatic: retentions that serve no observer are reclaimed.

## Locks as claims on future facts
A FOR UPDATE lock is a **claim** that the locking transaction intends to produce a new fact about a specific entity. The lock prevents other transactions from making conflicting claims about the same entity until the first transaction's claim is resolved (committed or rolled back).

In ontology terms:
- **FOR SHARE** — "I depend on this fact remaining stable" (read dependency)
- **FOR NO KEY UPDATE** — "I am changing attributes but not the identity key" (partial mutation)
- **FOR UPDATE** — "I am claiming the right to transform this entity" (full mutation)

## Deadlock as circular dependency
A deadlock in the lock graph corresponds to a **circular dependency** in the ontological dependency chain: Entity A's new state depends on Entity B's current state, while Entity B's new state depends on Entity A's current state. This is logically impossible to resolve in a causal system.

The ontological solution is to break the circular dependency by ordering operations according to a canonical traversal of the ontology graph (e.g., always process entities in ascending id order, reflecting an ontological hierarchy where lower-id entities are "more foundational").

## SKIP LOCKED as priority-agnostic work claiming
In an ontology of tasks and workers, SKIP LOCKED implements a **resource allocation protocol** that respects the constraint that each task can only be claimed by one worker at a time. It is a materialization of the "exclusive assignment" relationship in the task ontology.

## Obsidian graph mapping
- `mvcc_demo row version` → node type: VersionedFact (temporal extent: xmin→xmax)
- `dead tuple` → node type: RetractedFact
- `job_queue row` → node type: Task
- `worker` → node type: Agent
- Edge: Agent --[claims]--> Task (via FOR UPDATE SKIP LOCKED)
- Edge: Task --[transitions_to]--> Status (pending → processing → done)
