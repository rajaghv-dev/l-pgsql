# Ontology Thinking Prompts

10+ questions about concept relationships — how PostgreSQL ideas relate to, depend on, and constrain each other.

---

## Constraints and Triggers

### Q: What is the difference between a constraint and a trigger? When should you use each?
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** A constraint is a declarative rule enforced by the storage engine — it is either satisfied or not. A trigger is an event-driven procedure that runs on write. Which is faster? Which is more flexible? Which can do things the other cannot?  
**Reference:** [[concepts/intermediate/02-constraints-as-business-invariants]]

---

### Q: Can a trigger enforce something that a CHECK constraint cannot? Give a concrete example.
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** CHECK constraints can only reference the current row's columns in the current table. A trigger can query other tables, call functions, and look at the OLD value. What cross-table invariant requires a trigger?  
**Reference:** [[design-principles/schema-design-principles]] Principle 1

---

## Indexes and Tables

### Q: How does an index relate to a table in terms of data dependency?
**Type:** Ontology  
**Level:** Beginner  
**Hint:** An index is a derived structure — it exists only to accelerate access to data in the table. Every row insert, update, or delete must update the index. Who "owns" the index? What happens to the index if you drop the table?  
**Reference:** [[diagrams/index-selection-flow]]

---

### Q: What is the relationship between a view and a materialized view? What does "materialized" mean in this context?
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** A view is a named query — it runs the query on each access. A materialized view stores the result of the query as a physical table. What is the cost of each? What does `REFRESH MATERIALIZED VIEW` do?  
**Reference:** [[design-principles/advanced-design-principles]] Principle 10

---

## Transactions and Isolation

### Q: What is the difference between isolation and consistency in the ACID acronym?
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** Isolation is about what concurrent transactions see from each other. Consistency is about moving from one valid state to another — it is enforced by constraints. Which is a database mechanism and which is a contract with the application?  
**Reference:** [[concepts/intermediate/07-transactions-and-isolation]]

---

### Q: What is the difference between atomicity and durability? Give a failure scenario that breaks one but not the other.
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** Atomicity = all-or-nothing within a transaction. Durability = committed transactions survive crashes. Can you have atomicity without durability? (Yes: `synchronous_commit = off` risks losing committed transactions on crash but transactions are still atomic.)  
**Reference:** [[concepts/intermediate/07-transactions-and-isolation]]

---

## Schemas and Databases

### Q: What is the difference between a schema and a database as a namespace mechanism?
**Type:** Ontology  
**Level:** Beginner  
**Hint:** Schemas are namespaces within a database — they share connections, transactions, and users. Databases are fully isolated — they do not share connections by default and cannot be JOINed directly. When would you use one vs the other to separate domains?  
**Reference:** [[concepts/beginner/03-database-schema-table-row-column]]

---

### Q: What is the difference between a domain, a type, and a constraint in PostgreSQL's type system?
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** A base type (like `text` or `int`) is fundamental. A domain is a named type with constraints added on top of a base type. A constraint is a rule on a column or table. How does a domain differ from a CHECK constraint on a column?  
**Reference:** [[design-principles/intermediate-design-principles]] Principle 10

---

## Roles and Security

### Q: What is the difference between a role, a user, and a group in PostgreSQL?
**Type:** Ontology  
**Level:** Beginner  
**Hint:** In PostgreSQL, users and groups are both roles. A role with `LOGIN` is what we call a user. A role without `LOGIN` is used as a group. How does `GRANT role TO another_role` work?  
**Reference:** [[design-principles/security-design-principles]] Principle 1

---

### Q: What is the difference between a table privilege and a column privilege? When would you grant column-level access?
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** `GRANT SELECT ON TABLE orders TO reporter_role` gives SELECT on all columns. `GRANT SELECT (id, total, created_at) ON orders TO reporter_role` gives SELECT on only those columns. When would column-level grants be appropriate?  
**Reference:** [[design-principles/security-design-principles]]

---

## Extensions and Core Features

### Q: What is the difference between a PostgreSQL extension and a built-in feature? Where is the line?
**Type:** Ontology  
**Level:** Intermediate  
**Hint:** Extensions are installed with `CREATE EXTENSION` and live in the `pg_extension` catalog. Built-in features exist without extension. Some "built-in" features (like RLS) are in core; some frequently-used features (like `pgcrypto`, `pg_stat_statements`) require extension. What determines which side of the line something falls on?  
**Reference:** [[diagrams/extension-ecosystem-map]]

---

### Q: What is the relationship between WAL, replication, and crash recovery?
**Type:** Ontology  
**Level:** Advanced  
**Hint:** WAL is the source of truth for all three. Crash recovery replays WAL from last checkpoint. Streaming replication ships WAL to standbys. Logical replication decodes WAL into row-level changes. How does each use WAL differently?  
**Reference:** [[diagrams/postgres-mental-model]]
