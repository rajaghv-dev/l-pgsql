# Ontology Notes — JSONB Modeling

## JSONB as extensional ontology
A relational table with fixed columns represents a **closed schema**: every entity of that type has exactly the same properties. JSONB attributes add **extensional properties**: properties that exist only for some entities and are not part of the core type definition.

In ontology terms, core columns are **essential properties** (part of the type's definition) while JSONB attributes are **accidental properties** (contingent, not definitional). A product is a product whether or not it has a `waterproof` attribute; but its `id` and `price` are essential.

## EAV as failed ontology
The Entity-Attribute-Value (EAV) pattern was a common pre-JSONB approach to extensional properties. EAV stores attribute names as rows in a separate table — making queries verbose and losing type information. JSONB is a more ontologically coherent approach: each entity carries its own attribute bundle, and the structure is queryable without joins.

## JSONB field registry as an informal ontology
The `jsonb_field_registry` table is an informal ontology for JSONB fields: it declares which properties exist, their types, and descriptions. A formal ontology would also capture:
- Cardinality (exactly one value vs many)
- Domain (which entity types can have this property)
- Range (what values are valid)
- Synonyms (is `brand` the same as `manufacturer`?)

## Obsidian graph mapping
- `products` → node type: Entity/Product
- `categories` → node type: Entity/Category (type hierarchy)
- `attributes.brand` → property: hasBrand (linking to Brand node)
- `attributes.color` → property: hasColor (linking to Color node)
- Generated column `brand` → materialized ontology property (promoted from extensional to essential)
- `jsonb_field_registry` → ontology declaration layer

## Schema evolution as ontology evolution
When a JSONB key is promoted to a real column, this represents an **ontological promotion**: a property that was considered accidental has become essential to the type definition. This is a significant design event — it signals that the property has been recognized as part of the entity's core nature.
