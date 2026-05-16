# Ontology Notes — Query Planning with EXPLAIN

---

## The query plan as a proof structure

A SQL query is a declarative specification: "return rows satisfying condition C." The query planner produces an **execution plan** — an imperative procedure for computing those rows. This relationship mirrors the correspondence between a logical formula and a proof of that formula:

- The query = the theorem statement
- The plan = the proof
- Each plan node = a proof step (inference rule applied to sub-results)
- The cost = the complexity of the proof

A "bad plan" is an inefficient proof — correct in output but expensive in derivation.

---

## The planner as a bounded-rational agent

PostgreSQL's planner enumerates candidate plans and selects the one with lowest estimated cost. This is a form of **bounded rationality**: it cannot explore all possible plans (the search space is exponential in join count), so it uses heuristics (join collapse limit, genetic query optimizer for large join counts).

The planner's rationality is limited by its information (statistics). Stale or missing statistics cause it to make decisions that appear rational given its beliefs but are incorrect given reality — analogous to a rational agent with a partially-incorrect world model.

---

## Statistics as an epistemological structure

`pg_stats` stores histograms, most-common values, and null fractions per column — a compact representation of what PostgreSQL "knows" about the data distribution. The statistics target controls the resolution of this knowledge.

This is an **epistemological structure**: a model of the database's knowledge about itself. Low statistics target = coarse knowledge = low-quality plans. High statistics target = detailed knowledge = better plans, but more ANALYZE time.

---

## The visibility map as a consistency structure

The visibility map tracks which heap pages are "all-visible" (no dead tuples from concurrent transactions visible to any active snapshot). Index Only Scans require the visibility map to be current — without it, PostgreSQL must verify each row's visibility from the heap.

In ontological terms, the visibility map is a **consistency certificate**: a page marked all-visible is guaranteed to contain only valid, committed tuples. The MVCC protocol maintains this certificate through VACUUM.

---

## pg_stat_statements as an observational ontology

`pg_stat_statements` maintains aggregate observations about query executions. It answers "what happened and how often" — an extensional record of query behavior over time. This is an **observational ontology**: a structured record of events (query executions) with aggregate properties (total time, mean time, rows).

Querying `pg_stat_statements` is itself a meta-level query: querying observations about queries. This reflexivity is a hallmark of observational monitoring systems.

---

## Seq Scan vs. Index Scan as knowledge-driven choice

The planner chooses Seq Scan when it estimates that the indexed rows constitute a large fraction of the table — essentially saying "I know so little about which rows to skip that it's faster to read everything." This is correct given the planner's knowledge.

The choice is an **epistemic decision under uncertainty**: if the planner's estimate of selectivity is wrong (as in Exercise 3), it makes a suboptimal choice. More precise statistics narrow the uncertainty and improve the decision.
