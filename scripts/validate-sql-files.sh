#!/usr/bin/env bash
# List all .sql files in scripts/ and examples/ and verify each is non-empty.
# Does NOT execute any SQL — purely a file structure check.
#
# Run from repo root: bash scripts/validate-sql-files.sh

set -euo pipefail

PASS=0
FAIL=0
WARN=0

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }
warn() { echo "[WARN] $1"; WARN=$((WARN+1)); }

usage() {
    echo "Usage: bash scripts/validate-sql-files.sh"
    echo ""
    echo "Scans scripts/ and examples/ for .sql files."
    echo "Checks each file is non-empty (contains at least one line)."
    echo "Does NOT execute any SQL."
    exit 1
}

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
fi

# ── Scan for .sql files ───────────────────────────────────────────────────────

echo "=== SQL file structure check ==="
echo ""

SCAN_DIRS=("$REPO_ROOT/scripts" "$REPO_ROOT/examples")
FOUND=0

for scan_dir in "${SCAN_DIRS[@]}"; do
    if [[ ! -d "$scan_dir" ]]; then
        warn "directory not found, skipping: ${scan_dir#"$REPO_ROOT/"}"
        continue
    fi

    while IFS= read -r -d '' sql_file; do
        FOUND=$((FOUND+1))
        rel_path="${sql_file#"$REPO_ROOT/"}"
        line_count=$(wc -l < "$sql_file" 2>/dev/null || echo 0)

        if [[ ! -s "$sql_file" ]]; then
            fail "$rel_path (EMPTY — 0 bytes)"
        else
            # Check for at least one non-blank, non-comment line
            # (a line that is not empty and not starting with --)
            sql_lines=$(grep -c '[^[:space:]]' "$sql_file" 2>/dev/null || echo 0)
            if [[ $sql_lines -eq 0 ]]; then
                fail "$rel_path (no non-blank content)"
            else
                pass "$rel_path ($line_count lines)"
            fi
        fi
    done < <(find "$scan_dir" -name "*.sql" -type f -print0 | sort -z)
done

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "=== Summary ==="
echo "Files scanned : $FOUND"
echo "PASS          : $PASS"
echo "WARN          : $WARN"
echo "FAIL          : $FAIL"

if [[ $FOUND -eq 0 ]]; then
    warn "No .sql files found in scripts/ or examples/"
    echo ""
    echo "RESULT: NOTHING TO CHECK — no .sql files found"
    exit 0
elif [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "RESULT: FAILED — fix empty or blank SQL files listed above"
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo ""
    echo "RESULT: PASSED WITH WARNINGS — review WARN items"
    exit 0
else
    echo ""
    echo "RESULT: ALL SQL FILES ARE NON-EMPTY"
    exit 0
fi
