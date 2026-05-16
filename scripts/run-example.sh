#!/usr/bin/env bash
# Helper script to set up and optionally run a specific example.
# Checks that the example folder has README.md and setup.sql,
# displays setup.sql contents, then optionally runs it against cfp_postgres.
#
# Run from repo root: bash scripts/run-example.sh --example examples/beginner/simple-store

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

usage() {
    echo "Usage: bash scripts/run-example.sh --example <path>"
    echo ""
    echo "  --example <path>   Relative path to the example folder"
    echo "                     (e.g. examples/beginner/simple-store)"
    echo ""
    echo "Options:"
    echo "  --no-prompt        Skip the confirmation prompt and execute setup.sql directly"
    echo "  --dry-run          Show setup.sql contents only; never execute"
    echo ""
    echo "Environment variables:"
    echo "  PGSQL_CONTAINER    Docker container name (default: cfp_postgres)"
    echo "  PGSQL_USER         PostgreSQL user (default: cfp)"
    echo "  PGSQL_DB           PostgreSQL database (default: cfp)"
    echo ""
    echo "Examples:"
    echo "  bash scripts/run-example.sh --example examples/beginner/simple-store"
    echo "  bash scripts/run-example.sh --example examples/beginner/simple-store --no-prompt"
    echo "  bash scripts/run-example.sh --example examples/beginner/simple-store --dry-run"
    exit 1
}

# ── Argument parsing ──────────────────────────────────────────────────────────

EXAMPLE_PATH=""
NO_PROMPT=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --example)
            EXAMPLE_PATH="$2"
            shift 2
            ;;
        --no-prompt)
            NO_PROMPT=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
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

if [[ -z "$EXAMPLE_PATH" ]]; then
    echo "Error: --example <path> is required"
    usage
fi

# ── Resolve paths ─────────────────────────────────────────────────────────────

ABS_EXAMPLE="$REPO_ROOT/$EXAMPLE_PATH"

echo "=== Example: $EXAMPLE_PATH ==="
echo ""

# ── Validate folder structure ─────────────────────────────────────────────────

if [[ ! -d "$ABS_EXAMPLE" ]]; then
    fail "example folder does not exist: $EXAMPLE_PATH"
    echo ""
    echo "RESULT: CANNOT PROCEED — example folder missing"
    exit 1
fi

README="$ABS_EXAMPLE/README.md"
SETUP_SQL="$ABS_EXAMPLE/setup.sql"

if [[ -f "$README" ]]; then
    pass "README.md found"
else
    fail "README.md missing in $EXAMPLE_PATH"
fi

if [[ -f "$SETUP_SQL" ]]; then
    pass "setup.sql found"
else
    fail "setup.sql missing in $EXAMPLE_PATH"
fi

# Check for optional but common files
for optional_file in "teardown.sql" "queries.sql" "examples.sql"; do
    if [[ -f "$ABS_EXAMPLE/$optional_file" ]]; then
        pass "$optional_file found (optional)"
    fi
done

echo ""

# If required files are missing, stop now
if [[ $FAIL -gt 0 ]]; then
    echo "RESULT: CANNOT PROCEED — required files missing"
    exit 1
fi

# ── Display setup.sql ─────────────────────────────────────────────────────────

LINE_COUNT=$(wc -l < "$SETUP_SQL")
echo "--- setup.sql contents ($LINE_COUNT lines) ---"
echo ""
cat "$SETUP_SQL"
echo ""
echo "--- end of setup.sql ---"
echo ""

# ── Dry-run: stop here ────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "true" ]]; then
    echo "RESULT: DRY RUN — setup.sql not executed"
    exit 0
fi

# ── Check Docker availability ─────────────────────────────────────────────────

DOCKER_AVAILABLE=false

if ! command -v docker > /dev/null 2>&1; then
    warn "docker not found in PATH — cannot execute setup.sql"
elif ! docker info > /dev/null 2>&1; then
    warn "docker daemon not running — cannot execute setup.sql"
elif ! docker inspect "$DOCKER_CONTAINER" > /dev/null 2>&1; then
    warn "container '$DOCKER_CONTAINER' not found — cannot execute setup.sql"
else
    CONTAINER_STATUS=$(docker inspect "$DOCKER_CONTAINER" --format '{{.State.Status}}')
    if [[ "$CONTAINER_STATUS" == "running" ]]; then
        DOCKER_AVAILABLE=true
    else
        warn "container '$DOCKER_CONTAINER' exists but status is: $CONTAINER_STATUS"
    fi
fi

if [[ "$DOCKER_AVAILABLE" == "false" ]]; then
    echo ""
    echo "To run setup.sql manually:"
    echo "  docker exec -i $DOCKER_CONTAINER psql -U $POSTGRES_USER -d $POSTGRES_DB < $EXAMPLE_PATH/setup.sql"
    echo ""
    echo "RESULT: CANNOT EXECUTE — Docker container not available"
    exit 0
fi

# ── Confirmation prompt ───────────────────────────────────────────────────────

if [[ "$NO_PROMPT" == "false" ]]; then
    echo "Target: $DOCKER_CONTAINER / user=$POSTGRES_USER / db=$POSTGRES_DB"
    echo ""
    read -r -p "Run setup.sql against $DOCKER_CONTAINER? [y/N]: " CONFIRM
    echo ""
    case "$CONFIRM" in
        [yY]|[yY][eE][sS])
            ;;
        *)
            echo "RESULT: CANCELLED — setup.sql not executed"
            exit 0
            ;;
    esac
fi

# ── Execute setup.sql ─────────────────────────────────────────────────────────

echo "=== Executing setup.sql against $DOCKER_CONTAINER ==="
echo ""

if docker exec -i "$DOCKER_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$SETUP_SQL"; then
    echo ""
    pass "setup.sql executed successfully"
    echo ""
    echo "RESULT: EXAMPLE SETUP COMPLETE"
    exit 0
else
    echo ""
    fail "setup.sql execution failed — check output above for errors"
    echo ""
    echo "RESULT: EXECUTION FAILED — review psql output above"
    exit 1
fi
