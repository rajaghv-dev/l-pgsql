# Troubleshooting — Full-Text Search and Fuzzy Search

## ERROR: syntax error in tsquery
**Cause:** `to_tsquery` received invalid syntax (e.g., unbalanced parentheses, user-typed operators).
**Fix:** Use `websearch_to_tsquery` for user input — it never raises a syntax error.

## FTS returns no results for known terms
**Diagnosis:** Check what the tsvector actually contains:
```sql
SELECT to_tsvector('english', 'PostgreSQL performance tuning');
-- 'perform':2 'postgresql':1 'tune':3
```
Note: "PostgreSQL" → "postgresql" (lowercase), "tuning" → "tune" (stemmed).
**Fix:** Match the stemmed form or use `plainto_tsquery` which stems automatically.

## GIN index not used for FTS
**Cause:** Query uses `to_tsvector()` in WHERE instead of matching against a stored column.
```sql
-- No index:
WHERE to_tsvector('english', body) @@ q

-- Uses GIN index:
WHERE search_vector @@ q
```
Always use the stored/indexed `search_vector` column in the WHERE clause.

## pg_trgm similarity always 0
**Cause:** Extension not installed, or the strings have no shared trigrams.
```sql
SELECT show_trgm('hi');
-- Very short strings have few trigrams; similarity with any other short string will be low
```
**Fix:** Minimum useful string length for trigram similarity is ~4 characters.

## Fuzzy search returns too many false positives
**Symptom:** Similarity threshold too low; unrelated items returned.
**Fix:** Increase threshold per-session:
```sql
SET pg_trgm.similarity_threshold = 0.5;  -- stricter
```
Or use `word_similarity` which handles length disparities better.

## ts_headline returns empty or truncated excerpt
**Cause:** Body text is very short, or query terms don't appear in the body.
**Fix:** Adjust `ts_headline` options:
```sql
ts_headline('english', body, q, 'MaxWords=50, MinWords=20, MaxFragments=3')
```
`MaxFragments` allows multiple non-contiguous excerpts.

## Generated column for tsvector not updating
**Cause:** Generated columns with complex expressions may be slow on bulk updates.
**Note:** GENERATED ALWAYS AS STORED columns update automatically on every row change. If this is a performance concern, drop the generated column and use a trigger instead (more control over when updates fire).
