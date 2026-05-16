# Scripts

Validation and utility scripts for the l-pgsql PostgreSQL learning repo.

All scripts run from the **repo root** unless otherwise noted.

---

## scripts/stage-00/ — Stage 0 validation

### validate-env.sh

**Purpose:** Full environment check for Stage 0. Verifies git, Docker, container status, psql access, PostgreSQL version, user privileges, required extensions, and session memory files.

**Usage:**
```bash
bash scripts/stage-00/validate-env.sh
```

**Expected output:**
```
=== Git ===
[PASS] git repository initialized
[PASS] current branch: main
...
=== Summary ===
PASS : 25
WARN : 1
FAIL : 0
RESULT: VALIDATION PASSED WITH WARNINGS — review WARN items; Stage 1 can proceed
```

---

### validate-session-files.sh

**Purpose:** Checks that all prompt-pack session memory files and control files exist and are non-empty. Validates formatting of `current-stage.md` and `stage-history.md`.

**Usage:**
```bash
bash scripts/stage-00/validate-session-files.sh
```

**Expected output:**
```
=== Session memory files ===
[PASS] pgsql_learning_repo_prompt_pack/.learning-session/README.md
...
=== Summary ===
PASS : 18
FAIL : 0
RESULT: ALL CHECKS PASSED
```

---

### validate-extensions.sql

**Purpose:** Checks that required extensions are available and can be created in the `cfp` database. Tests actual SQL operations (vector distance, UUID generation, trigram similarity, etc.).

**Usage:**
```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < scripts/stage-00/validate-extensions.sql
```

**Expected output:** Extension availability table, installation confirmations, and sample query results for each tested extension.

---

## scripts/dashboards/ — Dashboard setup

### enable-pg-stat-statements.sh

**Purpose:** Enables `pg_stat_statements` in `cfp_postgres` by setting `shared_preload_libraries` via `ALTER SYSTEM`, restarting the container, and creating the extension. Required before the Grafana dashboard can show query stats.

**Usage:**
```bash
bash scripts/dashboards/enable-pg-stat-statements.sh
```

**Expected output:**
```
==> Enabling pg_stat_statements in shared_preload_libraries...
==> Restarting cfp_postgres...
==> Waiting for PostgreSQL to be ready...
==> Creating pg_stat_statements extension...
DONE — pg_stat_statements is active.
```

**Note:** Requires Docker daemon running. Triggers a container restart (brief downtime).

---

## scripts/ (root) — General validation

### check-required-files.sh

**Purpose:** Checks that all required files for a given stage exist in the repo. Useful for confirming a stage's deliverables before marking it complete.

**Usage:**
```bash
bash scripts/check-required-files.sh --stage 0
bash scripts/check-required-files.sh --stage 1
bash scripts/check-required-files.sh --stage 2
```

**Expected output:**
```
=== Required files for Stage 2 ===
[PASS] tools/templates/lesson-template.md
[PASS] tools/templates/practice-template.md
...
=== Summary ===
PASS : 17
FAIL : 0
RESULT: ALL REQUIRED FILES PRESENT
```

---

### validate-stage.sh

**Purpose:** Top-level wrapper that runs all checks appropriate for a given stage: required-file check, Docker connection test, and a note on which SQL validations to run manually.

**Usage:**
```bash
bash scripts/validate-stage.sh --stage 2
```

**Expected output:**
```
=== Stage 2 Validation ===
--- Required files ---
[PASS] tools/templates/lesson-template.md
...
--- Docker connection ---
[PASS] container cfp_postgres is running
[PASS] PostgreSQL connection OK
--- Summary ---
PASS : 20  WARN : 0  FAIL : 0
RESULT: STAGE 2 VALIDATION PASSED
```

---

### validate-practice-structure.sh

**Purpose:** Checks that a practice session folder contains all required files (README.md, setup.sql, exercises.md, solutions.md, reflection.md, etc.). Can also validate all sessions in a level at once.

**Usage:**
```bash
# Single folder
bash scripts/validate-practice-structure.sh practice/beginner/01-basic-sql

# All beginner sessions
bash scripts/validate-practice-structure.sh --all-beginner

# All intermediate sessions
bash scripts/validate-practice-structure.sh --all-intermediate

# All advanced sessions
bash scripts/validate-practice-structure.sh --all-advanced
```

**Expected output:**
```
=== Validating: practice/beginner/01-basic-sql ===
[PASS] README.md
[PASS] setup.sql
[PASS] exercises.md
...
RESULT: ALL CHECKS PASSED
```

---

### validate-sql-files.sh

**Purpose:** Scans `scripts/` and `examples/` for `.sql` files and checks each is non-empty (contains at least one SQL statement). Does not execute any SQL — purely a file structure check.

**Usage:**
```bash
bash scripts/validate-sql-files.sh
```

**Expected output:**
```
=== SQL file structure check ===
[PASS] scripts/stage-00/validate-extensions.sql (126 lines)
[PASS] scripts/validate-extension-availability.sql (80 lines)
...
=== Summary ===
PASS : 4  FAIL : 0
RESULT: ALL SQL FILES ARE NON-EMPTY
```

---

### validate-extension-availability.sql

**Purpose:** Comprehensive SQL check of all 48 extensions known to be available in the `cfp_postgres` container. Returns name and availability/installation status. Includes a summary count. More complete than the Stage 0 version.

**Usage:**
```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < scripts/validate-extension-availability.sql
```

**Expected output:** A table of all 48 extensions with their status (INSTALLED / available / NOT available), plus a summary row count.

---

### run-example.sh

**Purpose:** Helper that prepares and optionally executes a runnable example. Validates folder structure (README.md + setup.sql), displays the setup SQL, and prompts before executing against the live database.

**Usage:**
```bash
bash scripts/run-example.sh --example examples/beginner/simple-store
```

**Expected output:**
```
=== Example: examples/beginner/simple-store ===
[PASS] README.md found
[PASS] setup.sql found
--- setup.sql contents ---
...
Run setup.sql against cfp_postgres? [y/N]:
```

---

## Stage validation quick reference

| Stage | Run when Docker is available |
|-------|------------------------------|
| 0 | bash scripts/stage-00/validate-env.sh |
| 1 | bash scripts/check-required-files.sh --stage 1 |
| 2 | bash scripts/check-required-files.sh --stage 2 |
| 3 | bash scripts/validate-stage.sh --stage 3 |
| 4-29 | bash scripts/validate-stage.sh --stage N |

To validate all practice SQL for beginner level:
bash scripts/validate-practice-structure.sh --all-beginner

To check all SQL files are non-empty:
bash scripts/validate-sql-files.sh
