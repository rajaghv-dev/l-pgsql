# Troubleshooting — Geospatial Intro with PostGIS

## PostGIS not available in cfp_postgres
**Status:** All spatial queries blocked in this environment.
**Resolution:** Use a PostGIS-enabled container:
```bash
docker pull postgis/postgis:16-3.4
docker run --name pg_geo -e POSTGRES_PASSWORD=secret -p 5433:5432 -d postgis/postgis:16-3.4
docker exec pg_geo psql -U postgres -c "CREATE DATABASE geo_practice;"
docker exec pg_geo psql -U postgres -d geo_practice -c "CREATE EXTENSION postgis;"
```

## ERROR: type "geography" does not exist
**Cause:** PostGIS extension not installed.
**Fix:** `CREATE EXTENSION postgis;` as superuser.

## ERROR: function st_distance does not exist
**Cause:** Same — PostGIS not installed, or wrong function signature.
**Fix:** Install PostGIS. Verify: `SELECT PostGIS_Version();`

## Distance calculation returns wrong result
**Cause:** Using `geometry` instead of `geography` for global coordinates.
**Fix:** Cast to `::geography`:
```sql
-- Wrong (Euclidean degrees, not meters):
ST_Distance(ST_MakePoint(-122.4, 37.7), ST_MakePoint(-118.2, 34.0))

-- Correct (spherical meters):
ST_Distance(
    ST_MakePoint(-122.4, 37.7)::geography,
    ST_MakePoint(-118.2, 34.0)::geography
)
```

## GiST index not used for spatial query
**Cause:** Index not created, or SRID mismatch between stored data and query geometry.
**Fix:**
```sql
-- Verify index exists:
SELECT indexname FROM pg_indexes WHERE tablename = 'stores';
-- Verify SRID consistency:
SELECT ST_SRID(location::geometry) FROM stores LIMIT 1;
-- Query point SRID must match stored SRID
```

## ST_Within returns false for a point that appears inside a polygon
**Cause:** SRID mismatch (point is in one CRS, polygon in another), or the point is exactly on the boundary (use `ST_Covers` for boundary-inclusive containment).
**Fix:** Ensure both geometries use the same SRID. Use `ST_SetSRID` to assign explicitly.

## Coordinates stored as lat/lng vs lng/lat
**Cause:** PostGIS convention is (longitude, latitude) — opposite of common "lat, lng" convention.
**Fix:** Always use `ST_MakePoint(longitude, latitude)`. Add a comment to your schema:
```sql
-- location GEOGRAPHY(POINT, 4326) -- stored as (longitude, latitude), WGS84
```
