# PostgreSQL Concept Map

Level: Beginner → Advanced
Domain: PostgreSQL / Navigation

This is a navigation guide, not a full ontology file. Use it to orient yourself in the knowledge graph, then follow wikilinks into the detailed ontology files.

---

## Top-level clusters

```
PostgreSQL
├── Data Model
│   ├── [[schema-design-ontology]] — tables, columns, constraints, types
│   ├── [[entity-relationship-ontology]] — ER concepts mapped to PG schema
│   └── [[extension-ontology]] — extended types, operators, functions
│
├── Query Language
│   ├── [[sql-ontology]] — SELECT, INSERT, UPDATE, DELETE, JOINs, CTEs
│   └── [[query-ontology]] — parse → plan → execute lifecycle
│
├── Storage & Integrity
│   ├── [[transaction-ontology]] — ACID, MVCC, isolation levels, vacuum
│   └── [[index-ontology]] — B-tree, GIN, GiST, BRIN, partial, covering
│
├── Performance
│   └── [[performance-ontology]] — cost model, statistics, scan types, joins
│
├── Security
│   └── [[security-ontology]] — roles, grants, RLS, pgcrypto, audit
│
├── Observability
│   └── [[observability-ontology]] — pg_stat_*, pg_locks, Prometheus, Grafana
│
├── Advanced / Specialized
│   ├── [[vector-search-ontology]] — pgvector, embeddings, RAG
│   ├── [[geospatial-ontology]] — PostGIS, geometry, spatial indexes
│   └── [[time-series-ontology]] — partitioning, BRIN, window functions
│
└── AI / Agent
    ├── [[ai-agent-memory-ontology]] — agent memory, MCP tools, event log
    └── [[domain-ontology-examples]] — e-commerce, CMS, financial ledger
```

---

## Concept dependency order (learning sequence)

1. **Foundations**: [[schema-design-ontology]] → [[sql-ontology]] → [[entity-relationship-ontology]]
2. **Execution**: [[query-ontology]] → [[index-ontology]] → [[performance-ontology]]
3. **Reliability**: [[transaction-ontology]]
4. **Safety**: [[security-ontology]] → [[observability-ontology]]
5. **Ecosystem**: [[extension-ontology]]
6. **Specializations**: [[vector-search-ontology]], [[geospatial-ontology]], [[time-series-ontology]]
7. **Agent patterns**: [[ai-agent-memory-ontology]] → [[domain-ontology-examples]]

---

## Key cross-cutting concepts

| Concept | Appears in |
|---------|-----------|
| MVCC / snapshot | [[transaction-ontology]], [[performance-ontology]], [[security-ontology]] |
| Index | [[index-ontology]], [[query-ontology]], [[performance-ontology]], [[vector-search-ontology]], [[geospatial-ontology]] |
| Role / privilege | [[security-ontology]], [[ai-agent-memory-ontology]] |
| pg_stat_statements | [[performance-ontology]], [[observability-ontology]] |
| Partition | [[time-series-ontology]], [[performance-ontology]] |
| Extension | [[extension-ontology]], [[vector-search-ontology]], [[geospatial-ontology]] |
| Foreign key | [[schema-design-ontology]], [[entity-relationship-ontology]], [[sql-ontology]] |

---

## System catalog quick reference

| Catalog object | What it shows |
|---------------|--------------|
| `pg_class` | Tables, indexes, sequences, views |
| `pg_attribute` | Columns |
| `pg_constraint` | Constraints (PK, FK, CHECK, UNIQUE) |
| `pg_index` | Index metadata |
| `pg_stat_user_tables` | Per-table access stats |
| `pg_stat_user_indexes` | Per-index usage stats |
| `pg_stat_statements` | Query-level performance (requires extension) |
| `pg_stat_activity` | Active sessions |
| `pg_locks` | Lock graph |
| `pg_roles` | Roles and privileges |
| `pg_policies` | RLS policies |

---

## Obsidian connections
[[sql-ontology]] [[schema-design-ontology]] [[entity-relationship-ontology]] [[index-ontology]] [[query-ontology]] [[transaction-ontology]] [[extension-ontology]] [[performance-ontology]] [[security-ontology]] [[observability-ontology]] [[vector-search-ontology]] [[geospatial-ontology]] [[time-series-ontology]] [[ai-agent-memory-ontology]] [[domain-ontology-examples]]
