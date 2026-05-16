#!/usr/bin/env bash
# Run file checks for all stages 0-29 and summarize.
# Usage: bash scripts/validate-all-stages.sh
# Does NOT validate SQL (requires Docker). Only checks file existence.

set -euo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

for stage in $(seq 0 29); do
    output=$(bash "$REPO_ROOT/scripts/check-required-files.sh" --stage "$stage" 2>&1) || true
    if echo "$output" | grep -q "RESULT: ALL REQUIRED FILES PRESENT"; then
        echo "[PASS] Stage $stage"
        PASS=$((PASS+1))
    elif echo "$output" | grep -q "not recognized"; then
        echo "[SKIP] Stage $stage — not yet in check-required-files.sh"
    else
        echo "[FAIL] Stage $stage"
        echo "$output" | grep "FAIL" | head -5
        FAIL=$((FAIL+1))
    fi
done

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
