# Ontology Notes — Observability

## The database observing itself
`pg_stat_statements` and `pg_stat_activity` are the database's **self-model** — a representation of the database's own behavior within the database. This is the epistemological concept of self-reflection: the system maintains a model of its own activity, accessible via SQL queries.

This self-model enables meta-level reasoning:
- "Which queries are most expensive?" — reasoning about query patterns
- "Which sessions are blocking?" — reasoning about concurrency
- "Which tables need vacuum?" — reasoning about physical state

## Observability as ontological completeness
An unmonitored database is an ontologically incomplete system: it has state (data) but no accessible representation of its own behavioral patterns. `pg_stat_statements` adds the behavioral layer to the ontology — making the database's execution patterns a first-class citizen of the information model.

## Query normalization as ontological abstraction
Query normalization (replacing literal values with `$1`, `$2`) is an ontological abstraction operation: it projects individual query instances onto their structural type (the query shape). This is analogous to classifying instances under types in an ontology — `WHERE id = 1` and `WHERE id = 2` are the same ontological query type.

## Obsidian graph mapping
- `pg_stat_statements row` → node type: QueryType (normalized query as a class)
- `pg_stat_activity row` → node type: QueryInstance (specific active execution)
- `pg_stat_user_tables row` → node type: TableState (health metrics of a table entity)
- `calls` property → frequency of type instantiation
- `total_exec_time` → cumulative resource consumption of the type
- `seq_scan` → signal of missing index (ontological gap: an implicit filter without a declared access path)
