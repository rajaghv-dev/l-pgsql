# Solutions — Indexing Strategies

> validation: blocked — Docker not accessible; re-validate against cfp_postgres when Docker Desktop WSL integration is enabled
> Expected EXPLAIN output shown as representative examples; actual numbers will vary by run.

---

## Exercise 1: Baseline seq scan

**Expected plan for all 4 queries**: `Seq Scan on idx_events`

**a)** All four use Seq Scan — no indexes exist except the PK (PK is not useful for these filters).

**b)** Q3 (status = 'failed'): approximately 2,000 failed rows (~2% of 100k). Estimate should be close if ANALYZE was run after data load.

**c)** Q1 buffers: `shared hit` or `shared read` will be proportional to the number of pages in the table (~100k rows × ~100 bytes average ≈ 10MB → ~1250 8KB pages). Expect `Buffers: shared hit=1000–1300` on a warm cache.

---

## Exercise 2: B-tree on email

**Expected plan**: `Index Scan using idx_events_email_idx on idx_events`

**a)** Index Scan or Bitmap Index Scan (depends on row count returned — ~100 rows per email).

**b)** Buffers before: full table scan (~1250 pages). After index: ~3–5 pages (index pages + heap pages for ~100 rows).

**c)** Index size: approximately 3–5 MB for a text column with 100k rows.

**d)** Email index does NOT help Q2 (timestamp filter). The index is organized by `user_email`, not `occurred_at`. The planner correctly ignores it.

---

## Exercise 3: BRIN on occurred_at

**a)** BRIN index should be used for Q2 if the data is physically ordered by time (which it is — `generate_series` inserts in order). Expected plan:
```
Bitmap Heap Scan on idx_events
  ->  Bitmap Index Scan on idx_events_time_brin
```

**b)** BRIN is dramatically smaller:
- BRIN: ~24–48 KB (stores one entry per block range, default 128 blocks)
- B-tree: ~2–4 MB (one entry per row)

**c)** BRIN is appropriate for: large append-only or time-ordered tables (logs, events, IoT sensor data). If rows were inserted out of order, BRIN would provide no benefit — each block would contain a wide min/max range, making the index useless for selective range queries.

---

## Exercise 4: GIN on JSONB payload

**a)** Expected plan after GIN index:
```
Bitmap Heap Scan on idx_events
  ->  Bitmap Index Scan on idx_events_payload_gin
        Index Cond: (payload @> '{"currency": "USD"}'::jsonb)
```

**b)** GIN index for JSONB on 100k rows: typically 5–15 MB (larger than B-tree due to inverted structure). The GIN index stores one entry per distinct JSON key-value pair across all documents.

**c)** `payload @> '{"element": "btn-5"}'` — YES, uses GIN (containment operator `@>` is supported by GIN).

**d)** `payload->>'element' = 'btn-5'` — NO, does NOT use the GIN index. This is an extraction operator (`->>`), not a containment operator. To index this, create an expression index:
```sql
CREATE INDEX ON idx_events ((payload->>'element'));
```

---

## Exercise 5: Partial index for pending/failed

**a)** YES — the partial index is used when the WHERE clause matches the index condition:
```
Index Scan using idx_events_pending_failed_idx on idx_events
  Index Cond: (occurred_at < now())
  Filter: (status = ANY ('{pending,failed}'))
```

**b)** Partial index size: approximately 200–400 KB (only ~10,000 rows indexed vs. 100,000 in the full B-tree).

**c)** Without the `status` filter: the partial index is NOT used (the query might return rows where status = 'processed' or 'click', which are not in the index). PostgreSQL correctly uses the full B-tree or seq scan.

**d)** The partial index is smaller because it excludes all rows where `status = 'processed'` (~90% of rows). Only ~10,000 rows (pending + failed) are indexed.

---

## Exercise 6: Expression index

**a)** `WHERE LOWER(user_email) = 'user_42@example.com'` uses `idx_events_lower_email`.

**b)** `WHERE user_email = 'user_42@example.com'` uses `idx_events_email_idx` (the raw column index).

**c)** If emails are always stored lowercase, the expression index is redundant — the raw index already handles exact matches efficiently. The expression index is essential when:
- The stored column has mixed case (e.g., `Alice@Example.com`)
- Queries use `LOWER()` for case-insensitive comparison
- ILIKE is too slow (ILIKE cannot use a regular B-tree index)

---

## Exercise 7: Covering index with INCLUDE

**a)** Expected plan: `Index Only Scan using idx_events_email_covering on idx_events` — IF the visibility map is up-to-date. After `VACUUM idx_events;` this should reliably appear.

**b)** `Heap Fetches: 0` means no heap reads were needed — all required columns (event_type, occurred_at) were found in the index itself.

**c)** Without the covering index, the plan reverts to `Index Scan` (uses `idx_events_email_idx` but must fetch heap pages for `event_type` and `occurred_at`). Buffers count increases.

**d)** INCLUDE is worth it when:
- A query is run very frequently (high scan rate)
- The table is large and heap fetches are expensive
- The INCLUDE columns are narrow (add minimal index size)
- NOT worth it if: the INCLUDE columns are wide (text, JSONB), or the query is infrequent

---

## Exercise 8: Index usage statistics

**a)** The most-scanned index will be whichever was used in the most queries during your session — likely `idx_events_email_idx` or `idx_events_email_covering`.

**b)** Indexes with `idx_scan = 0` after this exercise set: likely `idx_events_time_brin` and `idx_events_lower_email` (if no LOWER() queries were run) and `idx_events_time_btree` (if the BRIN was preferred).

**c)** Size comparison (approximate):
```
table_heap:  ~10 MB  (100k rows × ~100 bytes)
all_indexes: ~25 MB  (5–6 indexes total)
table_total: ~35 MB
```
This shows that indexes can be 2–3× the table size — a real write overhead at scale.

**d)** Candidates to drop in production:
- `idx_events_time_btree` if `idx_events_time_brin` serves the timestamp range queries adequately
- `idx_events_lower_email` if emails are always stored lowercase
- Any index with `idx_scan = 0` after a representative production workload period
