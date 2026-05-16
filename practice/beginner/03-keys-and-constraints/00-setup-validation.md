# Setup Validation — Practice 03: Keys and Constraints

> blocked: Docker not accessible; validate against cfp_postgres when available

---

## Step 1 — Run setup.sql

```bash
docker exec -i cfp_postgres psql -U cfp -d cfp < practice/beginner/03-keys-and-constraints/setup.sql
```

The final query lists all constraints. Confirm they are present.

---

## Step 2 — List all constraints on store tables

```sql
SELECT
    conname     AS constraint_name,
    contype     AS type,
    conrelid::regclass AS on_table,
    pg_get_constraintdef(oid) AS definition
FROM   pg_constraint
WHERE  conrelid IN (
    'store.customers'::regclass,
    'store.products'::regclass,
    'store.orders'::regclass
)
ORDER  BY on_table, contype;
```

**contype key:**
- `c` = CHECK
- `f` = FOREIGN KEY
- `p` = PRIMARY KEY
- `u` = UNIQUE
- `n` = NOT NULL (stored per-attribute, not here)

Expected constraints:
- `store.customers`: PRIMARY KEY, UNIQUE (email)
- `store.products`: PRIMARY KEY, UNIQUE (sku), CHECK (price), CHECK (status)
- `store.orders`: PRIMARY KEY, FOREIGN KEY (customer_id), CHECK (status)

---

## Step 3 — Verify NOT NULL via information_schema

```sql
SELECT column_name, is_nullable
FROM   information_schema.columns
WHERE  table_schema = 'store'
ORDER  BY table_name, ordinal_position;
```

Columns declared NOT NULL should show `is_nullable = NO`.

---

## Step 4 — Verify index on orders.customer_id

```sql
SELECT indexname, indexdef
FROM   pg_indexes
WHERE  schemaname = 'store' AND tablename = 'orders';
```

Expected: `idx_orders_customer_id` on `(customer_id)`.

---

## Checklist

- [ ] All 3 tables recreated with full constraints
- [ ] PRIMARY KEY on `id` for all tables
- [ ] `customers.email` has UNIQUE constraint
- [ ] `products.sku` has UNIQUE constraint
- [ ] `products.price` has CHECK (price > 0)
- [ ] `products.status` has CHECK (IN 'active','discontinued','draft')
- [ ] `orders.customer_id` has FK to customers.id
- [ ] `orders.status` has CHECK constraint
- [ ] Index on `orders.customer_id` exists
- [ ] Seed data: 3 customers, 3 products, 3 orders
