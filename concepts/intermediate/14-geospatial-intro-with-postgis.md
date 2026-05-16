# Geospatial Intro with PostGIS
Level: Intermediate

## Status: TODO — PostGIS not available in cfp_postgres image
All SQL in this concept file is marked as "blocked: PostGIS not available in cfp_postgres". The conceptual content is complete. Run SQL when a PostGIS-enabled instance is available.

---

## One-line intuition
PostGIS extends PostgreSQL with geometry and geography types plus hundreds of spatial functions, turning it into a full GIS database capable of proximity search, containment checks, and map rendering.

## Why this exists
Location data is ubiquitous: delivery addresses, store locations, user check-ins, sensor positions. Standard SQL has no concept of "within 5km" or "contains this polygon". PostGIS adds these natively, replacing external GIS systems for most practical use cases.

## First-principles explanation
PostGIS introduces two type families:

**geometry** — Euclidean (flat-earth) coordinates in any coordinate reference system (CRS). Operations assume straight lines.

**geography** — Spheroidal (round-earth) coordinates in WGS84 (longitude/latitude). Operations account for Earth's curvature; distances are in meters.

Common geometry subtypes (OGC WKT standard):
- `POINT(lng lat)` — a single location
- `LINESTRING(x1 y1, x2 y2, ...)` — a path
- `POLYGON((x1 y1, x2 y2, ...))` — an area (first and last point must be equal)
- `MULTIPOLYGON(...)` — multiple polygons (city districts, island groups)

**Key spatial functions:**

| Function | Description |
|---|---|
| `ST_Distance(a, b)` | Distance between geometries |
| `ST_DWithin(a, b, d)` | True if within distance d |
| `ST_Within(a, b)` | True if a is completely within b |
| `ST_Intersects(a, b)` | True if geometries overlap |
| `ST_Contains(a, b)` | True if b is inside a |
| `ST_Area(a)` | Area of polygon |
| `ST_Buffer(a, d)` | Polygon of distance d around a |
| `ST_AsGeoJSON(a)` | Serialize to GeoJSON |
| `ST_GeomFromGeoJSON(json)` | Deserialize from GeoJSON |

**Spatial indexes:** PostGIS uses GiST (Generalized Search Tree) with R-tree structure. The `&&` bounding-box overlap operator uses this index. Most spatial functions internally use `&&` for index pruning before exact computation.

## Micro-concepts
- **SRID** — Spatial Reference ID; 4326 = WGS84 (GPS coordinates), 3857 = Web Mercator (map tiles)
- **GiST spatial index** — R-tree implementation for bounding-box-first filtering
- **ST_MakePoint(lng, lat)** — construct a point from coordinates
- **ST_SetSRID(geom, srid)** — assign a coordinate reference system to a geometry
- **KNN query** — K-nearest neighbors using `ORDER BY geom <-> ST_MakePoint(lng, lat) LIMIT K`
- **Geocoding** — converting addresses to coordinates (requires external service: Nominatim, Google)
- **Reverse geocoding** — coordinates to address

## Beginner view
PostGIS is like adding a map layer to your database. Instead of storing "San Francisco", you store the exact GPS coordinates, and then you can ask "show me all coffee shops within 1km of my location" as a database query.

## Intermediate view
For "nearby" queries, use `geography` type and `ST_DWithin(location, reference_point, meters)` — this uses the spatial GiST index and handles Earth's curvature. For map boundary containment ("is this point inside this city polygon?"), use `ST_Within` with the city's boundary geometry.

Always index geography/geometry columns:
```sql
-- blocked: PostGIS not available in cfp_postgres
CREATE INDEX ON locations USING gist(geom);
```

## Advanced view
Performance-critical geospatial queries use the `<->` distance operator for KNN directly in the `ORDER BY` clause — this pushes the ordering into the GiST index scan (index-based KNN). This avoids materializing all candidates and computing exact distances before sorting.

Bounding-box queries (using `&&`) are cheaper than exact spatial queries — filter by bounding box first (using the index), then apply exact spatial predicates to the smaller candidate set.

## Mental model
Think of a spatial index as a hierarchical grid of bounding boxes. The outer box covers the whole world; inner boxes subdivide it recursively. A "within 1km" query finds the smallest boxes that overlap the search radius, then checks exact geometry only for rows within those boxes. This is the GiST R-tree.

## PostgreSQL view (blocked: PostGIS not available in cfp_postgres)
```sql
-- blocked: PostGIS not available in cfp_postgres

-- Install PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Table of store locations
CREATE TABLE stores (
    id       SERIAL PRIMARY KEY,
    name     TEXT NOT NULL,
    location GEOGRAPHY(POINT, 4326)  -- WGS84
);

CREATE INDEX ON stores USING gist(location);

-- Insert stores (longitude, latitude)
INSERT INTO stores (name, location) VALUES
    ('Store A', ST_MakePoint(-122.4194, 37.7749)::geography),  -- San Francisco
    ('Store B', ST_MakePoint(-118.2437, 34.0522)::geography);  -- Los Angeles

-- Find stores within 10km of a point
SELECT name, ST_Distance(location, ST_MakePoint(-122.40, 37.78)::geography) AS dist_m
FROM stores
WHERE ST_DWithin(location, ST_MakePoint(-122.40, 37.78)::geography, 10000)
ORDER BY dist_m;

-- KNN: 5 nearest stores
SELECT name, location <-> ST_MakePoint(-122.40, 37.78)::geography AS dist
FROM stores
ORDER BY dist
LIMIT 5;

-- Polygon containment
SELECT s.name
FROM stores s, neighborhoods n
WHERE n.name = 'Mission District'
  AND ST_Within(s.location::geometry, n.boundary);

-- GeoJSON output
SELECT name, ST_AsGeoJSON(location) AS geojson FROM stores;
```

## SQL view (blocked: PostGIS not available in cfp_postgres)
PostGIS is PostgreSQL-specific. MySQL 8 has spatial types and functions (OGC-compliant). SQL Server has `GEOMETRY` and `GEOGRAPHY` types. Most PostGIS functions follow OGC Simple Features for SQL standard naming (ST_ prefix). GeoJSON (RFC 7946) is the standard interchange format.

## Non-SQL or hybrid view
PostGIS is often used alongside Elasticsearch geo_point fields: PostGIS for complex spatial analysis (polygon containment, route planning), Elasticsearch for fast proximity search in user-facing applications. Tile servers (Martin, pg_tileserv) read directly from PostGIS tables to serve vector map tiles.

## Design principle
**Use `geography` type for real-world coordinates (GPS data), `geometry` for projected/mapped coordinates.** Geography handles Earth's curvature correctly for distance calculations. Geometry is faster but assumes flat Earth — only appropriate for small areas or already-projected data. Always set SRID explicitly; a geometry without SRID has no coordinate meaning.

## Critical thinking (blocked: PostGIS not available in cfp_postgres)
- All SQL examples in this concept are untestable without PostGIS. Verify against a PostGIS-enabled environment.
- KNN queries using `<->` only use the index efficiently when no other WHERE clause interferes. Adding a non-spatial WHERE condition may prevent the index-based KNN scan.
- Geography distance calculations are slower than geometry because they involve trigonometric functions. For very large tables (>10M rows), consider pre-clustering by geohash.

## Creative thinking
Combine PostGIS with ltree for spatial-hierarchical queries: store a `region_path ltree` alongside each point's geometry. Use ltree for quick region-level filtering, then PostGIS for exact boundary checks. This hybrid avoids expensive spatial intersections for coarse-grained queries.

## Systems thinking
Geospatial data often comes from external sources (GPS devices, geocoding APIs) with varying precision and SRID conventions. Build an ingestion pipeline that normalizes all incoming coordinates to WGS84 (SRID 4326) before storage. Validate coordinate ranges (longitude -180 to 180, latitude -90 to 90) at ingestion time.

## MCP and agent perspective
An MCP agent handling location-aware queries should:
1. Accept coordinates from the user as `{lat, lng}` 
2. Construct `ST_MakePoint(lng, lat)::geography` with SRID 4326
3. Use `ST_DWithin` with appropriate radius in meters
4. Return results with distance in a human-friendly unit (km or miles)

PostGIS is not available in cfp_postgres — all geospatial agent features must wait for a PostGIS-enabled deployment.

## Ontology perspective
Geospatial entities are ontological objects with a spatial extent property. A `POINT` is a location (a property), not an entity itself. A `POLYGON` can be an entity (a neighborhood, a country) with identity, attributes, and relationships. The ontological distinction between "an entity that has a location" vs "a location that defines an entity" maps to PostGIS's distinction between a `location GEOGRAPHY` column on a `stores` table vs a `neighborhoods` table where the polygon IS the entity.

## Practice session
See `practice/intermediate/08-geospatial-intro/` — all SQL is blocked (PostGIS not available). Conceptual exercises included.

## References
- PostGIS documentation: https://postgis.net/docs/manual-3.4/
- PostGIS installation guide: https://postgis.net/install/
- OGC Simple Features standard: https://www.ogc.org/standard/sfa/
- "Introduction to PostGIS" (Boundless tutorial): https://postgis.net/workshops/postgis-intro/
- GeoJSON specification (RFC 7946): https://datatracker.ietf.org/doc/html/rfc7946
- pg_tileserv: https://github.com/CrunchyData/pg_tileserv
