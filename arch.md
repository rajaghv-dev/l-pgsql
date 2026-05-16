# Repository Architecture

## Purpose

A staged, first-principles PostgreSQL learning lab.  
Teaches PostgreSQL as a database AND as an agent-safe state/memory/retrieval/audit substrate.

---

## Top-level structure

```
l-pgsql/
├── arch.md                     ← this file
├── README.md                   ← quick start and overview
├── AGENT_GUIDE.md              ← resume instructions for coding agents
├── CONTRIBUTING.md             ← contribution rules
│
├── learning-roadmap.md         ← full stage map (0–29)
├── beginner-roadmap.md         ← beginner learning path
├── intermediate-roadmap.md     ← intermediate learning path
├── advanced-roadmap.md         ← advanced learning path
│
├── references.md               ← curated free references
├── extension-map.md            ← all 48 extensions by category
├── capability-map.md           ← capabilities organized by problem
│
├── concepts/                   ← short lessons
│   ├── beginner/               ← intuition, first commands, micro-practice
│   ├── intermediate/           ← design, indexes, transactions, RLS
│   └── advanced/               ← internals, performance, agent-safe arch
│
├── practice/                   ← micro-practice sessions
│   ├── beginner/
│   ├── intermediate/
│   └── advanced/
│
├── examples/                   ← runnable domain examples
│   ├── beginner/
│   ├── intermediate/
│   └── advanced/
│
├── extensions/                 ← one file per extension
├── ontology/                   ← concept maps and ontology notes
├── diagrams/                   ← Mermaid and ASCII diagrams
├── design-principles/          ← schema and system design guides
├── reflections/                ← question banks
│
├── scripts/                    ← validation and utility scripts
│   ├── stage-00/               ← environment validation (Stage 0)
│   └── dashboards/             ← dashboard setup scripts
│
├── tools/
│   ├── dashboards/             ← full dashboard stack (compose + configs)
│   └── templates/              ← lesson and practice templates
│
└── pgsql_learning_repo_prompt_pack/   ← prompt pack (orchestration layer)
    ├── MASTER_SPEC.md
    ├── AGENT_BOOTSTRAP.md
    ├── CURRENT_STAGE.md
    ├── DONE_CRITERIA.md
    ├── STAGES.md
    ├── prompts.md
    ├── STAGE_PROMPTS/          ← one file per stage (0–29)
    └── .learning-session/      ← session memory (resumable state)
```

---

## Two-layer design

```
┌─────────────────────────────────────────────────────┐
│  Prompt pack (pgsql_learning_repo_prompt_pack/)      │
│  Orchestration layer — controls what gets built,     │
│  when, and validates completion before continuing.   │
│                                                      │
│  MASTER_SPEC → STAGES → CURRENT_STAGE → STAGE_PROMPTS│
│  .learning-session/ = resumable memory              │
└─────────────────────────┬───────────────────────────┘
                          │ generates
                          ▼
┌─────────────────────────────────────────────────────┐
│  Learning repo (root)                               │
│  Content layer — concepts, practice, examples,       │
│  extensions, ontology, diagrams, design principles.  │
└─────────────────────────────────────────────────────┘
```

---

## Infrastructure

```
┌─────────────────────────── Docker network: cfp_default ─────────────────────────┐
│                                                                                   │
│  cfp_postgres          cfp_redis           cfp_ollama         mlcp-registry       │
│  PostgreSQL 16.13      Redis 7             Ollama             Docker registry     │
│  pgvector image        port 6379           port 11434         port 5000           │
│  port 5432                                                                        │
│  user/db/pass: cfp                                                                │
│                                                                                   │
│  ── Dashboard stack (tools/dashboards/docker-compose.yml) ─────────────────────  │
│                                                                                   │
│  dash_pgadmin          dash_adminer        dash_grafana        dash_prometheus    │
│  pgAdmin 4             Adminer             Grafana             Prometheus         │
│  port 5050             port 8082           port 3000           port 9090          │
│                                                                                   │
│  dash_postgres_exporter  dash_redis_exporter  dash_redisinsight  dash_open_webui │
│  postgres→Prometheus     redis→Prometheus     Redis GUI          Ollama UI        │
│  port 9187               port 9121            port 5540          port 8080        │
│                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────┘
```

---

## Learning content architecture

### Three-level pattern

Every major topic has three files (beginner / intermediate / advanced).

```
Topic: Indexes
├── concepts/beginner/06-indexes-basics.md
│     intuition, B-tree, CREATE INDEX, EXPLAIN
├── concepts/intermediate/03-index-types.md
│     GIN, GiST, BRIN, partial, expression, covering
└── concepts/advanced/05-parallel-query.md  ← advanced touches index parallelism
```

### Lesson file structure

Each lesson follows the template in `MASTER_SPEC.md`:

```
# Topic
Level: Beginner / Intermediate / Advanced
## One-line intuition
## Why this exists
## First-principles explanation
## Micro-concepts (each with micro-practice + validation)
## Mental model
## PostgreSQL view
## SQL view
## Non-SQL / hybrid view
## Design principle
## Critical / creative / systems thinking
## MCP and agent perspective
## Ontology perspective
## Practice session → links to practice/<level>/<topic>/
## References
```

### Practice session structure

Every `practice/<level>/<topic>/` folder:

```
README.md           — overview and goals
setup.sql           — creates tables, seed data, extensions
00-setup-validation.md  — validates setup ran correctly
exercises.md        — step-by-step exercises
solutions.md        — full solutions with explanations
reflection.md       — thinking questions
ontology-notes.md   — concept map for this topic
troubleshooting.md  — common errors and fixes
references.md       — topic-specific references
```

---

## Dashboard architecture

```
tools/dashboards/
├── docker-compose.yml          ← brings up all 8 dashboard services
├── README.md                   ← learning guide for every dashboard
│
├── pgadmin/
│   ├── servers.json            ← pre-wired cfp_postgres connection
│   └── pgpass                  ← password file (no manual entry)
│
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   ├── postgres.yml    ← direct PG datasource (cfp-postgres)
│   │   │   └── prometheus.yml  ← Prometheus datasource (cfp-prometheus)
│   │   └── dashboards/
│   │       └── provider.yml    ← loads dashboards from /dashboards/
│   └── dashboards/
│       └── pg-learning-overview.json  ← pre-built learning dashboard
│
└── prometheus/
    └── prometheus.yml          ← scrapes postgres_exporter + redis_exporter
```

### Grafana dashboard — pg-learning-overview

```
┌──────────────┬──────────────┬──────────────┬──────────────┐
│ Active       │ Cache hit    │ Installed    │ User tables  │
│ connections  │ rate %       │ extensions   │              │
├──────────────┴──────────────┴──────────────┴──────────────┤
│ Table statistics (seq scans, idx scans, live/dead rows)   │
├────────────────────────────────────────────────────────────┤
│ Active queries (pg_stat_activity)                         │
├────────────────────────────────────────────────────────────┤
│ Index usage (idx_scan, tuple reads)                       │
├────────────────────────────────────────────────────────────┤
│ Locks (pg_locks — blocked queries only)                   │
└────────────────────────────────────────────────────────────┘
```

---

## MCP and agent architecture

Every lesson and practice session with a non-trivial write operation includes:

```
## MCP and agent perspective
- What state the agent reads
- What state the agent writes
- What MCP tool would expose this
- What must NOT be exposed
- Permission boundary
- Validation before execution
- Audit event
- Human approval required
- Failure mode
- Recovery / rollback
- Ontology connection
```

### Agent safety layers

```
Agent request
    │
    ▼
MCP tool (narrow, typed input)
    │
    ▼
PostgreSQL
    ├── RLS policy        ← tenant isolation
    ├── CHECK constraint  ← value invariants
    ├── NOT NULL / FK     ← referential integrity
    ├── TRIGGER           ← audit log on every write
    └── TRANSACTION       ← atomic multi-step operations
```

---

## Ontology

The `ontology/` folder and per-lesson ontology notes form a concept graph.

When viewed in **Obsidian graph view** (open this repo as an Obsidian vault), linked concepts cluster visually:

```
Beginner cluster: table → column → constraint → index → query
                                                  │
Intermediate cluster: ──────────────────────────→ index types → GIN → pgvector
                                                                │
Advanced cluster: ──────────────────────────────────────────→ MVCC → vacuum → bloat
```

---

## Extension examples

### pgvector — vector similarity search

```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    content TEXT,
    embedding vector(1536)
);

CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops);

-- nearest 5 neighbours
SELECT content, embedding <=> '[0.1, 0.2, ...]'::vector AS distance
FROM documents
ORDER BY distance
LIMIT 5;
```

Agent use: semantic memory retrieval, RAG document search.

### pg_trgm — fuzzy search

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX ON products USING gin (name gin_trgm_ops);

SELECT name, similarity(name, 'postgress') AS sim
FROM products
WHERE name % 'postgress'
ORDER BY sim DESC;
```

Agent use: typo-tolerant search, user input correction.

### pgcrypto — encryption

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO users (email, password_hash)
VALUES ('alice@example.com', crypt('secret', gen_salt('bf')));

-- verify
SELECT crypt('secret', password_hash) = password_hash AS valid FROM users WHERE email = 'alice@example.com';
```

Agent use: never store plaintext secrets in agent-managed tables.

### ltree — hierarchy

```sql
CREATE EXTENSION IF NOT EXISTS ltree;

CREATE TABLE categories (path ltree, label TEXT);
INSERT INTO categories VALUES ('science', 'Science');
INSERT INTO categories VALUES ('science.physics', 'Physics');
INSERT INTO categories VALUES ('science.physics.quantum', 'Quantum Physics');

-- all descendants of science
SELECT * FROM categories WHERE path <@ 'science';
```

Agent use: hierarchical permission trees, org structures, category browsing.

### Row Level Security (RLS) — tenant isolation

```sql
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON documents
    USING (tenant_id = current_setting('app.tenant_id')::int);

-- agent sets its context before any query
SET app.tenant_id = '42';
SELECT * FROM documents; -- only sees tenant 42's rows
```

Agent use: multi-tenant SaaS, per-user data isolation.

---

## Stage map

| Stage | Layer | Content |
|-------|-------|---------|
| 0 | Setup | Audit, environment, session init — completed |
| 1 | Setup | Foundation skeleton — completed |
| 2 | Setup | Templates and validation scripts — completed |
| 3–4 | Beginner | Core lessons (schema, CRUD, constraints) — in progress |
| 5 | Beginner | Querying, indexes, transactions — in progress |
| 6 | Beginner | Non-SQL intro (JSONB, FTS, pgvector) — in progress |
| 7–8 | Intermediate | Schema design, EXPLAIN, index types — in progress |
| 9 | Intermediate | Transactions, MVCC, locking — in progress |
| 10 | Intermediate | Extensions and non-SQL — in progress |
| 11 | Intermediate | Security, audit, observability — in progress |
| 12 | Reference | Extension learning map — in progress |
| 13–14 | Ontology | Core + advanced concept maps — in progress |
| 15–17 | Examples | Beginner / intermediate / advanced — in progress |
| 18–20 | Advanced | Core, architecture, operations — in progress |
| 21 | Visuals | Diagrams — in progress |
| 22 | Design | Design principles — in progress |
| 23 | Reflection | Question banks — in progress |
| 24 | Reference | References curation — in progress |
| 25 | QA | Final quality review — in progress |
| 26–29 | Agent | MCP, agent safety, RLS, regulated domains — in progress |
