# Ontology Notes — Constraint-Driven Design

---

## Constraints as ontological axioms

In formal ontologies (OWL, Description Logics), axioms are statements that must hold in all models of the ontology. Database constraints are the relational equivalent:

| Constraint type | Ontological equivalent |
|---|---|
| `NOT NULL` | Existential restriction: property p must exist for every instance of class C |
| `UNIQUE` | Uniqueness axiom: property p is a functional property (injective) |
| `PRIMARY KEY` | Identity criterion: p uniquely identifies instances of C |
| `FOREIGN KEY` | Referential axiom: instances of C must be related to existing instances of D |
| `CHECK` | Invariant: boolean predicate P must hold for all instances of C |
| `EXCLUDE` | Disjointness with overlap: no two instances of C can jointly satisfy predicate P |

---

## Closed-world assumption

Relational constraints operate under the **closed-world assumption**: if a fact is not in the database, it is false. This contrasts with the open-world assumption of RDF/OWL, where absence of a fact is simply absence of knowledge.

Practical consequence: NOT NULL is meaningful in a closed-world DB ("no email means the email is unknown/missing"). In an open-world system, NULL would mean "we don't know yet" — which is actually what `deleted_at IS NULL` means in the soft-delete pattern.

---

## The soft-delete pattern as ontological split

The `deleted_at` column splits the `customers` class into two subclasses:
- `ActiveCustomer` (deleted_at IS NULL)
- `DeletedCustomer` (deleted_at IS NOT NULL)

The partial unique index `WHERE deleted_at IS NULL` enforces a uniqueness axiom only on `ActiveCustomer`. This is equivalent to a subclass-level uniqueness constraint in OWL.

---

## EXCLUDE as a spatial/temporal disjointness axiom

The EXCLUDE constraint on reservations expresses:
> For all reservations r1 and r2 for the same room: the time intervals must be disjoint.

In formal logic: `∀r1, r2 ∈ Reservation: r1.room = r2.room ∧ r1 ≠ r2 → ¬(r1.during ∩ r2.during ≠ ∅)`

This is a **co-occurrence constraint** — a statement about the joint behavior of multiple instances. Relational constraints rarely express cross-row rules this cleanly; EXCLUDE is an exception.

---

## Named constraints as machine-readable semantics

Naming constraints (`price_must_be_positive`, `valid_order_status`) gives machine-readable semantic labels to the enforcement points. Applications can map constraint names to business rule descriptions, localizations, or remediation actions — a lightweight form of semantic annotation.

This aligns with ontological annotation properties (`rdfs:label`, `rdfs:comment`) applied to axioms.
