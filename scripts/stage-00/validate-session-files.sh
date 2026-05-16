#!/usr/bin/env bash
# Stage 0: Validate all required session and control files exist and are non-empty.
# Run from repo root: bash scripts/stage-00/validate-session-files.sh

set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

check_file() {
    local path="$REPO_ROOT/$1"
    if [[ ! -f "$path" ]]; then
        fail "missing: $1"
        return
    fi
    if [[ ! -s "$path" ]]; then
        fail "empty: $1"
        return
    fi
    pass "$1"
}

echo "=== Session memory files ==="
check_file "pgsql_learning_repo_prompt_pack/.learning-session/README.md"
check_file "pgsql_learning_repo_prompt_pack/.learning-session/current-stage.md"
check_file "pgsql_learning_repo_prompt_pack/.learning-session/stage-history.md"
check_file "pgsql_learning_repo_prompt_pack/.learning-session/repo-memory.md"
check_file "pgsql_learning_repo_prompt_pack/.learning-session/decisions.md"
check_file "pgsql_learning_repo_prompt_pack/.learning-session/open-questions.md"
check_file "pgsql_learning_repo_prompt_pack/.learning-session/validation-log.md"
check_file "pgsql_learning_repo_prompt_pack/.learning-session/generated-files.md"
check_file "pgsql_learning_repo_prompt_pack/.learning-session/next-actions.md"
check_file "pgsql_learning_repo_prompt_pack/.learning-session/agent-handoff.md"
check_file "pgsql_learning_repo_prompt_pack/.learning-session/prompts-used.md"

echo
echo "=== Control files ==="
check_file "pgsql_learning_repo_prompt_pack/STAGES.md"
check_file "pgsql_learning_repo_prompt_pack/AGENT_BOOTSTRAP.md"
check_file "pgsql_learning_repo_prompt_pack/CURRENT_STAGE.md"
check_file "pgsql_learning_repo_prompt_pack/DONE_CRITERIA.md"
check_file "pgsql_learning_repo_prompt_pack/MASTER_SPEC.md"
check_file "pgsql_learning_repo_prompt_pack/TODO.md"
check_file "pgsql_learning_repo_prompt_pack/CHANGELOG.md"

echo
echo "=== Stage prompts (spot-check) ==="
check_file "pgsql_learning_repo_prompt_pack/STAGE_PROMPTS/stage-00-audit-safety-and-session-setup.md"
check_file "pgsql_learning_repo_prompt_pack/STAGE_PROMPTS/stage-01-foundation-skeleton.md"

echo
echo "=== Validation scripts ==="
check_file "scripts/stage-00/validate-env.sh"
check_file "scripts/stage-00/validate-extensions.sql"

echo
echo "=== Content checks ==="
CURRENT="$REPO_ROOT/pgsql_learning_repo_prompt_pack/.learning-session/current-stage.md"
if grep -q "^Stage:" "$CURRENT"; then
    pass "current-stage.md: Stage: field found (correctly formatted)"
else
    fail "current-stage.md: Stage: field missing — file may be malformed"
fi

if grep -q "completed" "$CURRENT"; then
    pass "current-stage.md: completed status found"
else
    fail "current-stage.md: no completed status — stage not marked done"
fi

HISTORY="$REPO_ROOT/pgsql_learning_repo_prompt_pack/.learning-session/stage-history.md"
if grep -q "Stage 0" "$HISTORY"; then
    pass "stage-history.md: Stage 0 entry found"
else
    fail "stage-history.md: Stage 0 entry missing"
fi

VALLOG="$REPO_ROOT/pgsql_learning_repo_prompt_pack/.learning-session/validation-log.md"
if grep -q "Stage 0" "$VALLOG"; then
    pass "validation-log.md: Stage 0 entry found"
else
    fail "validation-log.md: Stage 0 entry missing"
fi

echo
echo "=== Summary ==="
echo "PASS : $PASS"
echo "FAIL : $FAIL"

if [[ $FAIL -gt 0 ]]; then
    echo "RESULT: FAILED — fix FAIL items"
    exit 1
else
    echo "RESULT: ALL CHECKS PASSED"
    exit 0
fi
