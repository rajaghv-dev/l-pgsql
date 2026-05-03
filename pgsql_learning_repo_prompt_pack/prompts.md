# prompts.md

Reusable prompts for coding agents working on this staged learning repository.

---

## Stage continuation prompt

Continue this PostgreSQL learning repo from the current stage.

Before doing anything:

1. Read `AGENT_BOOTSTRAP.md`.
2. Read `CURRENT_STAGE.md`.
3. Read `STAGES.md`.
4. Read `DONE_CRITERIA.md`.
5. Read `.learning-session/agent-handoff.md`.
6. Read `.learning-session/validation-log.md`.
7. Identify the next allowed stage.
8. Work only on that stage.
9. Run that stage's self-tests.
10. Update session memory.
11. Stop and ask permission before continuing.

Do not generate future stages unless explicitly approved.

---

## Stage repair prompt

Repair the current incomplete stage.

Before editing:

1. Read `.learning-session/current-stage.md`.
2. Read `.learning-session/validation-log.md`.
3. Read `TODO.md`.
4. Identify failed or blocked validation.
5. Fix only the current stage.
6. Run self-tests again.
7. Update session memory.
8. Stop.

---

## New technology repo prompt

Create a staged learning repo for `<TECHNOLOGY_NAME>` using the same structure as this PostgreSQL learning repo.

Requirements:

- phase-by-phase generation
- session memory
- beginner/intermediate/advanced stages
- micro-practices
- validation
- ontology notes
- self-tests
- curated internet references
- MCP/agent perspective where relevant
- stop after each stage
- ask permission before continuing

Do not generate the whole repo in one pass.

---

## Lesson generation prompt

Create a short lesson for `<TOPIC>` at `<LEVEL>`.

Rules:

- first-principles explanation
- beginner/intermediate/advanced relation where useful
- micro-concepts
- micro-practice for every micro-concept
- validation query
- ontology note
- MCP/agent perspective where relevant
- critical thinking
- creative thinking
- systems thinking
- references
- keep content concise

---

## Practice generation prompt

Create a micro-practice for `<TOPIC>` at `<LEVEL>`.

Every step must include:

- why this exists
- command or SQL
- expected result
- validation query
- common error
- fix
- ontology note
- Agent/MCP angle where relevant
- first-principles question
- critical-thinking question
- creative-thinking question
- systems-thinking question
- where this applies in real systems
- references

---

## MCP/agent practice expansion prompt

Expand the PostgreSQL practice session for `<TOPIC>` with MCP and AI-agent perspective.

For each exercise, add:

- Agent scenario
- MCP tool name
- Tool input schema
- Tool output contract
- PostgreSQL operation
- Required permission
- Validation before execution
- Audit log entry
- Human approval needed
- Failure mode
- Recovery or rollback
- Ontology connection
- Small domain example from legal, financial, medical, pharma, office, or compliance where relevant

Rules:

- Use synthetic data only.
- Keep examples small.
- Do not create professional advice logic.
- Do not expose raw database access to the agent.
- Prefer narrow tools.
- Use PostgreSQL constraints, transactions, RLS, triggers, and audit logs for safety.
- Keep content concise.

---

## Regulated domain mini-example prompt

Create a small PostgreSQL learning example for `<DOMAIN>` using an MCP/agent workflow.

Domain options:

- legal
- financial
- medical
- pharma
- office team
- compliance

The example must include:

- 3 to 5 tables
- synthetic seed data
- 5 to 10 queries
- MCP tool ideas
- permission model
- approval model
- audit model
- ontology notes
- practice tasks
- validation queries
- failure modes
- safe boundaries

Rules:

- No real sensitive data.
- No professional advice.
- Medical: no diagnosis or treatment.
- Legal: no legal advice.
- Financial: no financial advice.
- Pharma: no regulatory claims.
- Focus on workflow, retrieval, audit, permissions, human approval, and traceability.

---

## Agent safety review prompt

Review the current PostgreSQL lesson or practice for agent safety.

Check:

- Does the MCP tool expose too much?
- Is the permission boundary clear?
- Is RLS needed?
- Are constraints protecting invariants?
- Is there an audit log?
- Is human approval needed?
- Is the transaction boundary clear?
- Can the action be rolled back?
- Can the agent leak sensitive data?
- Can the agent confuse tenants, clients, patients, cases, invoices, or batches?
- Are examples synthetic and safe?
- Are unsafe professional advice behaviors avoided?

Return:

- safe
- unsafe
- needs improvement
- required fixes
- suggested validation tests

---

## Reference discovery prompt

Find high-quality free references for the PostgreSQL topic: `<TOPIC>`.

Prefer:

1. Official PostgreSQL documentation
2. Official extension documentation
3. Free open-source books
4. University notes
5. Known engineering blogs
6. Short YouTube videos under 15 minutes
7. Open-source runnable examples

Avoid:

- paid courses
- random SEO blogs
- copied content
- long videos unless no short option exists

Return:

- title
- URL
- type
- estimated time
- level: beginner / intermediate / advanced
- why useful
- related repo file
- whether it should be added to `references.md`

---

## Validation prompt

Validate the current stage.

Steps:

1. Read `STAGES.md`.
2. Read `CURRENT_STAGE.md`.
3. Check required files.
4. Check practice structure.
5. Check SQL files.
6. Run examples if possible.
7. Record pass/fail/blocked.
8. Update `.learning-session/validation-log.md`.
9. Do not mark stage complete unless validation is done or blockers are documented.

---

## Stage prompt splitter

Take `MASTER_SPEC.md` and split it into stage-specific prompts.

Create files under `STAGE_PROMPTS/`.

Rules:

- One file per stage.
- Each stage prompt must be self-contained.
- Each stage prompt must include:
  - goal
  - files in scope
  - files out of scope
  - tasks
  - validation
  - done criteria
  - stop condition
- Do not duplicate the full master spec in every stage.
- Keep each stage prompt concise.
- Preserve staged execution, validation, memory update, and permission checkpoint rules.
