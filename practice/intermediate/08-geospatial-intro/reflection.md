# Reflection — Geospatial Intro with PostGIS

## Key takeaways (conceptual — PostGIS not available locally)
- PostGIS turns PostgreSQL into a full GIS database with hundreds of spatial functions.
- Use `GEOGRAPHY` for real-world coordinates; `GEOMETRY` for projected/pre-processed map data.
- GiST R-tree indexes make spatial queries fast (proximity, containment, KNN).
- `ST_DWithin` + GiST is the canonical pattern for "nearby" queries.
- `<->` in ORDER BY with LIMIT is the canonical pattern for KNN.

## How to get PostGIS locally
```bash
# Option 1: PostGIS Docker image
docker pull postgis/postgis:16-3.4
docker run --name pg_geo -e POSTGRES_PASSWORD=secret -p 5433:5432 -d postgis/postgis:16-3.4

# Option 2: Install PostGIS in existing container (requires superuser + build tools)
# Not practical for cfp_postgres without a custom image rebuild.
```

## PostGIS vs alternatives
| Approach | Pros | Cons |
|---|---|---|
| PostGIS | Transactional, SQL joins, full GIS | Large extension, complex setup |
| Google Maps API | Rich features, routing, geocoding | Cost, external dependency, latency |
| Elasticsearch geo | Fast, scalable, good for search | Separate system, eventual consistency |
| PostGIS + pg_tileserv | Self-hosted map tile server | More infrastructure |

## Connection to other concepts
- ltree for spatial hierarchies (administrative boundaries: country > region > city)
- pgvector for location-aware semantic search (nearby similar items)
- RLS for geo-fenced data access (users can only see data in their region)

## What to explore next
- Install PostGIS in a separate Docker container for hands-on practice
- "Introduction to PostGIS" workshop (boundless/crunchydata) — free online tutorial
- pg_tileserv: serve vector tiles directly from PostGIS tables
