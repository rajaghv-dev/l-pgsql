#!/usr/bin/env bash
# Validate that a practice session folder contains all required files.
# Run from repo root: bash scripts/validate-practice-structure.sh <path>
#
# Can also validate an entire level at once:
#   bash scripts/validate-practice-structure.sh --all-beginner
#   bash scripts/validate-practice-structure.sh --all-intermediate
#   bash scripts/validate-practice-structure.sh --all-advanced

set -euo pipefail

PASS=0
FAIL=0
WARN=0

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }
warn() { echo "[WARN] $1"; WARN=$((WARN+1)); }

usage() {
    echo "Usage: bash scripts/validate-practice-structure.sh <practice-folder>"
    echo "       bash scripts/validate-practice-structure.sh --all-beginner"
    echo "       bash scripts/validate-practice-structure.sh --all-intermediate"
    echo "       bash scripts/validate-practice-structure.sh --all-advanced"
    echo ""
    echo "Arguments:"
    echo "  <practice-folder>   Path to a single practice session (e.g. practice/beginner/01-basic-sql)"
    echo "  --all-beginner      Validate all subfolders in practice/beginner/"
    echo "  --all-intermediate  Validate all subfolders in practice/intermediate/"
    echo "  --all-advanced      Validate all subfolders in practice/advanced/"
    echo ""
    echo "Required files per session:"
    echo "  README.md, setup.sql, 00-setup-validation.md, exercises.md,"
    echo "  solutions.md, reflection.md, ontology-notes.md, troubleshooting.md, references.md"
    exit 1
}

# ── Required files for a practice session ────────────────────────────────────

REQUIRED_PRACTICE_FILES=(
    "README.md"
    "setup.sql"
    "00-setup-validation.md"
    "exercises.md"
    "solutions.md"
    "reflection.md"
    "ontology-notes.md"
    "troubleshooting.md"
    "references.md"
)

# ── Validate a single practice folder ────────────────────────────────────────

validate_folder() {
    local folder="$1"
    local abs_folder="$REPO_ROOT/$folder"

    echo ""
    echo "=== Validating: $folder ==="

    if [[ ! -d "$abs_folder" ]]; then
        fail "folder does not exist: $folder"
        return
    fi

    for f in "${REQUIRED_PRACTICE_FILES[@]}"; do
        if [[ -f "$abs_folder/$f" ]]; then
            pass "$f"
        else
            fail "$f"
        fi
    done
}

# ── Validate all sessions in a level ─────────────────────────────────────────

validate_level() {
    local level="$1"   # beginner, intermediate, or advanced
    local level_dir="$REPO_ROOT/practice/$level"

    echo "=== Validating all $level practice sessions ==="

    if [[ ! -d "$level_dir" ]]; then
        warn "practice/$level/ does not exist — no sessions to validate"
        return
    fi

    local session_count=0
    local session_fail=0

    # Find immediate subdirectories (each is a practice session)
    while IFS= read -r -d '' session_dir; do
        local session_name
        session_name="practice/$level/$(basename "$session_dir")"

        local before_fail=$FAIL
        validate_folder "$session_name"
        if [[ $FAIL -gt $before_fail ]]; then
            session_fail=$((session_fail+1))
        fi
        session_count=$((session_count+1))
    done < <(find "$level_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

    if [[ $session_count -eq 0 ]]; then
        warn "No session subfolders found in practice/$level/ — nothing validated"
    fi
}

# ── Argument parsing ──────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
    usage
fi

MODE="single"
TARGET=""

case "$1" in
    --all-beginner)
        MODE="level"
        TARGET="beginner"
        ;;
    --all-intermediate)
        MODE="level"
        TARGET="intermediate"
        ;;
    --all-advanced)
        MODE="level"
        TARGET="advanced"
        ;;
    -h|--help)
        usage
        ;;
    --*)
        echo "Unknown flag: $1"
        usage
        ;;
    *)
        MODE="single"
        TARGET="$1"
        ;;
esac

# ── Run validation ────────────────────────────────────────────────────────────

if [[ "$MODE" == "level" ]]; then
    validate_level "$TARGET"
else
    validate_folder "$TARGET"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "=== Summary ==="
echo "PASS : $PASS"
echo "WARN : $WARN"
echo "FAIL : $FAIL"

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "RESULT: VALIDATION FAILED — add missing files listed above"
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo ""
    echo "RESULT: PASSED WITH WARNINGS — review WARN items"
    exit 0
else
    echo ""
    echo "RESULT: ALL CHECKS PASSED"
    exit 0
fi
