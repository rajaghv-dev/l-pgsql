# pg_trgm (pg_trgm)

Level: Intermediate
Available locally: Yes

## One-line purpose

Trigram-based fuzzy string matching and similarity search, enabling typo-tolerant search and fast `LIKE`/`ILIKE` queries with GIN or GiST indexes.

## Why this exists

Standard PostgreSQL `LIKE` requires a full sequential scan unless the pattern is left-anchored. `pg_trgm` breaks strings into overlapping 3-character tokens (trigrams), indexes those tokens, and computes a similarity score between 0 and 1. This enables fast fuzzy search without a separate search engine.

A trigram of `"hello"` → `{" h", " he", "hel", "ell", "llo", "lo "}` (with padding).

## Install

```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS pg_trgm;
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_trgm';
```

## Core operations

### Similarity functions

```sql
-- blocked: Docker not accessible
-- Similarity score: 0.0 (no match) to 1.0 (identical)
SELECT similarity('hello', 'helo');       -- 0.5714...
SELECT similarity('postgres', 'postgras');

-- Word similarity: best-matching substring
SELECT word_similarity('cat', 'the cat sat');   -- 1.0

-- Strict word similarity
SELECT strict_word_similarity('cat', 'the cat sat');
```

### Similarity operators

| Operator | Meaning | Default threshold |
|----------|---------|------------------|
| `%`      | `similarity() >= pg_trgm.similarity_threshold` | 0.3 |
| `<%`     | `word_similarity() >= pg_trgm.word_similarity_threshold` | 0.6 |
| `<<%`    | `strict_word_similarity() >= ...` | 0.5 |
| `<->` | Trigram distance (1 - similarity) | — (used in ORDER BY) |

```sql
-- blocked: Docker not accessible
-- Find names similar to "Jhon"
SELECT name FROM users WHERE name % 'Jhon';

-- Order by closeness
SELECT name, name <-> 'Jhon' AS dist
FROM users
ORDER BY dist
LIMIT 10;
```

### Tune the threshold

```sql
-- blocked: Docker not accessible
SET pg_trgm.similarity_threshold = 0.4;
-- Now % requires ≥ 0.4 similarity
```

### Fast LIKE/ILIKE with trigram index

```sql
-- blocked: Docker not accessible
-- Without index, LIKE '%pattern%' is O(n). With GIN trigram index, it becomes fast.
CREATE INDEX idx_users_name_trgm ON users USING GIN (name gin_trgm_ops);

-- This now uses the index
SELECT * FROM users WHERE name ILIKE '%johnsn%';
SELECT * FROM users WHERE name ~ 'john';
```

### show_trgm — inspect tokens

```sql
-- blocked: Docker not accessible
SELECT show_trgm('hello');
-- {"  h"," he","ell","hel","llo","lo "}
```

## Index types

### GIN with `gin_trgm_ops`

```sql
-- blocked: Docker not accessible
CREATE INDEX ON users USING GIN (name gin_trgm_ops);
```

- Best for: `LIKE`, `ILIKE`, `~`, `%` operator queries
- Fast build, slightly larger index size
- Supports concurrent updates well
- Recommended for most use cases

### GiST with `gist_trgm_ops`

```sql
-- blocked: Docker not accessible
CREATE INDEX ON users USING GiST (name gist_trgm_ops);
```

- Best for: `ORDER BY similarity(col, 'x') LIMIT n` — index-only nearest-neighbor scan
- Slower build, smaller index size than GIN
- Better when queries are mainly similarity-ordered fetches, not filter-only

### Choosing GIN vs GiST

| Criterion | GIN | GiST |
|-----------|-----|------|
| `LIKE`/`ILIKE`/regex filter | Fast | Slower |
| ORDER BY similarity LIMIT n | Must filter first | Native NN scan |
| Index size | Larger | Smaller |
| Build time | Faster | Slower |
| Update cost | Lower | Higher |

## Performance characteristics

- Trigram similarity is O(|s1| + |s2|) for computation
- GIN index lookup is logarithmic in unique trigram count
- Short strings (< 3 chars) have no trigrams — no index benefit; fall back to seq scan
- Very short search terms (< 3 chars) bypass the index; handle with a fallback or prefix index
- `pg_trgm.similarity_threshold` affects how many rows pass the `%` filter

## When to use

- User-facing search boxes where typos are expected (names, product titles, addresses)
- Autocomplete: `word_similarity` finds prefix-partial matches
- Deduplication: find near-duplicate records before an INSERT
- Speeding up `LIKE '%...%'` patterns that cannot use a btree index
- Entity matching across data sources with inconsistent spelling

## When NOT to use

- Exact keyword or phrase search — use `tsvector` / `to_tsquery` (full-text search)
- Accent-insensitive search — combine with `unaccent` extension
- Numeric or structured data similarity
- Very short tokens (< 3 chars) where trigrams don't exist
- High-cardinality columns with constantly changing data (GIN index maintenance cost)

## Alternatives

| Alternative | When to prefer |
|-------------|---------------|
| `tsvector` / `tsquery` | Language-aware full-text search with stemming and ranking |
| `fuzzystrmatch` | Phonetic matching (Soundex, Levenshtein distance) |
| `unaccent` | Strip accents before similarity comparison |
| Elasticsearch | Large-scale, multilingual, faceted search |
| Meilisearch | Simpler ops, typo tolerance built-in |

## MCP and agent perspective

- **Input normalization**: before looking up a user-provided entity name, run it through a trigram similarity query to find the canonical form in the database — prevents "no results" from minor typos
- **Fuzzy entity matching**: when merging data from an external API, use `%` to find existing records that are probably the same entity
- **Safe pattern**: always index the column with `gin_trgm_ops` before agents run fuzzy queries at scale; unindexed trigram scans on large tables are expensive
- Agents should log the `similarity()` score alongside the matched result so callers can evaluate confidence

## Ontology connection

- Pairs with `unaccent` (strip accents before trigram comparison) and `citext` (case-insensitive column type)
- Related to `fuzzystrmatch` — complementary: trigram is set-based similarity, fuzzystrmatch is edit-distance or phonetic
- Connects to full-text search (`tsvector`) — different approach; can be combined for best-of-both search

## References

- [PostgreSQL pg_trgm docs](https://www.postgresql.org/docs/16/pgtrgm.html)
- [PostgreSQL full-text search](https://www.postgresql.org/docs/16/textsearch.html)
- [Choosing between GIN and GiST](https://www.postgresql.org/docs/16/textsearch-indexes.html)
