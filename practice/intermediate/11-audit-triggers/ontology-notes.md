# Ontology Notes — Audit Triggers

## The audit log as temporal ontology
Every row in `audit_log` is a **fact about a state transition** in the ontology:
- It records that entity `record_id` in class `table_name` transitioned from state `old_data` to state `new_data` at time `changed_at`.
- This is structurally identical to a **temporal event** in bi-temporal data modeling.

The audit log makes the ontology explicitly temporal: it records not just what is true now, but what was true at every past moment. Unlike MVCC (which is implementation-internal), the audit log makes this history queryable at the application level.

## Event sourcing and ontological continuity
The audit log is a form of event sourcing: the current state of any entity is derivable from replaying its audit events. This preserves **ontological continuity** — the ability to trace how any entity arrived at its current state through a documented series of causally ordered transitions.

In formal ontology terms:
- Each audit row is a **temporal fact**: true between `old_data.updated_at` and `new_data.updated_at`
- The `INSERT` event is an **existence fact**: the entity came into being at `changed_at`
- The `DELETE` event is a **ceasing-to-exist fact**: the entity was removed from the world at `changed_at`

## Trigger as ontological enforcement
A trigger is an ontological rule made executable: "whenever an entity of type X undergoes a state transition, record it in the audit log." This rule is part of the database's invariant system — it is as immutable and universally applied as a CHECK constraint.

## Obsidian graph mapping
- `audit_log` → node type: Event/StateTransition
- Edge: Event --[records_change_of]--> Entity (via table_name + record_id)
- Edge: Event --[performed_by]--> Agent (via changed_by)
- Edge: Event --[occurred_at]--> TimePoint (via changed_at)
- `old_data` → property: preConditionState
- `new_data` → property: postConditionState
- `session_context` → property: executionContext (tenant, application)
