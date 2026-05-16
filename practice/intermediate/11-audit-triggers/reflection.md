# Reflection — Audit Triggers

## Key takeaways
- Audit triggers capture every INSERT, UPDATE, DELETE at the database level — regardless of which client or application made the change.
- Storing `old_data` and `new_data` as JSONB allows flexible diff queries without additional schema changes.
- `TG_TABLE_NAME` and `TG_OP` make a single trigger function reusable across all tables.
- AFTER triggers cannot cancel the operation — they are side-effect-only.
- Audit entries roll back with the transaction — correct for transactional consistency.

## The audit log is an event store
Every row in `audit_log` is an immutable event:
- `operation` = event type (INSERT, UPDATE, DELETE)
- `record_id` = subject entity
- `old_data` / `new_data` = state before/after
- `changed_by` + `changed_at` = who and when

This structure enables temporal queries: "what was the state of order #42 on Jan 1?" — find the last audit entry before that date.

## Common mistakes
1. Writing to `audit_log` from application code instead of triggers — easy to bypass
2. Not indexing `audit_log (table_name, changed_at)` — audit logs grow fast and need time-based queries
3. Using `BEFORE` trigger for audit (use AFTER — BEFORE sees the pre-committed state)
4. Large JSONB in audit_log for wide tables — monitor `pg_total_relation_size('audit_log')` regularly

## What to explore next
- Concept 18: RLS — combine with audit triggers for complete tenant-aware audit trails
- Concept 19: pg_stat_statements — audit trigger overhead shows up in query stats
- Practice 10: RLS — enrich audit_log with tenant context captured in session_context
