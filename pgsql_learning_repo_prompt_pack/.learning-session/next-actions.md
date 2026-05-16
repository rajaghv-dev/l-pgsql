# Next Actions

## Immediate (requires Docker)

1. Enable Docker Desktop WSL2 integration in Docker Desktop settings
2. Run: `bash scripts/stage-00/validate-env.sh`
3. Run: `bash scripts/validate-stage.sh --stage N` for each stage (3–29) to validate SQL
4. Enable pg_stat_statements: `bash scripts/dashboards/enable-pg-stat-statements.sh`
5. Check RedisInsight: manually add cfp_redis host on first open

## Content follow-up

6. Review practice session SQL in each folder — mark as "validated" once tested
7. Add 00-setup-validation.md result notes once Docker is accessible
8. Extend check-required-files.sh to include all stage 3–29 files (partial — in progress)

## Optional enhancements

9. Pull an Ollama model: `docker exec cfp_ollama ollama pull llama3.2:3b`
10. Test pgvector examples against cfp_postgres
11. Pin open-webui Docker image from :main to a versioned tag

## Not needed

- Do not regenerate any content — all stages 0–29 are complete
- Do not modify lesson structure — follow MASTER_SPEC for any future additions
