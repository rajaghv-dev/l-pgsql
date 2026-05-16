# Fuzzy Search with pg_trgm
Level: Intermediate

## One-line intuition
pg_trgm indexes every 3-character substring of a string, enabling fast fuzzy/similarity search — ideal for "did you mean?" features and typo-tolerant user-facing search boxes.

## Why this exists
FTS requires correct spelling (after stemming). A user who types "postresql" or "Posgres" will get no results. pg_trgm fills this gap: it measures string similarity as the fraction of shared trigrams, returning results even when the query is slightly misspelled.

## First-principles explanation
A **trigram** is a sequence of 3 consecutive characters. Every string is decomposed into a set of trigrams (with padding):

`"cat"` → `"  c"`, `" ca"`, `"cat"`, `"at "`, `"t  "` (PostgreSQL uses 2-space padding)

**Similarity** = `|intersection(trigrams_a, trigrams_b)| / |union(trigrams_a, trigrams_b)|`

A similarity of 1.0 = identical strings; 0.0 = no shared trigrams.

Key functions and operators:

| Function/Operator | Description |
|---|---|
| `similarity(a, b)` | Similarity score 0.0–1.0 |
| `a % b` | True if similarity > `pg_trgm.similarity_threshold` (default 0.3) |
| `show_trgm(text)` | Show trigrams of a string |
| `word_similarity(a, b)` | Best match of a against any word in b |
| `a <% b` | Word similarity threshold operator |
| `a <<% b` | Strict word similarity |
| `distance(a, b)` | 1 - similarity |

**Index types supporting trgm:**
- `GIN` with `gin_trgm_ops` — fast for equality-like searches, `%` operator
- `GIST` with `gist_trgm_ops` — supports `LIKE`, `ILIKE`, regex in addition to `%`

## Micro-concepts
- **pg_trgm.similarity_threshold** — GUC controlling the `%` operator cutoff (default 0.3)
- **pg_trgm.word_similarity_threshold** — GUC for word-level matching
- **GIN vs GIST for trgm** — GIN: faster writes, faster `%` queries; GIST: supports LIKE/ILIKE/regex
- **Ordering by similarity** — `ORDER BY similarity(name, 'query') DESC` gives ranked fuzzy results; use `LIMIT` for performance
- **Combining with FTS** — FTS for recall, pg_trgm similarity for re-ranking or typo fallback

## Beginner view
Imagine searching a phone book by ear: you say "Smithe" and the system shows "Smith", "Smithy", "Smythe" because they sound and look similar. pg_trgm does this visually — it finds strings that share most of the same 3-character pieces.

## Intermediate view
For a user-facing search box, the pattern is:
1. Try FTS first (`websearch_to_tsquery`) — precise, fast
2. If FTS returns zero results, fall back to `%` with `ORDER BY similarity DESC LIMIT 10`
3. Present results with "Did you mean: X?" for the trigram fallback

Always use a GIN index with `gin_trgm_ops` for production. Without it, similarity queries scan the full table.

## Advanced view
`word_similarity` is more useful than `similarity` for full-text fields. `similarity('hello world', 'hello')` returns ~0.3 (the full string differs a lot from the query). `word_similarity('hello', 'hello world')` returns 1.0 (the query is perfectly present in the string as a word). Use `word_similarity` for substring-style matching.

For multi-column fuzzy search, combine trigram scores:
```sql
ORDER BY (similarity(first_name, $1) + similarity(last_name, $1)) / 2 DESC
```

## Mental model
Think of pg_trgm as visual fingerprinting: every string's fingerprint is the set of its 3-grams. Two strings are "similar" if their fingerprints overlap substantially. The GIN index is an inverted map: for each trigram, it stores a list of row IDs that contain it. A query trigram set intersects the inverted index to find candidate rows quickly.

## PostgreSQL view
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Simple similarity check
SELECT similarity('postgresql', 'postresql');  -- ~0.65

-- Show trigrams
SELECT show_trgm('cat');

-- Product name fuzzy search
CREATE TABLE products (id SERIAL PRIMARY KEY, name TEXT);
CREATE INDEX ON products USING gin(name gin_trgm_ops);

-- Fuzzy match: name similar to query
SELECT name, similarity(name, 'postresql database') AS sim
FROM products
WHERE name % 'postresql database'
ORDER BY sim DESC
LIMIT 10;

-- ILIKE acceleration with GIST
CREATE INDEX ON products USING gist(name gist_trgm_ops);
SELECT name FROM products WHERE name ILIKE '%postgresql%';
-- Uses the GIST trgm index

-- Combined FTS + trgm fallback
SELECT id, title,
    CASE WHEN search_vector @@ to_tsquery('english', 'postgresql')
         THEN 1.0
         ELSE similarity(title, 'postgresql')
    END AS score
FROM articles
WHERE search_vector @@ to_tsquery('english', 'postgresql')
   OR title % 'postgresql'
ORDER BY score DESC;
```

## SQL view
pg_trgm is PostgreSQL-specific. MySQL does not have a direct equivalent. Elasticsearch uses n-gram tokenizers for similar functionality but with more configuration. SQLite does not support trigram indexes natively.

## Non-SQL or hybrid view
For multilingual fuzzy search, Elasticsearch's `fuzzy` query uses Levenshtein edit distance, which is computationally equivalent for short strings but configured differently. pg_trgm is simpler to use and requires no external service. At very large scale (>50M rows), Elasticsearch's sharding advantage becomes more significant.

## Design principle
**Use pg_trgm for user-facing search inputs; use FTS for document search.** Trigrams excel at short strings (names, product titles, addresses). FTS excels at long documents (articles, descriptions). The two approaches complement each other and can be combined in a single query.

## Critical thinking
- The default threshold of 0.3 is often too low for product names — it will return too many false positives. Tune with `SET pg_trgm.similarity_threshold = 0.4` or `0.5` depending on your domain.
- `ILIKE '%substring%'` on a large table without a GIST/GIN trgm index does a full sequential scan. Adding a GIN trgm index turns this into an index scan.
- Trigram similarity is case-sensitive by default. Use `lower()` or `citext` to normalize casing.

## Creative thinking
Use pg_trgm for deduplication: find rows with similarity > 0.85 against all other rows. This is a self-join with a trigram similarity condition — practical for moderate-size tables but needs careful indexing:
```sql
SELECT a.id, b.id, similarity(a.name, b.name)
FROM products a JOIN products b ON a.id < b.id
WHERE a.name % b.name
ORDER BY similarity(a.name, b.name) DESC;
```

## Systems thinking
pg_trgm similarity is computed at query time, not index time. The index only filters candidates; the similarity score is recalculated for each candidate. Index selectivity depends on the query trigrams — a 2-character query has few trigrams and poor index selectivity. For very short queries (1-3 characters), a sequential scan may be faster than an index scan.

## MCP and agent perspective
An MCP agent handling user queries should run fuzzy search as a fallback when structured lookup returns no results. The agent should parameterize the similarity threshold based on context: stricter for product codes (0.7+), lenient for natural language names (0.3–0.4). Agents building "suggest as you type" features should use `word_similarity` with a LIMIT of 5–10 for low-latency suggestions.

## Ontology perspective
Trigram similarity is a structural similarity measure — it compares surface form, not meaning. Two strings can be syntactically similar but semantically unrelated ("cat" and "can"). For semantic similarity, use pgvector (concept 15). pg_trgm's value in an ontology context is for entity resolution: identifying when two differently-spelled strings likely refer to the same ontological entity. This is the "same-as" relation in linked data terminology.

## Practice session
See `practice/intermediate/07-full-text-and-fuzzy-search/` for hands-on exercises combining FTS and pg_trgm.

## References
- PostgreSQL docs — pg_trgm: https://www.postgresql.org/docs/16/pgtrgm.html
- PostgreSQL docs — similarity function: https://www.postgresql.org/docs/16/pgtrgm.html#PGTRGM-FUNCS-OPS
- "Fuzzy Search with PostgreSQL": https://www.crunchydata.com/blog/fuzzy-name-matching-in-postgresql
- "pg_trgm and ILIKE acceleration": https://www.postgresql.org/docs/16/pgtrgm.html#PGTRGM-INDEX
