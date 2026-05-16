# PostGIS (postgis)

Level: Advanced
Available locally: **No — PostGIS is NOT installed in the `cfp_postgres` image (pgvector/pgvector:pg16). All SQL in this file is for reference only.**

## One-line purpose

Add full geospatial data types, spatial indexing, and hundreds of geometry/geography functions to PostgreSQL, making it a production-grade spatial database.

## Why this exists

Standard SQL has no concept of points, polygons, or spatial relationships. PostGIS follows the OGC Simple Features specification, adding:

- Geometry and geography column types
- Spatial reference systems (SRID/CRS)
- Spatial indexes (GiST on geometry)
- Functions for distance, containment, intersection, buffering, and coordinate transformation

It is the foundation of most open-source GIS stacks (QGIS, GeoServer, MapServer).

## Install

> **NOT AVAILABLE in cfp_postgres** — the local container uses `pgvector/pgvector:pg16` which does not include PostGIS. All SQL below is **blocked: PostGIS not available in cfp_postgres image**.

To use PostGIS, you would need an image such as `postgis/postgis:16-3.4`.

```sql
-- blocked: PostGIS not available in cfp_postgres image
CREATE EXTENSION IF NOT EXISTS postgis;
SELECT extname, extversion FROM pg_extension WHERE extname = 'postgis';
-- PostGIS version:
SELECT PostGIS_Full_Version();
```

## Core operations

### Geometry vs geography

| Type | Coordinates | Distance calculation | Use when |
|------|-------------|---------------------|----------|
| `geometry` | Planar (Cartesian) | Planar math (fast) | Local/regional data, projected CRS |
| `geography` | Spheroidal (lon/lat) | Great-circle (accurate) | Global data, lat/lng from GPS |

```sql
-- blocked: PostGIS not available in cfp_postgres image
CREATE TABLE locations (
    id       SERIAL PRIMARY KEY,
    name     TEXT,
    geom     geometry(Point, 4326),   -- WGS84 lon/lat
    geog     geography(Point, 4326)   -- spheroidal version
);

-- Insert a point (longitude first, then latitude)
INSERT INTO locations (name, geom, geog) VALUES (
    'Eiffel Tower',
    ST_SetSRID(ST_MakePoint(2.2945, 48.8584), 4326),
    ST_MakePoint(2.2945, 48.8584)::geography
);
```

### Key spatial functions

```sql
-- blocked: PostGIS not available in cfp_postgres image

-- Distance between two points (meters, using geography)
SELECT ST_Distance(
    'SRID=4326;POINT(2.2945 48.8584)'::geography,
    'SRID=4326;POINT(-0.1276 51.5074)'::geography
) AS distance_m;

-- Find all locations within 5 km of a point
SELECT name
FROM locations
WHERE ST_DWithin(
    geog,
    ST_MakePoint(2.2945, 48.8584)::geography,
    5000  -- meters
);

-- Containment: is a point inside a polygon?
SELECT name FROM regions
WHERE ST_Within(
    ST_MakePoint(2.2945, 48.8584)::geometry,
    region_boundary
);

-- Intersection: do two geometries overlap?
SELECT a.name, b.name
FROM regions a, regions b
WHERE a.id <> b.id
  AND ST_Intersects(a.boundary, b.boundary);

-- Buffer: create a polygon 500m around a point
SELECT ST_Buffer(geog, 500)
FROM locations
WHERE name = 'Eiffel Tower';

-- Area of a polygon in square meters
SELECT ST_Area(boundary::geography) AS area_sqm
FROM regions;
```

### Spatial indexes

```sql
-- blocked: PostGIS not available in cfp_postgres image
-- GiST index on geometry — required for spatial query performance
CREATE INDEX idx_locations_geom ON locations USING GiST (geom);
CREATE INDEX idx_locations_geog ON locations USING GiST (geog);

-- Bounding-box operators (use index)
-- && = bounding boxes overlap
SELECT * FROM locations WHERE geom && ST_MakeEnvelope(-5, 44, 10, 52, 4326);
```

### WKT and GeoJSON interop

```sql
-- blocked: PostGIS not available in cfp_postgres image
-- Well-Known Text
SELECT ST_AsText(geom) FROM locations;      -- 'POINT(2.2945 48.8584)'

-- GeoJSON — useful for API responses
SELECT ST_AsGeoJSON(geom) FROM locations;
-- {"type":"Point","coordinates":[2.2945,48.8584]}

-- Parse GeoJSON input
SELECT ST_GeomFromGeoJSON('{"type":"Point","coordinates":[2.2945,48.8584]}');
```

## Index types (spatial)

| Index | Operator class | Notes |
|-------|---------------|-------|
| GiST | default for geometry/geography | Supports `&&`, `ST_DWithin`, `ST_Intersects` |
| BRIN | `geometry_inclusion_minmax_multi_ops` | Very small; good for spatially sorted data |
| SP-GiST | — | Quad-tree; useful for point data |

Always create a GiST index on geometry/geography columns used in spatial queries. Without it, every spatial function call does a full table scan.

## Performance characteristics

- `ST_Distance` on `geography` uses spheroidal math — accurate but ~10x slower than planar `geometry`
- `ST_DWithin` with a GiST index is the canonical radius-search pattern (faster than `ST_Distance < n`)
- Bounding-box prefilter (`&&`) happens first in the index; exact geometry test happens after
- For read-heavy geo APIs, partition by region or tile to keep index scans narrow
- `CLUSTER` on the GiST index improves locality for range queries

## When to use

- Store and query GPS coordinates, addresses, routes, or polygons
- Radius search ("find restaurants within 2 km")
- Administrative boundary queries ("which country/state does this point fall in?")
- Route and network analysis (with `pgRouting`)
- Spatial joins between datasets (intersecting polygons, containment)

## When NOT to use

- Simple lat/lng storage with no spatial queries — use two `NUMERIC` columns
- pgvector-style similarity over geographic clusters — use clustering in application layer
- Very large raster/imagery datasets — use specialized GIS tools
- When the cfp_postgres container is in use (not available there)

## Alternatives

| Alternative | When to prefer |
|-------------|---------------|
| `earthdistance` + `cube` | Simple great-circle distance without PostGIS; available locally |
| External GIS service (Google Maps API, Mapbox) | Routing, geocoding, map rendering |
| pgRouting | Network/routing analysis on top of PostGIS |
| DuckDB spatial | Lightweight analytics on geo data |

## MCP and agent perspective

- **Location-based queries**: agents serving location-aware features use `ST_DWithin` for radius search — always index the geography column
- **Radius search pattern**: `WHERE ST_DWithin(geog, ST_MakePoint($lon, $lat)::geography, $radius_m)` — parameterize all three values; never interpolate coordinates into SQL strings
- **Response format**: use `ST_AsGeoJSON()` to serialize geometry for API responses; do not expose raw WKT to clients unless specifically requested
- Agents must validate that coordinate inputs are within valid ranges (lon: -180 to 180, lat: -90 to 90) before constructing geometry to avoid silent wraparound errors

## Ontology connection

- PostGIS is the spatial pillar of the extension map; `earthdistance` + `cube` are the lightweight local alternative
- Connects to: `pg_stat_statements` (monitor slow spatial queries), GiST indexes (shared index type with `btree_gist`, `ltree`), `uuid-ossp` (location record IDs)
- Concept map: geometry types → spatial indexes (GiST) → spatial joins → topological relationships

## References

- [PostGIS documentation](https://postgis.net/docs/manual-3.4/)
- [PostGIS function reference](https://postgis.net/docs/reference.html)
- [OGC Simple Features](https://www.ogc.org/standards/sfa)
- [pgRouting](https://pgrouting.org/)
- [PostGIS Docker image](https://hub.docker.com/r/postgis/postgis)
