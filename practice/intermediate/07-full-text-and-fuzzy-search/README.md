# Practice: Full-Text Search and Fuzzy Search

**Stage:** 10 — Non-SQL Capabilities
**Concept files:** `concepts/intermediate/11-full-text-search-design.md`, `concepts/intermediate/12-fuzzy-search-with-pg-trgm.md`
**Level:** Intermediate

## Goal
Build a searchable articles table using tsvector + GIN for FTS, and pg_trgm for fuzzy/typo-tolerant search. Practice ranking, highlighting, and combining both approaches.

## Schema overview
- `articles` — title, body, language, stored tsvector
- `tags` — simple tag table for filtered search exercises

## Docker note
All SQL is blocked: Docker not accessible in this session.
