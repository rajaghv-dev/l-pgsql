# Setup Validation — Practice 05

**Status: blocked — Docker not accessible in this session**

## Expected validation commands

```sql
-- blocked: Docker not accessible

-- 1. Check pageinspect is installed
SELECT extname FROM pg_extension WHERE extname = 'pageinspect';
-- Expected: 1 row

-- 2. Table row counts
SELECT 'mvcc_demo' AS tbl, COUNT(*) FROM mvcc_demo
UNION ALL
SELECT 'lock_demo', COUNT(*) FROM lock_demo
UNION ALL
SELECT 'job_queue', COUNT(*) FROM job_queue;
-- Expected: mvcc_demo=3, lock_demo=3, job_queue=8

-- 3. Confirm xmin/xmax columns are accessible
SELECT xmin, xmax, id, name FROM mvcc_demo;

-- 4. Confirm pageinspect works on mvcc_demo
SELECT lp, t_xmin, t_xmax, t_ctid
FROM heap_page_items(get_raw_page('mvcc_demo', 0))
LIMIT 5;
```

## When Docker is available
```bash
docker exec cfp_postgres psql -U cfp -d cfp -f /path/to/setup.sql
docker exec cfp_postgres psql -U cfp -d cfp -c \
  "SELECT xmin, xmax, id, name FROM mvcc_demo;"
```

## Expected xmin/xmax output
All rows should have non-zero xmin (the XID of the INSERT transaction) and xmax = 0 (not deleted or locked).
