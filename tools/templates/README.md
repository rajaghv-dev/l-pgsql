# tools/templates

Templates for every content type in this repository.
Copy the relevant template, fill in `<!-- TODO: ... -->` placeholders, delete instruction blocks, and commit.

---

## Template index

| Template file | Use for | Location of output |
|---------------|---------|-------------------|
| `lesson-template.md` | Any lesson — all sections, all levels | `concepts/<level>/<topic>.md` |
| `beginner-lesson-template.md` | Beginner-calibrated lesson | `concepts/beginner/<topic>.md` |
| `intermediate-lesson-template.md` | Intermediate-calibrated lesson | `concepts/intermediate/<topic>.md` |
| `advanced-lesson-template.md` | Advanced-calibrated lesson | `concepts/advanced/<topic>.md` |
| `extension-lesson-template.md` | Extension deep-dive | `extensions/<extension_name>.md` |
| `practice-template.md` | Full practice session (all 8 files) | `practice/<level>/<topic>/` |
| `example-template.md` | Domain example folder | `examples/<level>/<domain>/README.md` |
| `ontology-template.md` | Concept ontology entry | `ontology/<concept-name>.md` |
| `reference-template.md` | Adding references | `references.md` or `practice/.../references.md` |
| `design-principle-template.md` | Schema / system design principle | `design-principles/<principle-slug>.md` |
| `stage-report-template.md` | Stage completion report | `.learning-session/agent-handoff.md` |

---

## When to use each template

### `lesson-template.md`

Use this as the base template when you are not sure which level to use, or when a lesson spans multiple levels. It contains all sections defined in `MASTER_SPEC.md` with instructions inside each section.

### `beginner-lesson-template.md`

Use for `concepts/beginner/` files. Calibrated to:
- Intuition-first explanations and everyday analogies
- Micro-practice with immediate validation
- Simple agent scenarios (task list, notes, search)
- No EXPLAIN internals, MVCC, or buffer-level details

### `intermediate-lesson-template.md`

Use for `concepts/intermediate/` files. Calibrated to:
- Design trade-off tables
- EXPLAIN ANALYZE output interpretation
- RLS and audit trigger patterns
- Agent scenarios with tenant isolation

### `advanced-lesson-template.md`

Use for `concepts/advanced/` files. Calibrated to:
- Storage and WAL internals
- Lock mode analysis
- Performance forensics (`pg_stat_statements`, `pg_buffercache`, `pageinspect`)
- Agent-safe architecture with immutable audit trails

### `extension-lesson-template.md`

Use for `extensions/<extension_name>.md` files. Contains:
- Install command and verification
- Core operations with runnable SQL
- Index types and performance characteristics
- Agent/MCP usage pattern
- When to use / when NOT to use / alternatives

### `practice-template.md`

Use when creating a new `practice/<level>/<topic>/` folder. This single file shows the content that belongs in each of the 8 required practice files:
- `README.md` — goals, prerequisites, quick start
- `setup.sql` — idempotent schema + seed data with a DO $$ ASSERT block
- `00-setup-validation.md` — step-by-step validation checks
- `exercises.md` — exercises with agent/MCP angle in each
- `solutions.md` — solutions with explanations and variations
- `reflection.md` — comprehension, design, and connection questions
- `ontology-notes.md` — concept map and Obsidian links
- `troubleshooting.md` — common errors, silent failures, setup fixes

### `example-template.md`

Use for `examples/<level>/<domain>/README.md`. Contains:
- Domain overview (synthetic data note included)
- Schema with `CREATE TABLE` and `COMMENT ON`
- Seed data (synthetic only — no real personal data)
- Example queries (basic → advanced)
- Validation queries
- Practice tasks
- MCP/agent scenario with the standard angle block
- Teardown SQL

### `ontology-template.md`

Use for `ontology/<concept-name>.md`. Contains:
- Precise definition
- Parent, child, related, and contrasting concepts
- SQL representation (create, inspect, modify, remove)
- System catalog details
- Agent/MCP view
- Practical implication table
- Obsidian wikilinks for graph view

### `reference-template.md`

Use when adding entries to any `references.md` file. Contains:
- Table format definition
- Field definitions (type values, level values, time format)
- Preferred domain list (free, verified sources only)
- Complete entry examples for each reference type
- Missing reference protocol

### `design-principle-template.md`

Use for `design-principles/<principle-slug>.md`. Contains:
- One-line actionable rule
- Rationale
- Correct example with verification SQL
- Counter-example with failure mode analysis
- When the principle applies / when to break it
- Full PostgreSQL implementation section (constraints, triggers, RLS)
- Agent/MCP safety implications table

### `stage-report-template.md`

Use at the end of every stage. Fill in and save to `.learning-session/agent-handoff.md`. Contains:
- Files created / modified tables
- Validation results table (check | command | result | notes)
- Blockers table
- TODOs deferred to future stages
- Next actions list
- Git status section
- Permission request block (agents must stop and ask before continuing)
- Session memory update checklist

---

## SQL execution convention

Every SQL block in every template uses this format:

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- SQL here -->
"
```

For multi-statement scripts:
```bash
docker exec cfp_postgres psql -U cfp -d cfp \
  -f /mnt/d/wsl/l-pgsql/path/to/file.sql
```

Connection details:
- Container: `cfp_postgres`
- User: `cfp`
- Database: `cfp`
- Password: `cfp`

---

## Quality checklist before committing a filled-in template

- [ ] All `<!-- TODO: ... -->` placeholders replaced with real content
- [ ] All instruction blocks (lines starting with `>`) deleted
- [ ] Every SQL block tested and output pasted
- [ ] References verified as free and accessible
- [ ] Synthetic data only — no real names, emails, or financial data
- [ ] Ontology links use `[[concept]]` wikilink format
- [ ] File committed to the correct folder (`concepts/`, `practice/`, `extensions/`, etc.)
