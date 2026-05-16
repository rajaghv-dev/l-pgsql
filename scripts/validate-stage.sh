#!/usr/bin/env bash
# Top-level validation wrapper for a given stage.
# Calls check-required-files.sh, tests Docker connection, and notes any SQL
# validations that should be run manually.
#
# Run from repo root: bash scripts/validate-stage.sh --stage N

set -euo pipefail

PASS=0
FAIL=0
WARN=0

DOCKER_CONTAINER="${PGSQL_CONTAINER:-cfp_postgres}"
POSTGRES_USER="${PGSQL_USER:-cfp}"
POSTGRES_DB="${PGSQL_DB:-cfp}"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }
warn() { echo "[WARN] $1"; WARN=$((WARN+1)); }
header() { echo ""; echo "--- $1 ---"; }

usage() {
    echo "Usage: bash scripts/validate-stage.sh --stage N"
    echo ""
    echo "  --stage N    Stage number to validate (0–29)"
    echo ""
    echo "Examples:"
    echo "  bash scripts/validate-stage.sh --stage 0"
    echo "  bash scripts/validate-stage.sh --stage 1"
    echo "  bash scripts/validate-stage.sh --stage 2"
    echo "  bash scripts/validate-stage.sh --stage 3"
    exit 1
}

# ── Argument parsing ──────────────────────────────────────────────────────────

STAGE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stage)
            STAGE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
done

if [[ -z "$STAGE" ]]; then
    echo "Error: --stage N is required"
    usage
fi

echo "=== Stage $STAGE Validation ==="

# ── Required files ────────────────────────────────────────────────────────────

header "Required files"

FILE_CHECK_SCRIPT="$REPO_ROOT/scripts/check-required-files.sh"

if [[ ! -f "$FILE_CHECK_SCRIPT" ]]; then
    fail "scripts/check-required-files.sh not found — cannot run file check"
else
    # Run the file check; capture result without aborting on non-zero exit
    if bash "$FILE_CHECK_SCRIPT" --stage "$STAGE"; then
        # pass/fail already printed by the sub-script; just tally the result
        pass "required-file check passed (Stage $STAGE)"
    else
        fail "required-file check FAILED (Stage $STAGE) — see output above"
    fi
fi

# ── Docker connection ─────────────────────────────────────────────────────────

header "Docker connection"

if ! command -v docker > /dev/null 2>&1; then
    warn "docker not in PATH — skipping connection tests"
elif ! docker info > /dev/null 2>&1; then
    warn "docker daemon not running — skipping connection tests"
elif ! docker inspect "$DOCKER_CONTAINER" > /dev/null 2>&1; then
    warn "container '$DOCKER_CONTAINER' not found — skipping connection tests"
else
    CONTAINER_STATUS=$(docker inspect "$DOCKER_CONTAINER" --format '{{.State.Status}}')
    if [[ "$CONTAINER_STATUS" == "running" ]]; then
        pass "container '$DOCKER_CONTAINER' is running"

        PG_VER=$(docker exec "$DOCKER_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
            -tAc "SELECT version();" 2>&1)
        if echo "$PG_VER" | grep -q "PostgreSQL"; then
            pass "PostgreSQL connection OK: $(echo "$PG_VER" | head -1 | cut -c1-55)..."
        else
            fail "PostgreSQL connection FAILED: $PG_VER"
        fi
    else
        warn "container '$DOCKER_CONTAINER' exists but status is: $CONTAINER_STATUS"
    fi
fi

# ── Stage-specific checks ─────────────────────────────────────────────────────

header "Stage $STAGE specific checks"

case "$STAGE" in
    0)
        echo "  Hint: also run the detailed Stage 0 checks:"
        echo "    bash scripts/stage-00/validate-env.sh"
        echo "    bash scripts/stage-00/validate-session-files.sh"
        echo ""
        echo "  SQL validation (run manually):"
        echo "    docker exec -i cfp_postgres psql -U cfp -d cfp < scripts/stage-00/validate-extensions.sql"

        SESSION_FILE="$REPO_ROOT/pgsql_learning_repo_prompt_pack/.learning-session/current-stage.md"
        if [[ -f "$SESSION_FILE" ]]; then
            if grep -q "completed" "$SESSION_FILE"; then
                pass "current-stage.md shows completed"
            else
                warn "current-stage.md does not show completed — stage may be in progress"
            fi
        else
            warn "current-stage.md not found — session file checks skipped"
        fi
        ;;
    1)
        echo "  Hint: Stage 1 has no SQL deliverables — this is a content/structure stage."
        echo ""
        echo "  To verify README files are non-empty:"
        echo "    find . -path '*/concepts/*/README.md' -o -path '*/practice/*/README.md' | sort"

        # Spot-check a few key content files
        for f in "learning-roadmap.md" "AGENT_GUIDE.md" "extension-map.md"; do
            if [[ -f "$REPO_ROOT/$f" ]] && [[ -s "$REPO_ROOT/$f" ]]; then
                pass "$f exists and is non-empty"
            elif [[ -f "$REPO_ROOT/$f" ]]; then
                warn "$f exists but is empty"
            else
                fail "$f is missing"
            fi
        done
        ;;
    2)
        echo "  Hint: Stage 2 deliverables are templates and validation scripts."
        echo ""
        echo "  SQL validation (run manually):"
        echo "    docker exec -i cfp_postgres psql -U cfp -d cfp < scripts/validate-extension-availability.sql"
        echo ""
        echo "  To validate SQL file structure:"
        echo "    bash scripts/validate-sql-files.sh"
        echo ""
        echo "  To validate a practice session:"
        echo "    bash scripts/validate-practice-structure.sh practice/beginner/01-basic-sql"

        # Check that the Stage 2 scripts themselves are executable
        for script in \
            "scripts/check-required-files.sh" \
            "scripts/validate-stage.sh" \
            "scripts/validate-practice-structure.sh" \
            "scripts/validate-sql-files.sh" \
            "scripts/run-example.sh"
        do
            if [[ -f "$REPO_ROOT/$script" ]]; then
                if [[ -x "$REPO_ROOT/$script" ]]; then
                    pass "$script is executable"
                else
                    warn "$script exists but is not executable — run: chmod +x $script"
                fi
            else
                fail "$script is missing"
            fi
        done
        ;;
    3)
        echo "SQL validation hint for Stage 3:"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/beginner/00-environment-setup/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/beginner/01-basic-sql/setup.sql"
        ;;
    4)
        echo "SQL validation hint for Stage 4:"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/beginner/02-schema-and-table-basics/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/beginner/03-keys-and-constraints/setup.sql"
        ;;
    5)
        echo "SQL validation hint for Stage 5:"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/beginner/04-joins-and-aggregation/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/beginner/05-simple-indexes/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/beginner/06-simple-transactions/setup.sql"
        ;;
    6)
        echo "SQL validation hint for Stage 6:"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/beginner/07-jsonb-basics/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/beginner/08-views-and-functions-basics/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/beginner/09-roles-basics/setup.sql"
        ;;
    7)
        echo "SQL validation hint for Stage 7:"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/00-schema-design/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/01-constraint-driven-design/setup.sql"
        ;;
    8)
        echo "SQL validation hint for Stage 8:"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/02-indexing-strategies/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/03-query-planning/setup.sql"
        ;;
    9)
        echo "SQL validation hint for Stage 9:"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/04-transactions-and-isolation/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/05-mvcc-and-locking/setup.sql"
        ;;
    10)
        echo "SQL validation hint for Stage 10:"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/06-jsonb-modeling/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/07-full-text-and-fuzzy-search/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/08-geospatial-intro/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/09-pgvector-retrieval/setup.sql"
        ;;
    11)
        echo "SQL validation hint for Stage 11:"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/10-rls-and-multi-tenancy/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/11-audit-triggers/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/12-observability/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/13-ontology-modeling/setup.sql"
        ;;
    12)
        echo "SQL validation hint for Stage 12:"
        echo "  Stage 12 is extension documentation only — no practice SQL files."
        echo "  Verify extension docs exist: ls extensions/"
        ;;
    13)
        echo "SQL validation hint for Stage 13:"
        echo "  Stage 13 is ontology documentation only — no practice SQL files."
        echo "  Verify ontology docs exist: ls ontology/"
        ;;
    14)
        echo "SQL validation hint for Stage 14:"
        echo "  Stage 14 is ontology documentation only — no practice SQL files."
        echo "  Verify ontology docs exist: ls ontology/"
        ;;
    15)
        echo "SQL validation hint for Stage 15:"
        echo "  Stage 15 contains beginner examples with README only."
        echo "  If setup.sql files exist, run:"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /examples/beginner/simple-store/setup.sql"
        ;;
    16)
        echo "SQL validation hint for Stage 16:"
        echo "  Stage 16 contains intermediate examples with README only."
        echo "  If setup.sql files exist, run:"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /examples/intermediate/ecommerce/setup.sql"
        ;;
    17)
        echo "SQL validation hint for Stage 17:"
        echo "  Stage 17 contains advanced examples with README only."
        echo "  If setup.sql files exist, run:"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /examples/advanced/hybrid-search-system/setup.sql"
        ;;
    18)
        echo "SQL validation hint for Stage 18:"
        echo "  Stage 18 is advanced concepts only — no practice SQL files."
        echo "  Verify concept docs exist: ls concepts/advanced/"
        ;;
    19)
        echo "SQL validation hint for Stage 19:"
        echo "  Stage 19 is advanced concepts only — no practice SQL files."
        echo "  Verify concept docs exist: ls concepts/advanced/"
        ;;
    20)
        echo "SQL validation hint for Stage 20:"
        echo "  Stage 20 is advanced concepts only — no practice SQL files."
        echo "  Verify concept docs exist: ls concepts/advanced/"
        ;;
    21)
        echo "SQL validation hint for Stage 21:"
        echo "  Stage 21 is diagrams/documentation only — no SQL files."
        echo "  Verify diagram docs exist: ls diagrams/"
        ;;
    22)
        echo "SQL validation hint for Stage 22:"
        echo "  Stage 22 is design principles only — no SQL files."
        echo "  Verify design-principles docs exist: ls design-principles/"
        ;;
    23)
        echo "SQL validation hint for Stage 23:"
        echo "  Stage 23 is reflections documentation only — no SQL files."
        echo "  Verify reflections docs exist: ls reflections/"
        ;;
    24)
        echo "SQL validation hint for Stage 24:"
        echo "  Stage 24 is references documentation only — no SQL files."
        echo "  Verify references files exist: ls references.md concepts/*/references.md"
        ;;
    25)
        echo "SQL validation hint for Stage 25:"
        echo "  Stage 25 has no required files defined in the spec."
        echo "  No SQL validation needed."
        ;;
    26)
        echo "SQL validation hint for Stage 26:"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/14-mcp-tool-database-design/setup.sql"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /practice/intermediate/15-agent-safe-actions/setup.sql"
        ;;
    27)
        echo "SQL validation hint for Stage 27:"
        echo "  Stage 27 contains agent example READMEs only."
        echo "  If setup.sql files exist, run:"
        echo "  docker exec cfp_postgres psql -U cfp -d cfp -f /examples/intermediate/legal-case-notes-agent/setup.sql"
        ;;
    28)
        echo "SQL validation hint for Stage 28:"
        echo "  Stage 28 is advanced agent concepts and ontology — no practice SQL files."
        echo "  Verify concept docs exist: ls concepts/advanced/"
        ;;
    29)
        echo "SQL validation hint for Stage 29:"
        echo "  Stage 29 is reflections documentation only — no SQL files."
        echo "  Verify reflections docs exist: ls reflections/"
        ;;
    *)
        warn "No stage-specific checks defined for Stage $STAGE"
        ;;
esac

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "=== Summary ==="
printf "PASS : %d  WARN : %d  FAIL : %d\n" "$PASS" "$WARN" "$FAIL"

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "RESULT: STAGE $STAGE VALIDATION FAILED — fix FAIL items above"
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo ""
    echo "RESULT: STAGE $STAGE VALIDATION PASSED WITH WARNINGS — review WARN items"
    exit 0
else
    echo ""
    echo "RESULT: STAGE $STAGE VALIDATION PASSED"
    exit 0
fi
