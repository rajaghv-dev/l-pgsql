#!/usr/bin/env bash
# Stage 0 environment validation script.
# Run from repo root: bash scripts/stage-00/validate-env.sh

set -euo pipefail

PASS=0
FAIL=0
WARN=0

DOCKER_CONTAINER="${PGSQL_CONTAINER:-cfp_postgres}"
POSTGRES_USER="${PGSQL_USER:-cfp}"
POSTGRES_DB="${PGSQL_DB:-cfp}"

pass()  { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail()  { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }
warn()  { echo "[WARN] $1"; WARN=$((WARN+1)); }
header(){ echo; echo "=== $1 ==="; }

# ── Git ──────────────────────────────────────────────────────────────────────
header "Git"

if git rev-parse --git-dir > /dev/null 2>&1; then
    pass "git repository initialized"
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    pass "current branch: $BRANCH"
else
    fail "git repository NOT initialized — run: git init"
fi

if command -v git > /dev/null 2>&1; then
    GIT_VER=$(git --version)
    pass "git available: $GIT_VER"
else
    fail "git not found in PATH"
fi

# ── Docker ────────────────────────────────────────────────────────────────────
header "Docker"

if command -v docker > /dev/null 2>&1; then
    DOCKER_VER=$(docker --version)
    pass "docker available: $DOCKER_VER"
else
    fail "docker not found in PATH"
fi

if docker info > /dev/null 2>&1; then
    pass "docker daemon is running"
else
    fail "docker daemon is NOT running — start Docker first"
fi

if docker inspect "$DOCKER_CONTAINER" > /dev/null 2>&1; then
    CONTAINER_STATUS=$(docker inspect "$DOCKER_CONTAINER" --format '{{.State.Status}}')
    if [[ "$CONTAINER_STATUS" == "running" ]]; then
        pass "container '$DOCKER_CONTAINER' is running"
    else
        fail "container '$DOCKER_CONTAINER' exists but status is: $CONTAINER_STATUS"
    fi
else
    fail "container '$DOCKER_CONTAINER' not found — start it or set PGSQL_CONTAINER"
fi

# ── psql (host) ───────────────────────────────────────────────────────────────
header "psql on host"

if command -v psql > /dev/null 2>&1; then
    PSQL_VER=$(psql --version)
    pass "psql available on host: $PSQL_VER"
else
    warn "psql NOT in host PATH — using docker exec instead (acceptable for this setup)"
fi

# ── psql (container) ─────────────────────────────────────────────────────────
header "PostgreSQL connection (via container)"

if docker inspect "$DOCKER_CONTAINER" > /dev/null 2>&1 && \
   [[ "$(docker inspect "$DOCKER_CONTAINER" --format '{{.State.Status}}')" == "running" ]]; then

    if docker exec "$DOCKER_CONTAINER" psql --version > /dev/null 2>&1; then
        PSQL_CONTAINER_VER=$(docker exec "$DOCKER_CONTAINER" psql --version)
        pass "psql in container: $PSQL_CONTAINER_VER"
    else
        fail "psql not found inside container '$DOCKER_CONTAINER'"
    fi

    PG_VER=$(docker exec "$DOCKER_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -tAc "SELECT version();" 2>&1)
    if echo "$PG_VER" | grep -q "PostgreSQL"; then
        pass "postgres connection OK: $(echo "$PG_VER" | head -1 | cut -c1-60)..."
    else
        fail "postgres connection FAILED: $PG_VER"
    fi

    # Schema check
    SCHEMA=$(docker exec "$DOCKER_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -tAc "SELECT current_schema();" 2>&1)
    pass "current schema: $SCHEMA"

    # Superuser check
    IS_SUPER=$(docker exec "$DOCKER_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -tAc "SELECT usesuper FROM pg_user WHERE usename = current_user;" 2>&1)
    if [[ "$IS_SUPER" == "t" ]]; then
        pass "user '$POSTGRES_USER' has superuser privileges (can CREATE EXTENSION)"
    else
        warn "user '$POSTGRES_USER' is NOT superuser — some extensions may not install"
    fi
else
    warn "skipping PostgreSQL connection checks — container not running"
fi

# ── Extensions ────────────────────────────────────────────────────────────────
header "Required extensions (available in PostgreSQL)"

REQUIRED_EXTENSIONS=(
    "vector"
    "pgcrypto"
    "pg_stat_statements"
    "pg_trgm"
    "uuid-ossp"
    "hstore"
    "ltree"
    "citext"
    "btree_gin"
    "btree_gist"
    "unaccent"
    "tablefunc"
    "postgres_fdw"
    "pageinspect"
    "pg_buffercache"
    "bloom"
)

OPTIONAL_EXTENSIONS=(
    "pg_cron"
    "timescaledb"
    "postgis"
    "pgaudit"
)

if docker inspect "$DOCKER_CONTAINER" > /dev/null 2>&1 && \
   [[ "$(docker inspect "$DOCKER_CONTAINER" --format '{{.State.Status}}')" == "running" ]]; then

    AVAILABLE=$(docker exec "$DOCKER_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -tAc "SELECT name FROM pg_available_extensions ORDER BY name;" 2>&1)

    for ext in "${REQUIRED_EXTENSIONS[@]}"; do
        if echo "$AVAILABLE" | grep -qx "$ext"; then
            pass "extension available: $ext"
        else
            fail "extension NOT available: $ext"
        fi
    done

    echo
    echo "--- Optional extensions ---"
    for ext in "${OPTIONAL_EXTENSIONS[@]}"; do
        if echo "$AVAILABLE" | grep -qx "$ext"; then
            pass "optional extension available: $ext"
        else
            warn "optional extension NOT available: $ext (lessons using it will be marked TODO)"
        fi
    done
else
    warn "skipping extension checks — container not running"
fi

# ── Session files ─────────────────────────────────────────────────────────────
header "Session memory files"

SESSION_FILES=(
    "pgsql_learning_repo_prompt_pack/.learning-session/README.md"
    "pgsql_learning_repo_prompt_pack/.learning-session/current-stage.md"
    "pgsql_learning_repo_prompt_pack/.learning-session/stage-history.md"
    "pgsql_learning_repo_prompt_pack/.learning-session/repo-memory.md"
    "pgsql_learning_repo_prompt_pack/.learning-session/decisions.md"
    "pgsql_learning_repo_prompt_pack/.learning-session/open-questions.md"
    "pgsql_learning_repo_prompt_pack/.learning-session/validation-log.md"
    "pgsql_learning_repo_prompt_pack/.learning-session/generated-files.md"
    "pgsql_learning_repo_prompt_pack/.learning-session/next-actions.md"
    "pgsql_learning_repo_prompt_pack/.learning-session/agent-handoff.md"
    "pgsql_learning_repo_prompt_pack/.learning-session/prompts-used.md"
)

CONTROL_FILES=(
    "pgsql_learning_repo_prompt_pack/STAGES.md"
    "pgsql_learning_repo_prompt_pack/AGENT_BOOTSTRAP.md"
    "pgsql_learning_repo_prompt_pack/CURRENT_STAGE.md"
    "pgsql_learning_repo_prompt_pack/DONE_CRITERIA.md"
    "pgsql_learning_repo_prompt_pack/MASTER_SPEC.md"
    "pgsql_learning_repo_prompt_pack/TODO.md"
    "pgsql_learning_repo_prompt_pack/CHANGELOG.md"
)

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

for f in "${SESSION_FILES[@]}" "${CONTROL_FILES[@]}"; do
    if [[ -f "$REPO_ROOT/$f" ]]; then
        pass "file exists: $f"
    else
        fail "file MISSING: $f"
    fi
done

# ── Stage 0 content check ─────────────────────────────────────────────────────
header "Stage 0 completion check"

STAGE_FILE="$REPO_ROOT/pgsql_learning_repo_prompt_pack/.learning-session/current-stage.md"
if [[ -f "$STAGE_FILE" ]]; then
    if grep -q "completed" "$STAGE_FILE"; then
        pass "current-stage.md shows completed status"
    else
        warn "current-stage.md does not show completed — stage may still be in progress"
    fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
header "Summary"
echo "PASS : $PASS"
echo "WARN : $WARN"
echo "FAIL : $FAIL"

if [[ $FAIL -gt 0 ]]; then
    echo
    echo "RESULT: VALIDATION FAILED — fix the FAIL items above before proceeding to Stage 1"
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo
    echo "RESULT: VALIDATION PASSED WITH WARNINGS — review WARN items; Stage 1 can proceed"
    exit 0
else
    echo
    echo "RESULT: ALL CHECKS PASSED — Stage 0 complete, ready for Stage 1"
    exit 0
fi
