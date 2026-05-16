# Ontology Notes — Transactions and Isolation Levels

## Transaction as a boundary event
In ontology terms, a transaction is a **boundary event** — a discrete moment when the world's state transitions from one valid configuration to another. The transaction's COMMIT is the moment the new state becomes "real" in the shared ontology.

## Isolation as visibility scoping
Each isolation level defines a **visibility scope** — the set of facts a transaction is allowed to perceive at any moment. This maps to ontological concepts of:
- **Open World Assumption (OWA)**: READ COMMITTED — new facts inserted by others become visible as they are committed (the world is open and growing)
- **Closed World Assumption (CWA)**: REPEATABLE READ / SERIALIZABLE — the transaction operates as if the world is frozen at its snapshot point (facts not in the snapshot do not exist)

## ACID in ontological terms
- **Atomicity**: A transaction is an indivisible ontological fact — it either fully happened or did not happen. There are no partial events.
- **Consistency**: The database transitions between states that satisfy all declared constraints — the ontology's axioms are preserved.
- **Isolation**: Concurrent transactions do not perceive each other's intermediate states — each observes a consistent projection of the ontology.
- **Durability**: A committed transaction's effects are permanent — the fact is written into the ontology and cannot be retracted without an explicit new event.

## Bank account schema as an ontology
- `bank_accounts` entities are **persistent objects** in the ontology with a continuous identity (id)
- `transfers` entities are **events** — they record that a transition occurred between two persistent objects at a specific time
- The `balance` attribute is a **derived property** in the ideal model (sum of all transfers), stored as a denormalized snapshot for query efficiency
- The CHECK constraint `balance >= 0` is an **ontological axiom** — a fact that must be true in every valid state

## Serialization anomalies and causal consistency
A serialization anomaly (write skew) occurs when two transactions each read data the other will write, producing a result that could not have come from any serial execution. This is an ontological inconsistency: the final state implies a causal loop — each fact was written in response to the other, which is impossible in a causally ordered world.

SERIALIZABLE isolation enforces **causal consistency** by detecting and aborting transactions that would create such loops.

## Obsidian graph mapping
- `bank_accounts` → node type: Entity/Account
- `transfers` → node type: Event/Transfer
- Edge: Account --[source_of]--> Transfer
- Edge: Account --[destination_of]--> Transfer
- Property constraint: `balance >= 0` maps to an invariant axiom in the ontology
