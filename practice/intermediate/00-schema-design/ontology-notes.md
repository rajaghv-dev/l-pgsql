# Ontology Notes — Schema Design

These notes map the schema's entities and relationships to ontological concepts.

---

## Entities (Classes)

| Table | Ontological role | Identity |
|---|---|---|
| `customers` | Agent (buyer) | `email` (natural key); `id` (surrogate) |
| `categories` | Classification | `name` (natural key) |
| `products` | Artifact | `sku` (natural key); `id` (surrogate) |
| `orders` | Event / Transaction | `id` (surrogate); timestamp marks occurrence |
| `order_items` | Participation (in an event) | Composite: `(order_id, product_id)` |

---

## Relationships (Properties)

| Relationship | Ontological type | Cardinality |
|---|---|---|
| customer places order | `hasParticipant` (agent role) | 1:N |
| order contains item | `hasPart` (mereological) | 1:N |
| item refers to product | `refersTo` (referential) | N:1 |
| product belongs to category | `isA` (classification) | N:1 |

---

## Snapshot semantics

`order_items.unit_price` is a **snapshot property** — it records the value of `products.price` at the moment the order was placed. In ontological terms, this is a **temporal indexical**: the value is true of the world at a specific time, not continuously.

This is distinct from a **functional property** (like `products.price`) which reflects the current world state.

---

## JSONB as open-world attributes

`products.attrs` uses JSONB to represent **open-world attributes** — properties whose schema is not known at table-design time. In ontological terms, this is analogous to RDF's open-world assumption: new properties can be added without schema changes.

The trade-off: closed-world constraints (NOT NULL, type checking, FK) cannot be applied to JSONB keys without CHECK constraints or application-layer validation.

---

## The junction table as a reified relation

`order_items` is a **reification** of the association between `orders` and `products`. In ontology engineering, reifying an n-ary relation means promoting it to a class with its own identity and properties (`qty`, `unit_price`, `line_total`). This is the standard pattern when a relation itself has attributes.

---

## Existential commitments

Each FK is an existential commitment: "This entity cannot exist without that entity."
- An `order_item` cannot exist without an `order` AND a `product`.
- An `order` cannot exist without a `customer`.
- A `product` cannot exist without a `category`.

The `ON DELETE` behavior defines what happens when the existence constraint is broken from the parent side.
