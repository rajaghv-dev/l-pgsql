# Reflection — Full-Text Search and Fuzzy Search

## Key takeaways
- Use FTS (tsvector/tsquery + GIN) for document search with language awareness and relevance ranking.
- Use pg_trgm for short-string fuzzy matching (names, titles, product codes) and typo tolerance.
- Always store tsvectors (GENERATED ALWAYS or trigger) and index them — never compute `to_tsvector()` on every query row.
- `websearch_to_tsquery` is the right choice for user-provided search input.
- Combine FTS and pg_trgm in a tiered query: FTS for precision, trgm for recall when FTS fails.

## When each approach wins
| Scenario | FTS | pg_trgm |
|---|---|---|
| Article/document search | Best | Not ideal |
| Name/username search | Poor (stemming distorts names) | Best |
| Typo tolerance | Limited | Best |
| Multilingual | Yes (per-row regconfig) | No (character-based) |
| Relevance ranking | Yes (ts_rank) | Possible (similarity score) |
| ILIKE acceleration | No | Yes (GIST index) |

## What to explore next
- Concept 15: pgvector — semantic search using embeddings (complements FTS)
- Concept 19: pg_stat_statements — measure actual FTS query performance
- Practice 09: pgvector retrieval — compare embedding-based vs FTS-based retrieval
