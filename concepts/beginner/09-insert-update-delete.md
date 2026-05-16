# INSERT, UPDATE, DELETE

Level: Beginner

## One-line intuition

INSERT adds rows, UPDATE changes rows, DELETE removes rows — the three write operations that mutate table data.

## Why this exists

SELECT reads data. To build anything useful you also need to create, change, and remove data. These three statements cover every mutation a row can experience.

## First-principles explanation

A relational table is a set of tuples. Mutations change that set:

- **INSERT** adds a new tuple to the set.
- **UPDATE** replaces field values in existing tuples (the row identity, its primary key, stays the same).
- **DELETE** removes tuples from the set entirely.

All three can be wrapped in a transaction (BEGIN/COMMIT) to make them atomic. All three can violate constraints (NOT NULL, UNIQUE, FK) — PostgreSQL will reject them with an error rather than silently corrupt data.

## Micro-concepts

| Statement | Core syntax | Key option |
|-----------|------------|------------|
| `INSERT INTO t (cols) VALUES (vals)` | Add one row | `RETURNING col` |
| `INSERT INTO t ... SELECT ...` | Bulk insert from query | `ON CONFLICT DO NOTHING` / `DO UPDATE` |
| `UPDATE t SET col = val WHERE cond` | Change matching rows | `RETURNING col` |
| `DELETE FROM t WHERE cond` | Remove matching rows | `RETURNING col` |
| `TRUNCATE t` | Remove ALL rows fast | `RESTART IDENTITY CASCADE` |

## Beginner view

Think of the library catalog:

- **INSERT** = add a new index card for a new book.
- **UPDATE** = correct the author name on an existing card.
- **DELETE** = pull a card out and throw it away.
- **TRUNCATE** = dump the entire drawer and start over.

```sql
-- Add a book
INSERT INTO books (title, author, genre, published_year)
VALUES ('Dune', 'Frank Herbert', 'Science Fiction', 1965);

-- Fix a typo
UPDATE books
SET author = 'Frank Herbert'
WHERE title = 'Dune';

-- Remove a withdrawn book
DELETE FROM books
WHERE isbn = '978-0441013593';
```

## Intermediate view

**RETURNING** turns any write into a write + read in one round-trip:

```sql
INSERT INTO books (title, author)
VALUES ('Foundation', 'Isaac Asimov')
RETURNING id, title;
```

**Upsert** (INSERT ... ON CONFLICT) merges insert and update:

```sql
INSERT INTO books (isbn, title)
VALUES ('978-0441013593', 'Dune')
ON CONFLICT (isbn) DO UPDATE
  SET title = EXCLUDED.title;
```

`EXCLUDED` is the row that was about to be inserted — useful in ON CONFLICT SET clauses.

**UPDATE without WHERE** updates every row in the table. Almost always a mistake. Same for DELETE without WHERE.

## Advanced view

- **UPDATE FROM**: update one table using values from another (PostgreSQL extension to standard SQL).
- **DELETE USING**: same pattern for deletes.
- **TRUNCATE vs DELETE**: TRUNCATE bypasses row-by-row logging — much faster for large tables but cannot be filtered (no WHERE). TRUNCATE fires no row-level triggers. It can be rolled back inside a transaction.
- **Dead tuples**: DELETE does not immediately free space. PostgreSQL marks rows as dead; VACUUM reclaims them. High-delete tables need frequent vacuuming.
- **CTEs with writes**: `WITH deleted AS (DELETE ... RETURNING *) SELECT * FROM deleted` — useful audit patterns.

## Mental model

Every write operation targets a **set of rows** (possibly empty, possibly all rows). The WHERE clause defines the set. Omitting WHERE = "the set is every row." Always state the set explicitly.

## PostgreSQL view

PostgreSQL implements UPDATE as a delete + insert internally (MVCC). The old row version is kept until VACUUM. This is why high-update tables grow and need autovacuum tuning.

## SQL view

```sql
-- INSERT with RETURNING (know the generated ID)
INSERT INTO checkouts (book_id, patron_id, checked_out_at)
VALUES (42, 7, now())
RETURNING id;

-- Conditional UPDATE (always use WHERE)
UPDATE checkouts
SET returned_at = now()
WHERE id = 103
  AND returned_at IS NULL;

-- Safe DELETE (confirm count first)
SELECT COUNT(*) FROM checkouts WHERE patron_id = 7;
DELETE FROM checkouts WHERE patron_id = 7;

-- TRUNCATE for test data cleanup
TRUNCATE checkouts RESTART IDENTITY;
```

## Non-SQL or hybrid view

ORMs (SQLAlchemy, Django ORM, Prisma) generate INSERT/UPDATE/DELETE from object operations. They add WHERE clauses automatically based on primary key — but bulk updates/deletes still require explicit conditions.

## Design principle

**Always use WHERE on UPDATE and DELETE.** Make it a physical rule. Before running a destructive statement, run the equivalent SELECT to preview the rows you are about to change.

## Critical thinking

- Why does PostgreSQL support `RETURNING`? It avoids a second round-trip to fetch what was just written — important for high-throughput write paths.
- What is the risk of `TRUNCATE ... CASCADE`? It truncates all tables with foreign keys pointing to the target table. Know your cascade graph before using it.

## Creative thinking

You can use INSERT ... SELECT to copy filtered rows from one table to another (archive pattern):

```sql
INSERT INTO books_archive
SELECT * FROM books
WHERE published_year < 1900;

DELETE FROM books WHERE published_year < 1900;
```

## Systems thinking

In event-sourced systems, rows are never UPDATEd or DELETEd — only INSERTed. The current state is derived by replaying events. This trades write simplicity for query complexity.

## MCP and agent perspective

An agent with write access needs:

- INSERT permission only for specific tables and columns (not `*`).
- No DELETE access by default — require human approval.
- RETURNING so the agent can confirm what was written without a follow-up SELECT.
- Rate limiting at the application layer — an agent can loop and INSERT millions of rows accidentally.

## Ontology perspective

- INSERT/UPDATE/DELETE are **DML** (Data Manipulation Language) — they change data without changing schema.
- TRUNCATE is DDL in PostgreSQL (it acquires an ACCESS EXCLUSIVE lock).
- All three are **mutations** — operations that change the database state (as opposed to queries, which read state).

## Practice session

See `practice/beginner/03-data-types-and-constraints/` for INSERT patterns.

The transactions practice (`practice/beginner/06-simple-transactions/`) covers UPDATE/DELETE inside BEGIN/COMMIT.

## References

| Resource | URL | Why |
|----------|-----|-----|
| PostgreSQL docs — INSERT | https://www.postgresql.org/docs/current/sql-insert.html | Full syntax including ON CONFLICT |
| PostgreSQL docs — UPDATE | https://www.postgresql.org/docs/current/sql-update.html | UPDATE FROM syntax |
| PostgreSQL docs — DELETE | https://www.postgresql.org/docs/current/sql-delete.html | DELETE USING syntax |
| PostgreSQL docs — TRUNCATE | https://www.postgresql.org/docs/current/sql-truncate.html | TRUNCATE vs DELETE tradeoffs |
| SQLBolt — Lesson 13–16 | https://sqlbolt.com/lesson/inserting_rows | Interactive INSERT/UPDATE/DELETE |
