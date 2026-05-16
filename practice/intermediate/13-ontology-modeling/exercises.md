# Exercises — Ontology-Driven Schema Design

**Status: blocked — Docker not accessible in this session**

## Exercise 1: Traverse the topic hierarchy (ltree)

```sql
-- blocked: Docker not accessible

-- All descendants of 'tech.db' (database topics)
SELECT name, path FROM topics
WHERE path <@ 'tech.db'
ORDER BY path;

-- Ancestors of 'tech.db.postgres.perf'
SELECT name, path FROM topics
WHERE path @> 'tech.db.postgres.perf'
ORDER BY path;

-- All talks in the 'tech.db.postgres' subtopic
SELECT t.title, top.name AS topic, top.path
FROM talks t
JOIN topics top ON t.topic_id = top.id
WHERE top.path <@ 'tech.db.postgres'
ORDER BY top.path;
```

## Exercise 2: FTS search on talks

```sql
-- blocked: Docker not accessible

-- Full-text search
SELECT title, ts_rank(search_vector, q) AS rank
FROM talks, to_tsquery('english', 'postgres & optimization') AS q
WHERE search_vector @@ q
ORDER BY rank DESC;

-- User-input search
SELECT title
FROM talks
WHERE search_vector @@ websearch_to_tsquery('english', 'pgvector RAG embedding');
```

## Exercise 3: Vector similarity search

```sql
-- blocked: Docker not accessible

-- Find talks most similar to the performance talk
SELECT t2.title,
       t1.embedding <=> t2.embedding AS cosine_dist
FROM talks t1
CROSS JOIN talks t2
WHERE t1.title = 'PostgreSQL Query Optimization Deep Dive'
  AND t1.id != t2.id
ORDER BY cosine_dist;

-- Semantic search with a query vector
SELECT title, embedding <=> '[0.11, 0.80, 0.35]'::vector AS dist
FROM talks
ORDER BY embedding <=> '[0.11, 0.80, 0.35]'::vector
LIMIT 3;
```

## Exercise 4: Multi-hop relationship query

```sql
-- blocked: Docker not accessible

-- For each conference, list all accepted speakers with their talk topics
SELECT
    c.name AS conference,
    s.full_name AS speaker,
    t.title AS talk,
    top.name AS topic,
    pr.role
FROM conferences c
JOIN talks t ON t.conference_id = c.id
JOIN presentation_roles pr ON pr.talk_id = t.id
JOIN speakers s ON pr.speaker_id = s.id
LEFT JOIN topics top ON t.topic_id = top.id
WHERE t.status = 'accepted'
ORDER BY c.name, s.full_name;
```

## Exercise 5: Inspect the ontological graph (FK structure)

```sql
-- blocked: Docker not accessible

-- Which tables reference which (the ontological graph)
SELECT
    tc.table_name AS child_entity,
    kcu.column_name AS via_column,
    ccu.table_name AS parent_entity
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY child_entity;
```

## Exercise 6: JSONB bio_data queries

```sql
-- blocked: Docker not accessible

-- Find speakers who specialize in PostgreSQL
SELECT full_name, bio_data ->> 'company' AS company
FROM speakers
WHERE bio_data @> '{"specialties": ["PostgreSQL"]}';

-- Extract specialties as rows
SELECT s.full_name, spec
FROM speakers s,
     jsonb_array_elements_text(bio_data -> 'specialties') AS spec
ORDER BY s.full_name, spec;

-- Speakers with more than 6 years experience
SELECT full_name, (bio_data ->> 'years_experience')::int AS yoe
FROM speakers
WHERE (bio_data ->> 'years_experience')::int > 6;
```

## Exercise 7: Ontology consistency check

```sql
-- blocked: Docker not accessible

-- Orphan check: talks with no presenter
SELECT t.title, t.status
FROM talks t
WHERE NOT EXISTS (
    SELECT 1 FROM presentation_roles pr WHERE pr.talk_id = t.id
);

-- Consistency check: accepted talks should have an accepted submission
SELECT t.title
FROM talks t
WHERE t.status = 'accepted'
  AND NOT EXISTS (
    SELECT 1 FROM submissions s
    WHERE s.talk_id = t.id AND s.decision = 'accepted'
);
```

## Reflection questions
1. Why is `submissions` an event table rather than a column on `talks`?
2. What is the ontological difference between `presentation_roles` and `submissions`?
3. Why is `bio_data` stored as JSONB on `speakers` rather than typed columns?
4. How would you model a speaker giving the same talk at two different conferences?
