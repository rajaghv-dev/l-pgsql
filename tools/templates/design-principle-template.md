# Design Principle: <!-- Principle Name -->

> File location: `design-principles/<!-- principle-slug -->.md`
>
> **How to use this template:**
> One file per design principle. Keep the principle name short and memorable.
> The "one-line rule" must be actionable — a developer should be able to apply it in 30 seconds.
> Every code example must be runnable with the local setup.
> Run SQL with: `docker exec cfp_postgres psql -U cfp -d cfp -c "..."`

---

## Principle name

`<!-- e.g., "Declare constraints at the schema level, not the application level" -->`

---

## One-line rule

<!-- TODO: fill in for this specific principle -->
One sentence. Imperative form. Must be concrete enough to apply immediately.

Examples:
- "Never store data you can compute."
- "Prefer partial indexes over filtering in code."
- "Every write must generate an audit record — enforce with a trigger, not with application logic."

---

## Rationale

<!-- TODO: fill in for this specific principle -->
Two to five sentences explaining why this principle exists.

- What failure does following this principle prevent?
- What is the cost of violating it? (Performance? Correctness? Security? Operability?)
- What assumption about systems does this principle encode?

Avoid restating the rule — explain the deeper reasoning.

---

## Example (correct)

<!-- TODO: fill in for this specific principle -->
Show the principle applied correctly in a realistic scenario.

**Scenario:** <!-- one sentence describing the context -->

```bash
# Correct approach
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: correct SQL demonstrating the principle -->
"
```

**Why this is correct:**
- <!-- reason 1 — what property this guarantees -->
- <!-- reason 2 — what failure this prevents -->

**Verify it holds:**
```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: query that confirms the principle is in effect, e.g., CHECK constraint visible in pg_constraint -->
"
```

---

## Counter-example (incorrect)

<!-- TODO: fill in for this specific principle -->
Show the principle violated. Make the failure mode clear.

**Scenario:** Same scenario as above, but implemented incorrectly.

```bash
# Incorrect approach — do NOT do this
docker exec cfp_postgres psql -U cfp -d cfp -c "
  <!-- TODO: anti-pattern SQL -->
"
```

**Why this fails:**
- <!-- failure mode 1 — what breaks when this assumption is violated -->
- <!-- failure mode 2 — what a future developer or agent might do that makes this worse -->

**The hidden cost:** <!-- one sentence about the failure that is not immediately visible — e.g., "This works until a second application writes to the table" -->

---

## When this principle applies

<!-- TODO: fill in for this specific principle -->
This principle applies when:

- <!-- condition 1 — e.g., "more than one application or agent writes to the table" -->
- <!-- condition 2 — e.g., "the table is part of a multi-tenant system" -->
- <!-- condition 3 — e.g., "data must be auditable or traceable" -->

Signal that you need this principle: <!-- one observable indicator, e.g., "you are writing validation logic in three different places" -->

---

## When to break this rule (with justification)

<!-- TODO: fill in for this specific principle -->
Every principle has exceptions. Document them so readers don't blindly apply the rule.

It is acceptable to deviate from this principle when:

- <!-- justified exception 1 — e.g., "prototyping in a single-user development environment" -->
- <!-- justified exception 2 — e.g., "the performance cost of enforcement is unacceptable at this scale and the trade-off is documented" -->

**Justification requirement:** If you deviate, you must document:
1. Why you deviated
2. What compensating control you put in place
3. When you will revisit the decision

---

## PostgreSQL implementation

<!-- TODO: fill in for this specific principle -->
How PostgreSQL mechanisms enforce or support this principle:

### Using CHECK constraints

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  ALTER TABLE <!-- table --> ADD CONSTRAINT <!-- name --> CHECK (<!-- expression -->);
"
```

### Using NOT NULL

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  ALTER TABLE <!-- table --> ALTER COLUMN <!-- col --> SET NOT NULL;
"
```

### Using UNIQUE constraints

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  ALTER TABLE <!-- table --> ADD CONSTRAINT <!-- name --> UNIQUE (<!-- columns -->);
"
```

### Using FOREIGN KEY constraints

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  ALTER TABLE <!-- table --> ADD CONSTRAINT <!-- name -->
    FOREIGN KEY (<!-- col -->) REFERENCES <!-- ref_table --> (<!-- ref_col -->)
    ON DELETE <!-- RESTRICT / CASCADE / SET NULL -->;
"
```

### Using triggers

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  CREATE OR REPLACE FUNCTION enforce_<!-- principle_name -->()
  RETURNS TRIGGER LANGUAGE plpgsql AS \$\$
  BEGIN
    -- <!-- what the trigger enforces -->
    IF <!-- violation condition --> THEN
      RAISE EXCEPTION '<!-- principle_name --> violated: %', <!-- detail -->;
    END IF;
    RETURN NEW;
  END;
  \$\$;

  CREATE TRIGGER trg_<!-- principle_name -->
    BEFORE INSERT OR UPDATE ON <!-- table -->
    FOR EACH ROW EXECUTE FUNCTION enforce_<!-- principle_name -->();
"
```

### Using Row Level Security

```bash
docker exec cfp_postgres psql -U cfp -d cfp -c "
  ALTER TABLE <!-- table --> ENABLE ROW LEVEL SECURITY;

  CREATE POLICY <!-- policy_name --> ON <!-- table -->
    USING (<!-- predicate that enforces the principle -->);
"
```

### Verify enforcement is in place

```bash
# Check constraints
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT conname, contype, pg_get_constraintdef(oid)
  FROM pg_constraint
  WHERE conrelid = '<!-- table -->'::regclass;
"

# Check triggers
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT tgname, tgenabled, pg_get_triggerdef(oid)
  FROM pg_trigger
  WHERE tgrelid = '<!-- table -->'::regclass AND NOT tgisinternal;
"

# Check RLS policies
docker exec cfp_postgres psql -U cfp -d cfp -c "
  SELECT polname, polcmd, pg_get_expr(polqual, polrelid)
  FROM pg_policy
  WHERE polrelid = '<!-- table -->'::regclass;
"
```

---

## Agent and MCP implications

<!-- TODO: fill in for this specific principle -->
How this design principle affects AI agent and MCP tool design:

- **Agent behavior this principle constrains:** <!-- e.g., "An agent must not bypass the audit trigger by using DELETE instead of a soft-delete UPDATE" -->
- **What the MCP tool must enforce:** <!-- e.g., "The tool validates the input against the same rules the CHECK constraint enforces, before issuing the SQL" -->
- **What happens if the agent violates this principle:** <!-- e.g., "PostgreSQL raises an exception, the transaction rolls back, the audit log records the failed attempt" -->
- **How PostgreSQL enforces the principle even if the agent misbehaves:** <!-- e.g., "The trigger fires regardless of which role or tool issues the write" -->
- **Principle-to-safety mapping:**

| Principle violation | PostgreSQL guard | Agent-visible error |
|--------------------|-----------------|---------------------|
| <!-- violation 1 --> | <!-- constraint / trigger / RLS --> | `<!-- error message -->` |
| <!-- violation 2 --> | <!-- constraint / trigger / RLS --> | `<!-- error message -->` |

---

## Ontology connection

<!-- TODO: fill in for this specific principle -->

- **This principle is a specialization of:** `[[<!-- broader design principle -->]]`
- **Concepts this principle governs:** `[[<!-- concept 1 -->]]`, `[[<!-- concept 2 -->]]`
- **Practices that embody this principle:** `[[<!-- practice file -->]]`

---

## References

<!-- TODO: fill in for this specific principle -->

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|-----------|
| <!-- title --> | <!-- URL --> | <!-- type --> | <!-- level --> | <!-- time --> | <!-- why relevant to this principle --> |

> If a reference cannot be verified, write: `TODO: Find verified reference for this principle.`
