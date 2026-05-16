# Exercises — Geospatial Intro with PostGIS

**Status: blocked — PostGIS not available in cfp_postgres**
All SQL below is conceptually correct and would run on a PostGIS-enabled instance.

---

## Exercise 1: Basic geometry and geography types

```sql
-- blocked: PostGIS not available in cfp_postgres

-- Create a point (WGS84)
SELECT ST_MakePoint(-122.4194, 37.7749)::geography AS sf_location;

-- Display as WKT
SELECT ST_AsText(ST_MakePoint(-122.4194, 37.7749));
-- Returns: POINT(-122.4194 37.7749)

-- Display as GeoJSON
SELECT ST_AsGeoJSON(ST_MakePoint(-122.4194, 37.7749));
-- Returns: {"type":"Point","coordinates":[-122.4194,37.7749]}

-- Check the SRID
SELECT ST_SRID(ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326));
-- Returns: 4326
```

## Exercise 2: Distance calculation

```sql
-- blocked: PostGIS not available in cfp_postgres

-- Distance between San Francisco and Los Angeles in meters
SELECT ST_Distance(
    ST_MakePoint(-122.4194, 37.7749)::geography,
    ST_MakePoint(-118.2437, 34.0522)::geography
) AS dist_m;
-- Expected: ~559,000 meters (~559km)

-- In kilometers
SELECT ROUND(ST_Distance(
    ST_MakePoint(-122.4194, 37.7749)::geography,
    ST_MakePoint(-118.2437, 34.0522)::geography
) / 1000) AS dist_km;
```

## Exercise 3: Proximity search — stores within N km

```sql
-- blocked: PostGIS not available in cfp_postgres

-- Stores within 600km of San Francisco
SELECT name,
       ROUND(ST_Distance(location, ST_MakePoint(-122.4194, 37.7749)::geography) / 1000) AS dist_km
FROM stores
WHERE ST_DWithin(location, ST_MakePoint(-122.4194, 37.7749)::geography, 600000)
ORDER BY dist_km;
-- Expected: Store SF (0km), Store LA (~559km)
```

## Exercise 4: KNN — nearest neighbors

```sql
-- blocked: PostGIS not available in cfp_postgres

-- 3 nearest stores to Chicago, ordered by distance
SELECT name,
       location <-> ST_MakePoint(-87.6298, 41.8781)::geography AS dist_m
FROM stores
ORDER BY location <-> ST_MakePoint(-87.6298, 41.8781)::geography
LIMIT 3;
-- Uses GiST index for efficient KNN
```

## Exercise 5: Polygon containment

```sql
-- blocked: PostGIS not available in cfp_postgres

-- Would a store at [-122.40, 37.78] be in a given rectangle?
SELECT ST_Within(
    ST_SetSRID(ST_MakePoint(-122.40, 37.78), 4326),
    ST_MakeEnvelope(-122.50, 37.70, -122.35, 37.85, 4326)  -- bounding box
) AS is_inside;
-- Expected: true (point is within the envelope)
```

## Conceptual exercises (no SQL required)

**CE1:** Draw a diagram showing:
- A `stores` table with `GEOGRAPHY(POINT, 4326)` column
- A GiST index as an R-tree
- How a `ST_DWithin` query uses the index: bounding box → exact distance check

**CE2:** Explain the difference between `geometry` and `geography` for a distance query between New York and London. Why does `geometry` give a wrong answer?

**CE3:** Design a schema for a food delivery service:
- Restaurants with locations
- Delivery zones as polygons
- Order delivery addresses as points
- What queries would you run to determine if a customer is in a restaurant's delivery zone?

## Reflection questions
1. Why is `GEOGRAPHY` more accurate than `GEOMETRY` for cross-continental distance calculations?
2. What is SRID 4326 and why is it the standard for GPS coordinates?
3. Why does a KNN query using `<->` in ORDER BY use the GiST index efficiently?
4. When would you choose PostGIS over a dedicated location service like Google Maps?
