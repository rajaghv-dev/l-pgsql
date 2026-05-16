# Solutions — Full-Text Search and Fuzzy Search

**Status: blocked — Docker not accessible in this session**

## Exercise 1 solution
- `to_tsquery('english', 'postgres & performance')` — matches articles containing both stems
- Phrase query `'row <-> level'` — requires "row" immediately before "level" in the document
- `websearch_to_tsquery` is the safe choice for user input: it handles quotes, `-` for NOT, and arbitrary text without SQL injection risk
- `plainto_tsquery` converts all words to AND implicitly — "query planning" → `'queri' & 'plan'`

## Exercise 2 solution
`ts_rank` scores each result by how frequently and prominently the query terms appear. Results with query terms in the title (weight A) score higher than those with terms only in the body (weight B). Expected top result for 'postgres | database | query': "PostgreSQL Performance Tuning" or "Full Text Search in PostgreSQL" depending on term frequency.

## Exercise 3 solution
`ts_headline` extracts a snippet from the body text, wrapping matched terms with the configured delimiters. With `StartSel=<<, StopSel=>>`:
```
Use operators like <<@>> for containment checks and <<GIN>> indexes for performance.
```
The highlight honors the document's word boundaries and tries to center the window on matched terms.

## Exercise 4 solution
- `similarity('Posgress Performance', 'PostgreSQL Performance Tuning')` ≈ 0.35 (above default 0.3 threshold)
- Lower threshold (0.2) catches more typos but may return irrelevant results
- `word_similarity('vacuum', 'Understanding MVCC and Vacuum')` ≈ 1.0 — the query word is exactly present in the title

The `%` operator uses the similarity threshold GUC; adjust per-session with `SET`.

## Exercise 5 solution
The combined query implements a tiered search:
1. Try FTS with the (misspelled) query — likely returns 0 results for "vacuem"
2. If FTS finds nothing, fall back to trigram similarity on the title
3. "Understanding MVCC and Vacuum" would surface via trgm (similarity to "vacuem" ≈ 0.35)

In production, this fallback should be implemented at the application layer or as a PostgreSQL function to avoid the CTE overhead when FTS succeeds.

## Exercise 6 solution
The JOIN with tags enables structured filtering alongside FTS. Only articles tagged 'performance' and matching the FTS query are returned. This is the hybrid query pattern: FTS for recall, relational joins for precision filtering.

## Reflection answers
1. Generated columns are maintained automatically and atomically with the row data — no trigger logic to maintain, no risk of the column getting out of sync. Triggers can miss bulk UPDATEs (e.g., `UPDATE articles SET language = 'french' WHERE author = 'X'`). Generated column re-computes automatically.
2. `ts_rank` weighs by frequency; `ts_rank_cd` (coverage density) also weighs by the span of document covered by matches — better for long documents where a result covering more of the document is considered more relevant.
3. `to_tsquery` requires syntactically valid tsquery expressions. If a user types `"apple & (orange"`, it raises an error. `websearch_to_tsquery` always succeeds, treating unknown syntax as literal text.
4. `word_similarity` is better when the query is a word or short phrase that should appear within a longer text. `similarity` compares the full string lengths, penalizing long text heavily. For a 2-word query vs a 6-word title, `word_similarity` gives a fair score.
