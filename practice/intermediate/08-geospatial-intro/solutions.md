# Solutions — Geospatial Intro with PostGIS

**Status: blocked — PostGIS not available in cfp_postgres**

## Exercise 1 solution (conceptual)
`ST_MakePoint(lng, lat)` creates a geometry with no SRID. Cast to `::geography` for spherical calculations. `ST_AsText` returns OGC WKT (Well-Known Text); `ST_AsGeoJSON` returns RFC 7946 GeoJSON — use this for API responses and web map libraries (Leaflet, Mapbox).

## Exercise 2 solution (conceptual)
The Haversine formula computes great-circle distance on a sphere. PostGIS `geography` type uses this for `ST_Distance`. SF to LA: ~559km along the curved Earth surface.

If you used `geometry` (flat-Earth): `sqrt((lng1-lng2)^2 + (lat1-lat2)^2)` would give ~5.1 "degrees" — meaningless without proper projection. This is why `geography` is always correct for GPS coordinates.

## Exercise 3 solution (conceptual)
Expected results:
- Store SF: 0 km (the reference point itself)
- Store LA: ~559 km (within 600km)
- Store NYC and CHI: >2000 km (excluded)

The GiST index first finds bounding-box candidates, then applies exact `ST_Distance`. Without the index, every row would require a full spherical distance computation.

## Exercise 4 solution (conceptual)
KNN using `<->` in ORDER BY with LIMIT pushes the sort into the GiST index — PostgreSQL uses an index scan that returns rows in distance order, stopping after LIMIT rows. This avoids computing distance for all rows.

Result: Store CHI (0km), Store NYC (~1270km), Store LA (~2800km).

## Conceptual exercise solutions

**CE2:** `geometry` uses Euclidean math in the coordinate plane. For NY (-74, 40) to London (-0.1, 51), the Euclidean distance in "degrees" is sqrt(74^2 + 11^2) ≈ 74.8 — meaningless. `geography` computes the great-circle distance: ~5,570 km. The difference grows with distance from the equator and across meridians.

**CE3 — Delivery schema:**
```sql
-- blocked: PostGIS not available in cfp_postgres
CREATE TABLE restaurants (
    id       SERIAL PRIMARY KEY,
    name     TEXT,
    location GEOGRAPHY(POINT, 4326)
);
CREATE TABLE delivery_zones (
    id            SERIAL PRIMARY KEY,
    restaurant_id INT REFERENCES restaurants(id),
    zone          GEOMETRY(POLYGON, 4326)
);
CREATE TABLE orders (
    id              SERIAL PRIMARY KEY,
    restaurant_id   INT,
    delivery_address GEOGRAPHY(POINT, 4326)
);

-- Is customer in delivery zone?
SELECT r.name
FROM restaurants r
JOIN delivery_zones dz ON r.id = dz.restaurant_id
WHERE ST_Within(
    customer_location::geometry,
    dz.zone
);
```

## Reflection answers
1. `GEOGRAPHY` uses spheroidal Earth model (WGS84 ellipsoid). `GEOMETRY` assumes flat plane — correct only for small areas within a properly projected coordinate system. For any real-world use spanning >10km, use `GEOGRAPHY`.
2. SRID 4326 = EPSG 4326 = WGS84 geographic coordinate system. It is the standard used by GPS, OpenStreetMap, Google Maps, and all geospatial interchange formats. "GPS coordinates" are always WGS84.
3. PostgreSQL's GiST index supports "index-based KNN scans" for the `<->` operator. The index can return rows in distance order without sorting the full result set — a tree-walk that stops when LIMIT is reached.
4. PostGIS is better when: location data lives in your database, you need transactional consistency between spatial and relational data, you do polygon/boundary analysis, and you want to avoid external API costs and network latency. External services (Google Maps) are better for: geocoding, routing, real-time traffic, map rendering, and very high request volumes.
