# Practice Session: pgvector Retrieval

Level: Intermediate
Prerequisites: intermediate SQL, understanding of indexes, basic familiarity with embeddings

## Goal

This session teaches you how to store synthetic vector embeddings in a PostgreSQL table using the pgvector extension and query nearest neighbours with the `<->` (L2 distance) operator. You will see how vector search integrates with ordinary SQL filters and how an IVFFLAT or HNSW index accelerates similarity search at scale.

## Quick start

```bash
docker exec cfp_postgres psql -U cfp -d cfp -f practice/intermediate/09-pgvector-retrieval/setup.sql
```
Note: blocked — Docker not accessible in current session; validate when Docker Desktop WSL2 integration is enabled.

## Files

| File | Purpose |
|------|---------|
| setup.sql | Schema and seed data |
| exercises.md | Step-by-step exercises |
| solutions.md | Full solutions |
| reflection.md | Thinking questions |
| ontology-notes.md | Concept connections |
| troubleshooting.md | Common errors |
| references.md | Further reading |

## What you'll learn

- How to enable the pgvector extension (`CREATE EXTENSION vector`)
- How to declare a `VECTOR(n)` column for fixed-dimension embeddings
- How to insert rows with literal vector values using the `'[0.1, 0.2, ...]'::vector` cast
- How to find the k nearest neighbours with `ORDER BY embedding <-> query_vec LIMIT k`
- The difference between `<->` (L2), `<#>` (inner product), and `<=>` (cosine) distance operators
- How an IVFFLAT index trades recall for speed, and when to rebuild it after bulk inserts

## MCP and agent perspective

Agents that implement retrieval-augmented generation (RAG) store document chunk embeddings in pgvector and query them at inference time. Because the vector search runs inside PostgreSQL, agents can combine semantic similarity with ordinary SQL predicates — for example, "find the 5 most similar documents WHERE doc_type = 'policy' AND updated_at > NOW() - INTERVAL '30 days'" — in a single round-trip query.
