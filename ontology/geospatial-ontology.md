# Geospatial Ontology

Level: Advanced
Domain: PostgreSQL / Extensions / Geospatial

## Definition
Geospatial data in PostgreSQL is handled primarily by the PostGIS extension, which adds geometry and geography column types, spatial reference systems, spatial indexes, and hundreds of spatial functions for distance, containment, and intersection queries.

## Why this concept matters
Location is a dimension of nearly every real-world domain — logistics, retail, real estate, public health. PostgreSQL with PostGIS is a production-grade spatial database, eliminating the need for a separate GIS system. Understanding spatial types and indexes prevents the common mistake of doing geospatial math in application code.

Note: PostGIS is not available in this local environment. All SQL is marked accordingly.

## Related concepts
- [[extension-ontology]] — parent (PostGIS is an extension)
- [[index-ontology]] — parent (GiST indexes power spatial queries)
- [[schema-design-ontology]] — related (geometry/geography as column types)
- [[performance-ontology]] — related (spatial index tuning)

---

## Geometry

One-line definition: A PostGIS data type representing a 2D (or 3D) shape in a flat, projected coordinate system; operations are computed using Euclidean distance in the projection's units (meters, feet, degrees).

```sql
-- blocked: Docker not accessible (PostGIS not available locally)
CREATE EXTENSION postgis;

CREATE TABLE locations (
    id       BIGSERIAL PRIMARY KEY,
    name     TEXT,
    geom     geometry(Point, 4326)  -- SRID 4326 = WGS84
);

INSERT INTO locations (name, geom)
VALUES ('Eiffel Tower', ST_GeomFromText('POINT(2.2945 48.8584)', 4326));
```

Geometry subtypes: `Point`, `LineString`, `Polygon`, `MultiPoint`, `MultiLineString`, `MultiPolygon`, `GeometryCollection`.

---

## Geography

One-line definition: A PostGIS data type for shapes on the Earth's curved surface (using WGS84 spheroid); distance calculations account for the Earth's curvature and return values in meters.

```sql
-- blocked: Docker not accessible
CREATE TABLE places (
    id       BIGSERIAL PRIMARY KEY,
    name     TEXT,
    location geography(Point, 4326)
);
```

When to use geometry vs geography:
| Use case | Type |
|---------|------|
| Small area, local projection, need speed | `geometry` |
| Global coordinates, need accurate distance in meters | `geography` |

---

## SRID (Spatial Reference Identifier)

One-line definition: A numeric code that identifies a coordinate reference system (projection and datum); stored with each geometry to ensure consistent spatial operations.

Common SRIDs:
| SRID | Name | Use |
|------|------|-----|
| 4326 | WGS84 geographic | GPS coordinates; global (latitude/longitude) |
| 3857 | Web Mercator | Web tile maps (Google Maps, OpenStreetMap) |
| 27700 | British National Grid | UK coordinates in meters |
| 32632 | UTM Zone 32N | Central Europe coordinates in meters |

```sql
-- blocked: Docker not accessible
-- Look up an SRID
SELECT srid, srtext FROM spatial_ref_sys WHERE srid = 4326;

-- Convert between SRIDs
SELECT ST_Transform(geom, 3857) FROM locations WHERE id = 1;
```

---

## WGS84

One-line definition: World Geodetic System 1984 — the global coordinate reference system used by GPS; SRID 4326; coordinates are longitude (X) and latitude (Y) in decimal degrees.

Note: In PostGIS, WGS84 coordinates are `(longitude, latitude)` — the order is X then Y, which is the opposite of the common conversational order "lat, lon".

---

## Spatial Index

One-line definition: A GiST index over geometry or geography columns that stores bounding boxes in an R-tree structure, enabling fast spatial filtering without computing exact geometry relationships.

```sql
-- blocked: Docker not accessible
CREATE INDEX idx_locations_geom ON locations USING GIST (geom);
CREATE INDEX idx_places_location ON places USING GIST (location);
```

How it works: Spatial queries first filter candidate rows using the bounding box index (fast), then compute the exact spatial relationship for the filtered candidates (precise). This two-step process is called the "filter-refine" strategy.

---

## Bounding Box

One-line definition: The smallest axis-aligned rectangle that entirely contains a geometry; used by the spatial index for fast overlap testing via the `&&` operator.

```sql
-- blocked: Docker not accessible
-- Bounding box overlap (index-accelerated)
SELECT * FROM locations WHERE geom && ST_MakeEnvelope(2.0, 48.5, 2.5, 49.0, 4326);
```

---

## Core Spatial Functions

### ST_Distance
One-line definition: Returns the minimum distance between two geometries; for `geography` type, returns meters on the Earth's surface.

```sql
-- blocked: Docker not accessible
-- Distance between two points (geography = meters)
SELECT ST_Distance(
    'SRID=4326;POINT(2.2945 48.8584)'::geography,
    'SRID=4326;POINT(-0.1276 51.5074)'::geography
) / 1000 AS distance_km;
```

### ST_Within
One-line definition: Returns true if geometry A is completely inside geometry B.

```sql
-- blocked: Docker not accessible
SELECT name FROM locations
WHERE ST_Within(geom, ST_GeomFromText('POLYGON((...))', 4326));
```

### ST_Intersects
One-line definition: Returns true if geometries share any point; the most general spatial relationship test; index-accelerated via bounding box pre-filter.

```sql
-- blocked: Docker not accessible
SELECT a.name, b.name
FROM regions a, regions b
WHERE ST_Intersects(a.geom, b.geom) AND a.id != b.id;
```

### ST_DWithin
One-line definition: Returns true if two geometries are within a specified distance of each other; for `geography`, distance is in meters; index-accelerated.

```sql
-- blocked: Docker not accessible
-- Find all locations within 5 km of a point
SELECT name
FROM locations
WHERE ST_DWithin(
    location,
    ST_GeographyFromText('POINT(2.2945 48.8584)'),
    5000  -- meters
);
```

### ST_Buffer
One-line definition: Returns a geometry expanded by a given distance (a "buffer zone" or ring).

### ST_Area
One-line definition: Returns the area of a polygon; for `geography`, returns square meters.

### ST_Centroid
One-line definition: Returns the geometric center of a geometry.

---

## Common Spatial Query Patterns

### Points within radius
```sql
-- blocked: Docker not accessible
SELECT id, name,
       ST_Distance(location, ST_GeographyFromText('POINT(lon lat)')) AS dist_m
FROM places
WHERE ST_DWithin(location, ST_GeographyFromText('POINT(lon lat)'), 1000)
ORDER BY dist_m
LIMIT 20;
```

### Polygon containment
```sql
-- blocked: Docker not accessible
SELECT p.name
FROM places p
JOIN neighborhoods n ON ST_Within(p.geom, n.geom)
WHERE n.name = 'Montmartre';
```

### K-nearest neighbors (KNN)
```sql
-- blocked: Docker not accessible
-- GiST supports KNN order by distance operator <->
SELECT name, geom <-> ST_GeomFromText('POINT(2.2945 48.8584)', 4326) AS dist
FROM locations
ORDER BY geom <-> ST_GeomFromText('POINT(2.2945 48.8584)', 4326)
LIMIT 10;
```

---

## System catalog reference
- `geometry_columns` — PostGIS view listing all geometry columns and their SRIDs
- `geography_columns` — PostGIS view for geography columns
- `spatial_ref_sys` — PostGIS table of all registered SRIDs
- `pg_am` — GiST appears as an index access method

---

## Beginner mental model
PostGIS adds "location awareness" to PostgreSQL. A geometry column stores a shape (point, line, polygon). A spatial index makes "find everything within 1 km" as fast as a regular B-tree lookup. Use `geography` when coordinates are GPS lat/lon and you want distances in meters; use `geometry` when you have a local projection.

## Intermediate mental model
Every spatial query has two phases: the index prunes candidates using bounding boxes (fast), then exact functions like ST_Within and ST_Intersects test the true geometry relationship (precise). Always create a GiST index on geometry/geography columns. Use `ST_DWithin` with a geography column for radius searches — it is index-accelerated and returns meters correctly.

## Advanced mental model
Coordinate order matters: PostGIS follows OGC convention (X=longitude, Y=latitude), which is the reverse of conversational "lat, lon". Always verify SRID before spatial operations — mixing SRIDs produces silent wrong results. For global datasets, `geography` handles polar distortion and antimeridian crossings correctly; `geometry` in EPSG:4326 does not. Raster data (satellite imagery, elevation models) is handled by the `postgis_raster` extension. Topology (shared borders, valid networks) uses the `topology` schema.

## MCP and agent perspective
An agent handling geospatial queries must validate that geometry columns have GiST indexes before issuing `ST_DWithin` or `ST_Intersects` queries. Without an index, spatial queries degrade to full table scans. Agents should check `geometry_columns` to discover the SRID of each geometry column before generating spatial SQL. For untrusted WKT input, use `ST_GeomFromText` (raises error on invalid geometry) rather than constructing raw WKT strings.

## Practical implication
| Situation | Implication |
|-----------|-------------|
| No GiST index on geometry column | Spatial queries scan every row; add USING GIST index |
| ST_Distance on geography in WHERE clause | Not index-accelerated; use ST_DWithin instead |
| Mixing SRID 4326 and 3857 in same join | Silent wrong results; always transform to same SRID first |
| Using geometry for global distance | Distance in degrees, not meters; use geography or transform to a metric projection |
| PostGIS not installed | `geometry` type unknown; all spatial functions error at parse time |

## Obsidian connections
[[extension-ontology]] [[index-ontology]] [[schema-design-ontology]] [[performance-ontology]]

## References
- PostGIS documentation: https://postgis.net/docs/
- Spatial Reference Systems: https://epsg.io
- PostGIS install: https://postgis.net/install/
