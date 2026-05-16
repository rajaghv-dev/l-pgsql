# Reference Entry Template

> **How to use this template:**
> Use this format when adding entries to `references.md` (root-level) or to
> `practice/<level>/<topic>/references.md` files.
>
> Each entry follows the table row format below.
> Before adding a reference, verify the URL is accessible and free.
> If you cannot verify a URL, write `TODO: Find verified reference for this topic.` instead.

---

## Table format

Add rows to the relevant `references.md` table in this format:

```markdown
| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|-----------|
| <!-- title --> | <!-- URL --> | <!-- type --> | <!-- level --> | <!-- time --> | <!-- why --> |
```

---

## Field definitions

### Title

The exact title of the resource as it appears on the page.
Do not shorten or paraphrase.

Example: `PostgreSQL Documentation — Row Security Policies`

---

### URL

The full, verified URL. Must be free to access. No paywalls.

Preferred domains (in order):
1. `https://www.postgresql.org/docs/` — official PostgreSQL documentation
2. `https://wiki.postgresql.org/` — PostgreSQL wiki
3. `https://www.postgresqltutorial.com/` — practical tutorials
4. `https://www.interdb.jp/pg/` — free internals book (The Internals of PostgreSQL)
5. `https://use-the-index-luke.com/` — free indexing book
6. `https://pgpedia.info/` — encyclopedia of PostgreSQL terms
7. High-quality engineering blogs: Cybertec, pganalyze, Brandur, Craig Kerstiens, 2ndQuadrant/EDB
8. GitHub repositories with runnable examples
9. Short YouTube videos under 15 minutes (verify free, not behind membership)

Avoid:
- SEO-driven content farms
- Medium articles without technical depth
- Fabricated or hallucinated URLs — if unsure, do not add it

---

### Type

Classify the resource type:

| Type value | Meaning |
|------------|---------|
| `Official docs` | postgresql.org/docs or extension's official docs |
| `Free book` | A complete free book (interdb.jp, use-the-index-luke, etc.) |
| `Tutorial` | A structured tutorial (postgresqltutorial.com, etc.) |
| `Blog` | A technical blog post |
| `Video` | A free YouTube or conference video |
| `Repo` | A GitHub or GitLab repository with runnable examples |
| `Wiki` | PostgreSQL wiki or similar community wiki |
| `Paper` | A research paper or formal specification |

---

### Level

| Level value | Meaning |
|-------------|---------|
| `Beginner` | Assumes no prior PostgreSQL knowledge |
| `Intermediate` | Assumes basic SQL and schema design knowledge |
| `Advanced` | Assumes understanding of EXPLAIN, MVCC, and production systems |
| `All` | Useful at any level |

---

### Time

Estimated reading or viewing time. Use:
- `5 min` / `10 min` / `15 min` / `20 min` / `30 min`
- `1 hr` / `2 hr` / `4 hr` / `Self-paced`

Be honest — overestimating is better than underestimating.

---

### Why useful

One sentence explaining what this reference adds that others don't.
Focus on the specific concept it clarifies or the specific skill it builds.

Example: `"The only free resource that shows live EXPLAIN ANALYZE output for every index type with annotated plans."`

---

## Complete entry examples

### Official docs entry

```markdown
| PostgreSQL docs — Row Security Policies | https://www.postgresql.org/docs/current/ddl-rowsecurity.html | Official docs | Intermediate | 20 min | Complete reference for RLS syntax, policy types, and security definer behavior |
```

### Free book entry

```markdown
| The Internals of PostgreSQL — Chapter 5 (Buffer Manager) | https://www.interdb.jp/pg/pgsql05.html | Free book | Advanced | 1 hr | The definitive free explanation of shared_buffers, clock-sweep eviction, and dirty page flushing |
```

### Blog entry

```markdown
| Use The Index, Luke — Index-Only Scans | https://use-the-index-luke.com/sql/clustering/index-only-scan-covering-index | Free book | Intermediate | 15 min | Visual, database-agnostic explanation of covering indexes with PostgreSQL examples |
```

### Video entry

```markdown
| Postgres EXPLAIN Visualizer — PEV2 demo | https://explain.dalibo.com/ | Repo | All | 5 min | Interactive tool for visualizing EXPLAIN (FORMAT JSON) output — paste a plan and see it as a tree |
```

---

## Missing reference protocol

If you need a reference for a topic but cannot find a verified free one:

```markdown
| TODO: Find verified reference for <!-- topic --> | — | — | <!-- level --> | — | Needed for <!-- specific concept or exercise --> |
```

Never invent a title or URL. A missing entry is better than a fabricated one.

---

## Bulk example: references.md table for a practice session

```markdown
# References: <!-- Topic Name -->

| Title | URL | Type | Level | Time | Why useful |
|-------|-----|------|-------|------|-----------|
| PostgreSQL docs — <!-- topic --> | https://www.postgresql.org/docs/current/<!-- page --> | Official docs | <!-- level --> | 15 min | <!-- why --> |
| <!-- title 2 --> | <!-- URL 2 --> | <!-- type 2 --> | <!-- level 2 --> | <!-- time 2 --> | <!-- why 2 --> |
| <!-- title 3 --> | <!-- URL 3 --> | <!-- type 3 --> | <!-- level 3 --> | <!-- time 3 --> | <!-- why 3 --> |

---

## Further reading

- `concepts/<!-- level -->/<!-- next-lesson -->` — <!-- why next -->
```
