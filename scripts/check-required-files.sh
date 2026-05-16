#!/usr/bin/env bash
# Check that all required files for a given stage exist in the repo.
# Run from repo root: bash scripts/check-required-files.sh --stage N

set -euo pipefail

PASS=0
FAIL=0
WARN=0

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }
warn() { echo "[WARN] $1"; WARN=$((WARN+1)); }

usage() {
    echo "Usage: bash scripts/check-required-files.sh --stage N"
    echo ""
    echo "  --stage N    Stage number to validate (0–29)"
    echo ""
    echo "Examples:"
    echo "  bash scripts/check-required-files.sh --stage 0"
    echo "  bash scripts/check-required-files.sh --stage 1"
    echo "  bash scripts/check-required-files.sh --stage 2"
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

# ── File lists per stage ──────────────────────────────────────────────────────

declare -a REQUIRED_FILES

case "$STAGE" in
    0)
        REQUIRED_FILES=(
            "scripts/stage-00/validate-env.sh"
            "scripts/stage-00/validate-session-files.sh"
            "scripts/stage-00/validate-extensions.sql"
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
            "pgsql_learning_repo_prompt_pack/STAGES.md"
            "pgsql_learning_repo_prompt_pack/AGENT_BOOTSTRAP.md"
            "pgsql_learning_repo_prompt_pack/CURRENT_STAGE.md"
            "pgsql_learning_repo_prompt_pack/DONE_CRITERIA.md"
            "pgsql_learning_repo_prompt_pack/MASTER_SPEC.md"
            "pgsql_learning_repo_prompt_pack/TODO.md"
            "pgsql_learning_repo_prompt_pack/CHANGELOG.md"
        )
        ;;
    1)
        REQUIRED_FILES=(
            "README.md"
            "learning-roadmap.md"
            "beginner-roadmap.md"
            "intermediate-roadmap.md"
            "advanced-roadmap.md"
            "AGENT_GUIDE.md"
            "CONTRIBUTING.md"
            "references.md"
            "extension-map.md"
            "capability-map.md"
            "concepts/beginner/README.md"
            "concepts/intermediate/README.md"
            "concepts/advanced/README.md"
            "practice/beginner/README.md"
            "practice/intermediate/README.md"
            "practice/advanced/README.md"
            "examples/beginner/README.md"
            "examples/intermediate/README.md"
            "examples/advanced/README.md"
            "diagrams/README.md"
            "ontology/README.md"
            "extensions/README.md"
            "design-principles/README.md"
            "reflections/README.md"
            "tools/templates/README.md"
        )
        ;;
    2)
        REQUIRED_FILES=(
            "tools/templates/lesson-template.md"
            "tools/templates/practice-template.md"
            "tools/templates/example-template.md"
            "tools/templates/ontology-template.md"
            "tools/templates/reference-template.md"
            "tools/templates/design-principle-template.md"
            "tools/templates/stage-report-template.md"
            "tools/templates/extension-lesson-template.md"
            "tools/templates/beginner-lesson-template.md"
            "tools/templates/intermediate-lesson-template.md"
            "tools/templates/advanced-lesson-template.md"
            "scripts/check-required-files.sh"
            "scripts/validate-stage.sh"
            "scripts/validate-practice-structure.sh"
            "scripts/validate-sql-files.sh"
            "scripts/validate-extension-availability.sql"
            "scripts/run-example.sh"
        )
        ;;
    3)
        REQUIRED_FILES=(
            "concepts/beginner/00-what-is-a-database.md"
            "concepts/beginner/01-what-is-postgresql.md"
            "concepts/beginner/02-sql-as-a-language-of-questions.md"
            "practice/beginner/00-environment-setup/README.md"
            "practice/beginner/00-environment-setup/setup.sql"
            "practice/beginner/00-environment-setup/exercises.md"
            "practice/beginner/00-environment-setup/solutions.md"
            "practice/beginner/00-environment-setup/reflection.md"
            "practice/beginner/00-environment-setup/ontology-notes.md"
            "practice/beginner/00-environment-setup/troubleshooting.md"
            "practice/beginner/00-environment-setup/references.md"
            "practice/beginner/01-basic-sql/README.md"
            "practice/beginner/01-basic-sql/setup.sql"
            "practice/beginner/01-basic-sql/exercises.md"
            "practice/beginner/01-basic-sql/solutions.md"
            "practice/beginner/01-basic-sql/reflection.md"
            "practice/beginner/01-basic-sql/ontology-notes.md"
            "practice/beginner/01-basic-sql/troubleshooting.md"
            "practice/beginner/01-basic-sql/references.md"
        )
        ;;
    4)
        REQUIRED_FILES=(
            "concepts/beginner/03-database-schema-table-row-column.md"
            "concepts/beginner/04-data-types-and-values.md"
            "concepts/beginner/05-primary-keys-and-identity.md"
            "concepts/beginner/06-foreign-keys-and-relationships.md"
            "concepts/beginner/07-constraints-as-rules.md"
            "practice/beginner/02-schema-and-table-basics/README.md"
            "practice/beginner/02-schema-and-table-basics/setup.sql"
            "practice/beginner/02-schema-and-table-basics/exercises.md"
            "practice/beginner/02-schema-and-table-basics/solutions.md"
            "practice/beginner/03-keys-and-constraints/README.md"
            "practice/beginner/03-keys-and-constraints/setup.sql"
            "practice/beginner/03-keys-and-constraints/exercises.md"
            "practice/beginner/03-keys-and-constraints/solutions.md"
        )
        ;;
    5)
        REQUIRED_FILES=(
            "concepts/beginner/08-select-filter-sort-limit.md"
            "concepts/beginner/09-insert-update-delete.md"
            "concepts/beginner/10-joins-intuition.md"
            "concepts/beginner/11-aggregation-intuition.md"
            "concepts/beginner/12-indexes-as-shortcuts.md"
            "concepts/beginner/13-transactions-as-safe-change.md"
            "practice/beginner/04-joins-and-aggregation/README.md"
            "practice/beginner/04-joins-and-aggregation/setup.sql"
            "practice/beginner/05-simple-indexes/README.md"
            "practice/beginner/05-simple-indexes/setup.sql"
            "practice/beginner/06-simple-transactions/README.md"
            "practice/beginner/06-simple-transactions/setup.sql"
        )
        ;;
    6)
        REQUIRED_FILES=(
            "concepts/beginner/14-jsonb-as-flexible-data.md"
            "concepts/beginner/15-views-as-saved-questions.md"
            "concepts/beginner/16-roles-and-permissions.md"
            "concepts/beginner/17-extensions-as-capability-addons.md"
            "concepts/beginner/18-full-text-search-intuition.md"
            "concepts/beginner/19-vector-search-intuition.md"
            "concepts/beginner/20-ontology-for-database-learning.md"
            "practice/beginner/07-jsonb-basics/README.md"
            "practice/beginner/07-jsonb-basics/setup.sql"
            "practice/beginner/08-views-and-functions-basics/README.md"
            "practice/beginner/08-views-and-functions-basics/setup.sql"
            "practice/beginner/09-roles-basics/README.md"
            "practice/beginner/09-roles-basics/setup.sql"
        )
        ;;
    7)
        REQUIRED_FILES=(
            "concepts/intermediate/00-schema-design-tradeoffs.md"
            "concepts/intermediate/01-normalization-and-denormalization.md"
            "concepts/intermediate/02-constraints-as-business-invariants.md"
            "concepts/intermediate/03-join-design-and-cardinality.md"
            "practice/intermediate/00-schema-design/README.md"
            "practice/intermediate/00-schema-design/setup.sql"
            "practice/intermediate/01-constraint-driven-design/README.md"
            "practice/intermediate/01-constraint-driven-design/setup.sql"
        )
        ;;
    8)
        REQUIRED_FILES=(
            "concepts/intermediate/04-index-selection.md"
            "concepts/intermediate/05-composite-partial-expression-indexes.md"
            "concepts/intermediate/06-query-planning-with-explain.md"
            "practice/intermediate/02-indexing-strategies/README.md"
            "practice/intermediate/02-indexing-strategies/setup.sql"
            "practice/intermediate/03-query-planning/README.md"
            "practice/intermediate/03-query-planning/setup.sql"
        )
        ;;
    9)
        REQUIRED_FILES=(
            "concepts/intermediate/07-transactions-and-isolation.md"
            "concepts/intermediate/08-mvcc-and-snapshot-thinking.md"
            "concepts/intermediate/09-locks-and-concurrency.md"
            "practice/intermediate/04-transactions-and-isolation/README.md"
            "practice/intermediate/04-transactions-and-isolation/setup.sql"
            "practice/intermediate/05-mvcc-and-locking/README.md"
            "practice/intermediate/05-mvcc-and-locking/setup.sql"
        )
        ;;
    10)
        REQUIRED_FILES=(
            "concepts/intermediate/10-jsonb-modeling-tradeoffs.md"
            "concepts/intermediate/11-full-text-search-design.md"
            "concepts/intermediate/12-fuzzy-search-with-pg-trgm.md"
            "concepts/intermediate/13-hierarchical-data-with-ltree-and-recursive-cte.md"
            "concepts/intermediate/14-geospatial-intro-with-postgis.md"
            "concepts/intermediate/15-vector-search-with-pgvector.md"
            "practice/intermediate/06-jsonb-modeling/README.md"
            "practice/intermediate/07-full-text-and-fuzzy-search/README.md"
            "practice/intermediate/08-geospatial-intro/README.md"
            "practice/intermediate/09-pgvector-retrieval/README.md"
        )
        ;;
    11)
        REQUIRED_FILES=(
            "concepts/intermediate/16-materialized-views-and-refresh-patterns.md"
            "concepts/intermediate/17-functions-triggers-and-audit-patterns.md"
            "concepts/intermediate/18-row-level-security-and-tenant-isolation.md"
            "concepts/intermediate/19-observability-with-pg-stat-statements.md"
            "concepts/intermediate/20-migrations-and-schema-evolution.md"
            "concepts/intermediate/21-ontology-driven-schema-design.md"
            "practice/intermediate/10-rls-and-multi-tenancy/README.md"
            "practice/intermediate/11-audit-triggers/README.md"
            "practice/intermediate/12-observability/README.md"
            "practice/intermediate/13-ontology-modeling/README.md"
        )
        ;;
    12)
        REQUIRED_FILES=(
            "extensions/README.md"
            "extensions/vector/pgvector.md"
            "extensions/search/pg-trgm.md"
            "extensions/geospatial/postgis.md"
            "extensions/security/pgcrypto.md"
            "extensions/observability/pg-stat-statements.md"
            "extensions/data-types/ltree.md"
            "extensions/foreign-data/postgres-fdw.md"
            "extensions/data-types/hstore.md"
        )
        ;;
    13)
        REQUIRED_FILES=(
            "ontology/README.md"
            "ontology/postgres-concept-map.md"
            "ontology/sql-ontology.md"
            "ontology/extension-ontology.md"
            "ontology/entity-relationship-ontology.md"
            "ontology/query-ontology.md"
            "ontology/transaction-ontology.md"
            "ontology/index-ontology.md"
            "ontology/schema-design-ontology.md"
        )
        ;;
    14)
        REQUIRED_FILES=(
            "ontology/performance-ontology.md"
            "ontology/security-ontology.md"
            "ontology/observability-ontology.md"
            "ontology/vector-search-ontology.md"
            "ontology/geospatial-ontology.md"
            "ontology/time-series-ontology.md"
            "ontology/ai-agent-memory-ontology.md"
            "ontology/domain-ontology-examples.md"
        )
        ;;
    15)
        REQUIRED_FILES=(
            "examples/beginner/personal-notes/README.md"
            "examples/beginner/simple-store/README.md"
            "examples/beginner/library-catalog/README.md"
            "examples/beginner/todo-app/README.md"
        )
        ;;
    16)
        REQUIRED_FILES=(
            "examples/intermediate/ecommerce/README.md"
            "examples/intermediate/observability/README.md"
            "examples/intermediate/compliance-audit/README.md"
            "examples/intermediate/ai-agent-memory/README.md"
            "examples/intermediate/multi-tenant-saas/README.md"
            "examples/intermediate/geospatial-store-locator/README.md"
            "examples/intermediate/document-search/README.md"
        )
        ;;
    17)
        REQUIRED_FILES=(
            "examples/advanced/hybrid-search-system/README.md"
            "examples/advanced/finance-ledger/README.md"
            "examples/advanced/support-ticketing/README.md"
            "examples/advanced/event-sourcing-audit/README.md"
            "examples/advanced/time-series-monitoring/README.md"
            "examples/advanced/rls-saas-platform/README.md"
            "examples/advanced/ai-agent-memory-platform/README.md"
        )
        ;;
    18)
        REQUIRED_FILES=(
            "concepts/advanced/00-postgresql-as-a-system.md"
            "concepts/advanced/01-planner-executor-and-cost-model.md"
            "concepts/advanced/02-cardinality-selectivity-and-statistics.md"
            "concepts/advanced/03-advanced-indexing-gin-gist-brin-spgist.md"
            "concepts/advanced/04-index-maintenance-and-write-amplification.md"
            "concepts/advanced/05-vacuum-autovacuum-and-bloat.md"
            "concepts/advanced/06-buffer-cache-and-io-thinking.md"
            "concepts/advanced/07-lock-contention-deadlocks-and-serializable.md"
        )
        ;;
    19)
        REQUIRED_FILES=(
            "concepts/advanced/08-partitioning-for-large-data.md"
            "concepts/advanced/09-logical-replication-and-change-data-capture.md"
            "concepts/advanced/10-time-series-architecture.md"
            "concepts/advanced/11-advanced-jsonb-performance.md"
            "concepts/advanced/12-advanced-full-text-and-hybrid-search.md"
            "concepts/advanced/13-advanced-pgvector-indexing-and-hybrid-retrieval.md"
            "concepts/advanced/14-postgis-advanced-systems-thinking.md"
            "concepts/advanced/15-foreign-data-wrapper-architecture.md"
        )
        ;;
    20)
        REQUIRED_FILES=(
            "concepts/advanced/16-extension-selection-and-risk-model.md"
            "concepts/advanced/17-security-hardening-and-auditability.md"
            "concepts/advanced/18-rls-at-scale.md"
            "concepts/advanced/19-observability-debugging-and-performance-forensics.md"
            "concepts/advanced/20-online-migrations-and-reliability.md"
            "concepts/advanced/21-backup-restore-and-disaster-recovery-thinking.md"
            "concepts/advanced/22-ai-agent-memory-architecture.md"
            "concepts/advanced/23-postgresql-vs-specialized-systems.md"
            "concepts/advanced/24-when-not-to-use-postgresql.md"
        )
        ;;
    21)
        REQUIRED_FILES=(
            "diagrams/README.md"
            "diagrams/postgres-mental-model.md"
            "diagrams/sql-vs-non-sql-capability-map.md"
            "diagrams/extension-ecosystem-map.md"
            "diagrams/application-to-database-flow.md"
            "diagrams/sql-query-lifecycle.md"
            "diagrams/transaction-mvcc-flow.md"
            "diagrams/index-selection-flow.md"
            "diagrams/vector-search-flow.md"
            "diagrams/hybrid-search-flow.md"
            "diagrams/agent-safety-model.md"
        )
        ;;
    22)
        REQUIRED_FILES=(
            "design-principles/README.md"
            "design-principles/beginner-design-principles.md"
            "design-principles/intermediate-design-principles.md"
            "design-principles/advanced-design-principles.md"
            "design-principles/schema-design-principles.md"
            "design-principles/query-design-principles.md"
            "design-principles/indexing-design-principles.md"
            "design-principles/transaction-design-principles.md"
            "design-principles/concurrency-design-principles.md"
            "design-principles/security-design-principles.md"
            "design-principles/mcp-tool-design-principles.md"
        )
        ;;
    23)
        REQUIRED_FILES=(
            "reflections/README.md"
            "reflections/beginner-thinking-prompts.md"
            "reflections/intermediate-thinking-prompts.md"
            "reflections/advanced-thinking-prompts.md"
            "reflections/first-principles-questions.md"
            "reflections/critical-thinking-prompts.md"
            "reflections/creative-thinking-prompts.md"
            "reflections/systems-thinking-prompts.md"
            "reflections/ontology-thinking-prompts.md"
            "reflections/extension-thinking-prompts.md"
        )
        ;;
    24)
        REQUIRED_FILES=(
            "references.md"
            "concepts/beginner/references.md"
            "concepts/intermediate/references.md"
            "concepts/advanced/references.md"
        )
        ;;
    25)
        REQUIRED_FILES=()
        warn "Stage 25 has no required files defined in the spec — skipping file checks"
        ;;
    26)
        REQUIRED_FILES=(
            "concepts/intermediate/22-postgresql-for-mcp-tools.md"
            "concepts/intermediate/23-agent-safe-database-actions.md"
            "concepts/intermediate/24-agent-memory-and-audit-trails.md"
            "practice/intermediate/14-mcp-tool-database-design/README.md"
            "practice/intermediate/14-mcp-tool-database-design/setup.sql"
            "practice/intermediate/15-agent-safe-actions/README.md"
            "practice/intermediate/15-agent-safe-actions/setup.sql"
            "ontology/agent-workflow-ontology.md"
            "ontology/mcp-tool-ontology.md"
        )
        ;;
    27)
        REQUIRED_FILES=(
            "examples/intermediate/legal-case-notes-agent/README.md"
            "examples/intermediate/finance-invoice-approval-agent/README.md"
            "examples/intermediate/medical-record-retrieval-agent/README.md"
            "examples/intermediate/pharma-quality-check-agent/README.md"
            "examples/intermediate/office-team-task-agent/README.md"
            "examples/intermediate/compliance-evidence-agent/README.md"
        )
        ;;
    28)
        REQUIRED_FILES=(
            "concepts/advanced/25-agent-permission-boundaries-with-rls.md"
            "concepts/advanced/26-human-in-the-loop-database-workflows.md"
            "concepts/advanced/27-agent-auditability-and-evidence-logs.md"
            "concepts/advanced/28-safe-agent-transactions-and-rollbacks.md"
            "ontology/agent-permission-ontology.md"
            "ontology/human-approval-ontology.md"
            "design-principles/agent-memory-design-principles.md"
            "design-principles/agent-permission-design-principles.md"
            "design-principles/human-in-the-loop-design-principles.md"
        )
        ;;
    29)
        REQUIRED_FILES=(
            "reflections/mcp-agent-thinking-prompts.md"
            "reflections/agent-safety-thinking-prompts.md"
            "reflections/human-approval-thinking-prompts.md"
        )
        ;;
    *)
        echo "Error: unknown stage '$STAGE'. Supported stages: 0–29"
        exit 1
        ;;
esac

# ── Check each file ───────────────────────────────────────────────────────────

echo "=== Required files for Stage $STAGE ==="
echo ""

for f in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$REPO_ROOT/$f" ]]; then
        pass "$f"
    else
        fail "$f"
    fi
done

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "=== Summary ==="
echo "PASS : $PASS"
echo "WARN : $WARN"
echo "FAIL : $FAIL"

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "RESULT: MISSING FILES — create the FAIL items above before marking Stage $STAGE complete"
    exit 1
else
    echo ""
    echo "RESULT: ALL REQUIRED FILES PRESENT — Stage $STAGE file check passed"
    exit 0
fi
