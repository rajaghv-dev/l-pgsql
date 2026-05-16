# Exercises — Full-Text Search and Fuzzy Search

**Status: blocked — Docker not accessible in this session**

## Exercise 1: Basic FTS — tsquery operators

```sql
-- blocked: Docker not accessible

-- AND search
SELECT title FROM articles
WHERE search_vector @@ to_tsquery('english', 'postgres & performance');

-- OR search
SELECT title FROM articles
WHERE search_vector @@ to_tsquery('english', 'vacuum | transactions');

-- Phrase search (adjacent terms)
SELECT title FROM articles
WHERE search_vector @@ to_tsquery('english', 'row <-> level');

-- User-input-safe (no operator knowledge required)
SELECT title FROM articles
WHERE search_vector @@ websearch_to_tsquery('english', 'postgres full text search');

-- Plain query (literal phrase, no operators)
SELECT title FROM articles
WHERE search_vector @@ plainto_tsquery('english', 'query planning');
```

## Exercise 2: Ranked results with ts_rank

```sql
-- blocked: Docker not accessible

SELECT
    title,
    ts_rank(search_vector, q) AS rank
FROM articles,
     to_tsquery('english', 'postgres | database | query') AS q
WHERE search_vector @@ q
ORDER BY rank DESC;
```

## Exercise 3: Highlighted excerpts with ts_headline

```sql
-- blocked: Docker not accessible

SELECT
    title,
    ts_headline(
        'english',
        body,
        to_tsquery('english', 'index & performance'),
        'MaxWords=30, MinWords=15, StartSel=<<, StopSel=>>'
    ) AS excerpt
FROM articles
WHERE search_vector @@ to_tsquery('english', 'index & performance');
```

## Exercise 4: Fuzzy search with pg_trgm

```sql
-- blocked: Docker not accessible

-- Typo-tolerant title search
SELECT title, similarity(title, 'Posgress Performance') AS sim
FROM articles
WHERE title % 'Posgress Performance'
ORDER BY sim DESC;

-- Adjust threshold for stricter matching
SET pg_trgm.similarity_threshold = 0.2;
SELECT title, similarity(title, 'postresql') AS sim
FROM articles
WHERE title % 'postresql'
ORDER BY sim DESC;

-- Word similarity (query is a substring of title)
SELECT title, word_similarity('vacuum', title) AS wsim
FROM articles
WHERE 'vacuum' <% title
ORDER BY wsim DESC;
```

## Exercise 5: Combined FTS + fuzzy fallback

```sql
-- blocked: Docker not accessible

-- Try FTS first; fall back to trgm if no results
WITH fts_results AS (
    SELECT id, title, ts_rank(search_vector, q) AS score, 'fts' AS source
    FROM articles, websearch_to_tsquery('english', 'postresql vacuem') AS q
    WHERE search_vector @@ q
),
trgm_results AS (
    SELECT id, title, similarity(title, 'postresql vacuem') AS score, 'trgm' AS source
    FROM articles
    WHERE title % 'postresql vacuem'
      AND NOT EXISTS (SELECT 1 FROM fts_results)
)
SELECT * FROM fts_results
UNION ALL
SELECT * FROM trgm_results
ORDER BY score DESC
LIMIT 10;
```

## Exercise 6: Filtered search (FTS + tag)

```sql
-- blocked: Docker not accessible

SELECT a.title, ts_rank(a.search_vector, q) AS rank
FROM articles a
JOIN article_tags at ON a.id = at.article_id
JOIN tags t ON at.tag_id = t.id,
     to_tsquery('english', 'query | performance') AS q
WHERE a.search_vector @@ q
  AND t.name = 'performance'
ORDER BY rank DESC;
```

## Reflection questions
1. Why is `search_vector` a GENERATED ALWAYS AS STORED column instead of updating it via a trigger?
2. What is the difference between `ts_rank` and `ts_rank_cd`? When would you use coverage density?
3. Why should you use `websearch_to_tsquery` for user-provided input instead of `to_tsquery`?
4. Under what circumstances would `word_similarity` give better results than `similarity`?
