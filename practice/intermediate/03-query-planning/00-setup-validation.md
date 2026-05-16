# Setup Validation — Query Planning

> **Validation status**: blocked — Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled.

## pg_stat_statements check

```sql
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_statements';
-- Expected: pg_stat_statements | <version>
```

If not present, add to `postgresql.conf`:
```
shared_preload_libraries = 'pg_stat_statements'
```
Then restart PostgreSQL and run `CREATE EXTENSION pg_stat_statements;`.

## Table row counts

```sql
SELECT 'customers'   AS tbl, COUNT(*) FROM customers
UNION ALL
SELECT 'products',          COUNT(*) FROM products
UNION ALL
SELECT 'orders',            COUNT(*) FROM orders
UNION ALL
SELECT 'order_items',       COUNT(*) FROM order_items
UNION ALL
SELECT 'idx_events',        COUNT(*) FROM idx_events;
-- Expected: ~500, ~200, ~2000, ~6000-8000, 100000
```

## Index state — no extra indexes (fresh start)

```sql
SELECT tablename, indexname
FROM pg_indexes
WHERE tablename IN ('customers','products','orders','order_items')
  AND indexname NOT LIKE '%_pkey'
  AND indexname NOT LIKE '%_key'
  AND indexname NOT LIKE '%_unique%'
ORDER BY tablename, indexname;
-- Expected: 0 rows (no manual indexes, only PK and UNIQUE constraint indexes)
```

## Confirm EXPLAIN works

```sql
EXPLAIN SELECT * FROM orders WHERE customer_id = 1;
-- Expected: Seq Scan on orders (no index on customer_id yet)
```

## Confirm pg_stat_user_tables is accessible

```sql
SELECT relname, seq_scan, idx_scan, n_live_tup
FROM pg_stat_user_tables
WHERE relname IN ('orders', 'customers', 'products', 'order_items')
ORDER BY relname;
```
