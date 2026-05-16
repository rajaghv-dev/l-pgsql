# Foreign Keys and Relationships

Level: Beginner

---

## One-line intuition

A foreign key is a column in one table that points to the primary key of another table, enforcing that the relationship refers to something real.

---

## Why this exists

Data is rarely about one thing. Books have authors. Orders have customers. Orders contain products. Without foreign keys:
- You can insert an order referencing a customer that does not exist
- You can delete a customer who still has open orders
- The application has to manually check consistency — and will sometimes miss it

Foreign keys delegate this consistency check to the database.

---

## First-principles explanation

A **relationship** is a fact about how two entities are connected. "Order 7 was placed by Customer 42." In a relational database, this is expressed by storing `customer_id = 42` in the orders table. A foreign key constraint tells PostgreSQL: "the value in this column must exist as a primary key in that other table."

This is called **referential integrity**: the reference always points to something real.

---

## Micro-concepts

| Term | Meaning |
|------|---------|
| **Foreign key (FK)** | A column that references the PK of another table |
| **Referencing table** | The table that contains the FK (child) |
| **Referenced table** | The table being pointed at (parent) |
| **Referential integrity** | The guarantee that every FK value exists as a PK in the parent |
| **ON DELETE CASCADE** | When a parent row is deleted, delete child rows automatically |
| **ON DELETE RESTRICT** | Block deletion of parent if children exist (default) |
| **ON DELETE SET NULL** | Set FK to NULL when parent is deleted |
| **ON DELETE SET DEFAULT** | Set FK to the column's default when parent is deleted |
| **ON UPDATE CASCADE** | When parent PK changes, update FK automatically |

---

## Beginner view

**Library example: books and authors**

```
authors                          books
┌────┬──────────────────┐        ┌────┬──────────────────┬───────────┐
│ id │ name             │        │ id │ title            │ author_id │
├────┼──────────────────┤        ├────┼──────────────────┼───────────┤
│  1 │ Frank Herbert    │◄───────│  1 │ Dune             │     1     │
│  2 │ William Gibson   │◄───────│  2 │ Neuromancer      │     2     │
└────┴──────────────────┘    ┌───│  3 │ Dune Messiah     │     1     │
                              │   └────┴──────────────────┴───────────┘
                              └─ author_id = 1 means "Frank Herbert"
```

The `author_id` column in `books` is a foreign key referencing `authors.id`. PostgreSQL will:
- Reject an INSERT into `books` if `author_id` does not exist in `authors`
- Enforce the rule on every INSERT and UPDATE — not just the first one

---

## Intermediate view

### Relationship types

**One-to-many (most common):**
One author → many books. The FK lives on the "many" side (books.author_id).

**Many-to-many:**
One book can have many tags; one tag can apply to many books. Neither table can hold the FK. Use a **junction table**:

```sql
CREATE TABLE book_tags (
    book_id BIGINT REFERENCES books(id) ON DELETE CASCADE,
    tag_id  BIGINT REFERENCES tags(id)  ON DELETE CASCADE,
    PRIMARY KEY (book_id, tag_id)
);
```

**One-to-one:**
One user profile → one settings row. Enforce with a UNIQUE constraint on the FK column.

### ON DELETE behavior comparison

| Action | What happens to child rows when parent is deleted |
|--------|--------------------------------------------------|
| `RESTRICT` (default) | Error — parent cannot be deleted |
| `NO ACTION` | Same as RESTRICT, checked at end of transaction |
| `CASCADE` | Child rows are deleted automatically |
| `SET NULL` | Child FK column is set to NULL |
| `SET DEFAULT` | Child FK column is set to its declared default |

**Rule of thumb:**
- Audit logs, historical records: `SET NULL` or `RESTRICT` (do not lose history)
- Child entities meaningless without parent (order items): `CASCADE`
- Required reference: `RESTRICT` (make the deletion explicit)

---

## Advanced view

### Deferred constraints

By default, FK constraints are checked immediately. For complex multi-table inserts (e.g. inserting two rows that reference each other), you can defer checking to end-of-transaction:

```sql
ALTER TABLE book_tags
  ADD CONSTRAINT fk_book FOREIGN KEY (book_id) REFERENCES books(id)
  DEFERRABLE INITIALLY DEFERRED;
```

### Index your foreign keys

PostgreSQL automatically indexes primary keys. It does NOT automatically index foreign key columns. Always add an index on FK columns that you join or filter on frequently:

```sql
CREATE INDEX ON books (author_id);
```

Without this, a query like `SELECT * FROM books WHERE author_id = 42` requires a sequential scan of the entire `books` table.

### Self-referential FK (hierarchy)

```sql
CREATE TABLE categories (
    id        BIGSERIAL PRIMARY KEY,
    name      TEXT      NOT NULL,
    parent_id BIGINT    REFERENCES categories(id)  -- points to self
);
```

This models a tree (category → subcategory → sub-subcategory).

---

## Mental model

```
Parent table (authors)          Child table (books)
┌────┬──────────────┐           ┌────┬───────────┬───────────┐
│ id │ name         │           │ id │ title     │ author_id │
├────┼──────────────┤           ├────┼───────────┼───────────┤
│  1 │ Frank Herbert│←──────────│  1 │ Dune      │     1     │
└────┴──────────────┘           └────┴───────────┴───────────┘

FK constraint says: "author_id must exist in authors.id"
On every INSERT/UPDATE of books, PostgreSQL verifies this.
```

---

## PostgreSQL view

```sql
-- List all FK constraints in the database
SELECT
    tc.table_name    AS child_table,
    kcu.column_name  AS fk_column,
    ccu.table_name   AS parent_table,
    ccu.column_name  AS parent_column,
    rc.delete_rule
FROM information_schema.table_constraints        tc
JOIN information_schema.key_column_usage         kcu  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.referential_constraints  rc   ON tc.constraint_name = rc.constraint_name
JOIN information_schema.constraint_column_usage  ccu  ON ccu.constraint_name = rc.unique_constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY';
```

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## SQL view

```sql
-- Parent table
CREATE TABLE IF NOT EXISTS authors (
    id   BIGSERIAL PRIMARY KEY,
    name TEXT      NOT NULL
);

-- Child table with FK
CREATE TABLE IF NOT EXISTS books (
    id        BIGSERIAL PRIMARY KEY,
    title     TEXT   NOT NULL,
    author_id BIGINT NOT NULL REFERENCES authors(id) ON DELETE RESTRICT
);

-- Index the FK column
CREATE INDEX IF NOT EXISTS idx_books_author_id ON books (author_id);

-- Many-to-many junction
CREATE TABLE IF NOT EXISTS tags (
    id   BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS book_tags (
    book_id BIGINT NOT NULL REFERENCES books(id)  ON DELETE CASCADE,
    tag_id  BIGINT NOT NULL REFERENCES tags(id)   ON DELETE CASCADE,
    PRIMARY KEY (book_id, tag_id)
);

-- Join across FK
SELECT b.title, a.name AS author
FROM   books   b
JOIN   authors a ON a.id = b.author_id
ORDER  BY a.name, b.title;
```

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Non-SQL or hybrid view

MongoDB has no native foreign key concept. Relationships are expressed by embedding documents or by storing `ObjectId` references manually — but the database does not enforce them. Application code or a separate validation layer must check consistency. This is a common source of orphaned records in MongoDB applications.

---

## Design principle

**Let the database enforce relationships, not the application.** An application can have bugs, race conditions, or be bypassed entirely (direct SQL access, scripts, imports). A FK constraint runs on every write, no exceptions, no bugs in the enforcement code.

---

## Critical thinking

- What happens if you try to INSERT a book with `author_id = 999` when no author with id 999 exists? (PostgreSQL raises a foreign key violation error.)
- Why is ON DELETE CASCADE dangerous for audit tables? (If you delete a customer, their order history disappears — you lose the audit trail.)
- If you need to delete a customer who has orders, what is the correct process without CASCADE? (Delete orders first, then delete the customer — or soft-delete by setting a `deleted_at` timestamp instead.)

---

## Creative thinking

A foreign key is like a library card that points to the main card catalog. Your loan record (child) references a specific book (parent) by its catalog number. If you try to return a book with a made-up catalog number, the librarian rejects it — the reference must be real. If the library deaccessions (deletes) a book, the policy decides what happens to outstanding loans (CASCADE = automatically resolved, RESTRICT = must resolve loans first).

---

## Systems thinking

FKs create a dependency graph. When designing a schema:
1. Draw the entity-relationship diagram first
2. Identify which tables are "parents" (referenced) and which are "children" (referencing)
3. Plan deletion order: children before parents
4. Add FK indexes on all FK columns
5. Choose ON DELETE behavior based on business rules, not convenience

In high-traffic systems, FK checks add overhead. Some teams disable FK enforcement for maximum throughput and enforce referential integrity at the application layer. This is a trade-off — not a recommendation for beginners.

---

## MCP and agent perspective

An agent that writes relational data (e.g. creating tasks assigned to users) relies on FKs to keep its world consistent. If the agent deletes a user, ON DELETE behavior automatically determines what happens to their tasks. The agent does not need to manage this logic itself. FKs also help agents discover schema relationships — they can query `information_schema.referential_constraints` to understand how tables connect before writing queries.

---

## Ontology perspective

A foreign key implements an **object property** in ontological terms — a relationship between two classes. `books.author_id` is the property "is written by" connecting the Books class to the Authors class. The FK constraint enforces the **domain** restriction: the subject must be a Book (row in books), the range must be an Author (row in authors). Referential integrity is the closed-world enforcement of this axiom.

---

## Practice session

See `practice/beginner/03-keys-and-constraints/` for FK creation, violation, and JOIN exercises.

---

## References

| Resource | URL |
|----------|-----|
| PostgreSQL 16 — FK Constraints | https://www.postgresql.org/docs/16/ddl-constraints.html#DDL-CONSTRAINTS-FK |
| PostgreSQL 16 — Referential Integrity | https://www.postgresql.org/docs/16/tutorial-fk.html |
| PostgreSQL 16 — JOIN types | https://www.postgresql.org/docs/16/queries-table-expressions.html |
| Always index your FK columns | https://use-the-index-luke.com/sql/join |
