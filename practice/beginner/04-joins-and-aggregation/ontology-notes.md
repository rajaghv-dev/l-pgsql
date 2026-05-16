# Ontology Notes: JOINs and Aggregation

These notes map the concepts in this practice session to the broader PostgreSQL concept graph.

---

## Concept map

```
relation (table / view / query result)
  └── JOIN operation (binary — takes two relations)
        ├── INNER JOIN  → intersection of matched rows
        │     └── requires: matching condition (usually FK = PK)
        ├── LEFT JOIN   → all left rows + NULLs for unmatched right
        │     └── enables: anti-join pattern (WHERE right.pk IS NULL)
        └── result IS A relation (can be JOINed again)

aggregation
  └── GROUP BY → partition rows into groups
        └── aggregate function (per group)
              ├── COUNT(*) / COUNT(col)
              ├── SUM(col)
              ├── AVG(col)
              ├── MIN(col) / MAX(col)
              └── HAVING → filter groups (WHERE for groups)
```

---

## Concept definitions

| Concept | Definition | Parent concept | Child concepts |
|---------|-----------|----------------|----------------|
| INNER JOIN | Combine rows with a match in both tables | JOIN | — |
| LEFT JOIN | All left rows; NULLs for unmatched right rows | JOIN | anti-join pattern |
| anti-join | Find left rows with no match in right | LEFT JOIN | — |
| GROUP BY | Partition rows into groups by column value | aggregation | aggregate functions |
| HAVING | Filter groups after aggregation | GROUP BY | — |
| COUNT(*) | Count of rows in a group (includes NULLs) | aggregate function | — |
| AVG(col) | Mean of non-NULL values in a group | aggregate function | — |
| COALESCE | Return first non-NULL value in a list | NULL handling | — |

---

## Key relationships

- **INNER JOIN IS A** JOIN that implements relational intersection (rows matching on both sides).
- **LEFT JOIN IS A** JOIN that implements left outer join (left rows always present).
- **GROUP BY REQUIRES** at least one aggregate function or all selected columns to be in the GROUP BY list.
- **HAVING REQUIRES** GROUP BY to be present (or is equivalent to WHERE on a grouped query).
- **COUNT(*) CONTRASTS WITH** COUNT(col): COUNT(*) counts all rows; COUNT(col) skips NULLs.
- **INNER JOIN CONTRASTS WITH** LEFT JOIN: INNER excludes non-matching left rows; LEFT includes them.
- **WHERE CONTRASTS WITH** HAVING: WHERE filters rows before grouping; HAVING filters groups after.

---

## Obsidian graph links

- `[[inner-join]]`
- `[[left-join]]`
- `[[anti-join]]`
- `[[group-by]]`
- `[[having]]`
- `[[aggregate-function]]`
- `[[foreign-key]]`
- `[[null-handling]]`
- `[[coalesce]]`
- `[[relation]]`

---

## Questions for deeper concept mapping

1. Is a JOIN result a relation? (Yes — can you JOIN a JOIN result with another table? Try it.)
2. What concept is logically upstream of JOIN? (The FK relationship that makes the join meaningful.)
3. What concepts does JOIN make possible downstream? (Aggregations across multiple tables, anti-joins, self-joins, hierarchical queries.)
