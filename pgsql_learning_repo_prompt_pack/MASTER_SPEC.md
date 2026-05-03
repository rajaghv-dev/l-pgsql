# MASTER_SPEC

This is the master specification for a staged PostgreSQL / PGSQL learning repository.

Do not feed this whole file to a coding agent every time. Treat it as the constitution of the repo. The coding agent should normally read:

1. `AGENT_BOOTSTRAP.md`
2. `CURRENT_STAGE.md`
3. `DONE_CRITERIA.md`
4. `STAGES.md`
5. The matching file under `STAGE_PROMPTS/`
6. `.learning-session/agent-handoff.md`, if it exists

The goal is to build the repo phase by phase with validation, memory, and permission checkpoints.

---

## Repo goal

Create a practical PostgreSQL learning repository that teaches PostgreSQL from first principles using:

- beginner, intermediate, and advanced learning stages
- short lessons
- micro-practices
- setup validation
- self-tests
- ontology mapping
- curated internet references
- SQL and non-SQL capability mapping
- PostgreSQL extensions
- vector search
- full-text search
- fuzzy search
- geospatial
- time-series
- JSONB
- AI-agent memory
- Model Context Protocol perspectives
- multi-tenant SaaS
- observability
- compliance and audit systems
- database-backed systems thinking

This repo must become a first-principles learning lab, not a notes dump.

---

## Global execution rule

Work stage by stage.

Never implement more than one stage unless explicitly instructed.

After completing each stage:

1. Run the required self-tests.
2. Validate practice/example SQL where possible.
3. Record pass/fail/blocked results.
4. Update `.learning-session/`.
5. Update `TODO.md`.
6. Report git status.
7. Stop.
8. Ask permission before moving to the next stage.

Use limited tokens.

Prefer references over long explanations.

Do not create all lessons, examples, diagrams, and practices in one pass.

---

## Required repo control files

The repo should contain:

```text
.
├── MASTER_SPEC.md
├── AGENT_BOOTSTRAP.md
├── CURRENT_STAGE.md
├── DONE_CRITERIA.md
├── STAGES.md
├── prompts.md
├── STAGE_PROMPTS/
└── .learning-session/
```

The long vision lives in `MASTER_SPEC.md`.

The coding agent should usually operate from `CURRENT_STAGE.md` plus one stage prompt.

---

## Session memory

Create and update:

```text
.learning-session/
├── README.md
├── current-stage.md
├── stage-history.md
├── repo-memory.md
├── decisions.md
├── open-questions.md
├── validation-log.md
├── generated-files.md
├── next-actions.md
├── agent-handoff.md
└── prompts-used.md
```

These files make the repo resumable across sessions and agents.

---

## Learning structure

The repo should eventually include:

```text
concepts/
├── beginner/
├── intermediate/
└── advanced/

practice/
├── beginner/
├── intermediate/
└── advanced/

examples/
├── beginner/
├── intermediate/
└── advanced/

extensions/
ontology/
diagrams/
design-principles/
reflections/
scripts/
tools/templates/
```

---

## Beginner / intermediate / advanced rule

Every major learning area should eventually exist at three levels.

Beginner:
- intuition
- small commands
- micro-practice
- validation
- simple analogies

Intermediate:
- design trade-offs
- schema judgment
- query planning
- indexing
- transactions
- RLS
- audit
- extension usage

Advanced:
- systems thinking
- internals
- performance
- reliability
- failure modes
- operations
- agent-safe architecture

Do not generate all levels at once.

---

## PostgreSQL capability coverage

The repo must eventually cover:

Core:
- SQL
- schema design
- constraints
- indexes
- query planning
- transactions
- MVCC
- locks
- views
- materialized views
- functions
- triggers
- roles
- privileges
- RLS
- partitioning
- migrations
- observability
- performance debugging

Non-SQL and hybrid:
- JSONB
- full-text search
- fuzzy search
- vector search
- geospatial
- time-series
- recursive CTEs
- graph-like modeling
- queue-like patterns with `SKIP LOCKED`
- audit/event-sourcing patterns
- semantic memory for AI agents

Extensions:
- pgvector
- pg_trgm
- PostGIS
- pg_stat_statements
- pgcrypto
- citext
- ltree
- postgres_fdw
- unaccent
- hstore
- tablefunc
- btree_gin
- btree_gist
- auto_explain
- pg_buffercache
- pageinspect
- pg_prewarm
- amcheck
- pgaudit
- TimescaleDB concepts
- PL/pgSQL
- PL/Python concepts

---

## MCP and AI-agent perspective

Every relevant lesson and practice must include:

```markdown
## MCP and agent perspective
```

Cover:

- What would an AI agent need to know?
- What state would the agent read?
- What state would the agent write?
- What MCP tool would expose this operation?
- What should not be exposed?
- What permission boundary is required?
- What validation should happen before execution?
- What audit event should be recorded?
- What human approval is required?
- What can go wrong?
- What can be rolled back?
- What must be append-only?
- How do constraints, transactions, RLS, triggers, and audit logs make the agent safer?

For every relevant practice exercise include:

```markdown
## Agent/MCP angle
- Agent scenario:
- MCP tool name:
- Tool input:
- Tool output:
- PostgreSQL operation:
- Required permission:
- Validation before execution:
- Audit log entry:
- Human approval needed:
- Failure mode:
- Recovery or rollback:
- Ontology connection:
```

Beginner examples should stay simple:
- search notes
- create task
- update task status
- retrieve document
- log action

Intermediate examples may include:
- RLS
- audit tables
- approval workflows
- transactions
- vector retrieval

Advanced examples may include:
- agent-safe architecture
- cross-tenant isolation
- immutable evidence
- rollback and compensation
- MCP gateway design

---

## Regulated-domain examples

Use small, synthetic examples only.

Allowed domains:
- legal
- financial
- medical
- pharma
- office team members
- compliance and audit

Focus on:
- workflow
- retrieval
- audit
- permissions
- human approval
- data integrity
- traceability

Do not create:
- legal advice logic
- financial advice logic
- diagnosis logic
- treatment logic
- pharma regulatory claims
- unsafe automated approval systems

Medical examples must avoid diagnosis and treatment.  
Legal examples must avoid legal advice.  
Financial examples must avoid financial advice.  
Pharma examples must avoid regulatory claims.

---

## Lesson template requirement

Each lesson should include:

```markdown
# Topic

Level: Beginner / Intermediate / Advanced

## One-line intuition
## Why this exists
## First-principles explanation
## Micro-concepts
## Beginner view
## Intermediate view
## Advanced view
## Mental model
## PostgreSQL view
## SQL view
## Non-SQL or hybrid view
## Design principle
## Critical thinking
## Creative thinking
## Systems thinking
## MCP and agent perspective
## Ontology perspective
## Practice session
## References
```

Keep content concise. Use references for deeper learning.

---

## Practice template requirement

Each practice folder must contain:

```text
README.md
setup.sql
00-setup-validation.md
exercises.md
solutions.md
reflection.md
ontology-notes.md
troubleshooting.md
references.md
```

Every setup step must include:
- command or SQL
- why this exists
- expected output
- validation query
- common error
- fix
- ontology note

Every exercise must include:
- goal
- first-principles question
- setup
- task
- SQL
- expected result
- hint
- solution
- validation query
- critical-thinking question
- creative-thinking question
- systems-thinking question
- ontology-thinking question
- Agent/MCP angle
- what this teaches
- where this applies in real systems
- references

---

## Reference policy

Use internet references instead of generating excessive content.

Prefer:
- PostgreSQL official documentation
- official extension docs
- PostgreSQL wiki
- free open-source books
- university notes
- high-quality engineering blogs
- open-source repos
- short YouTube videos under 15 minutes

Avoid:
- paid resources
- random SEO blogs
- fabricated links
- copied long content
- long videos unless no short option exists

If unsure, write:

```markdown
TODO: Find verified reference for this topic.
```

---

## Validation policy

A stage is not done unless:

- required files exist
- required folders exist
- practice folders have required files
- SQL is validated or blockers are documented
- examples/practices pass where possible
- validation log is updated
- generated-files log is updated
- agent handoff is updated
- TODOs are captured
- git status is reported

Say:
- `completed with validation`
- `partially completed; validation blocked because...`
- `incomplete; requires repair`

Never say completed without validation.

---

## Final operating model

`MASTER_SPEC.md` is the constitution.  
`STAGES.md` is the roadmap.  
`CURRENT_STAGE.md` is the command.  
`STAGE_PROMPTS/` are work orders.  
`.learning-session/` is memory.  
`DONE_CRITERIA.md` is the gatekeeper.
