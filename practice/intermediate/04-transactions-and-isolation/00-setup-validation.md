# Setup Validation — Practice 04

**Status: blocked — Docker not accessible in this session**

## Expected validation commands

Run these after `setup.sql` to confirm the schema is correct.

```sql
-- blocked: Docker not accessible
-- docker exec cfp_postgres psql -U cfp -d cfp -c "..."

-- 1. Table counts
SELECT 'bank_accounts' AS tbl, COUNT(*) FROM bank_accounts
UNION ALL
SELECT 'transfers', COUNT(*) FROM transfers;
-- Expected: bank_accounts=5, transfers=1

-- 2. Balance check — no negative balances
SELECT COUNT(*) FROM bank_accounts WHERE balance < 0;
-- Expected: 0

-- 3. Confirm indexes exist
SELECT indexname, tablename
FROM pg_indexes
WHERE tablename IN ('bank_accounts', 'transfers')
ORDER BY tablename, indexname;
-- Expected: indexes on transfers(from_id), transfers(to_id), transfers(created_at)
```

## When Docker is available
```bash
docker exec cfp_postgres psql -U cfp -d cfp -f /path/to/setup.sql
docker exec cfp_postgres psql -U cfp -d cfp -c \
  "SELECT owner, balance FROM bank_accounts ORDER BY id;"
```

## Expected output
| owner   | balance |
|---------|---------|
| Alice   | 1000.00 |
| Bob     | 500.00  |
| Charlie | 2500.00 |
| Diana   | 750.00  |
| Eve     | 0.00    |
