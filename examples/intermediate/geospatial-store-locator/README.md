# Geospatial Store Locator Example

Level: Intermediate
Domain: Store locator using lat/lon coordinates with Euclidean distance fallback
Synthetic data: Yes

## Overview

A store locator for a fictional retail chain called "Meridian Home Goods". Stores
are represented with latitude and longitude as FLOAT columns. Because PostGIS is
not available in the local `cfp_postgres` container, this example provides:

1. A working **non-spatial fallback** using Euclidean distance on lat/lon floats.
2. A documented **PostGIS version** of the same queries (blocked, for reference).

The Euclidean approximation is useful for small geographic areas (same city/region)
where the curvature of the earth is negligible. For accurate great-circle distance,
PostGIS or the Haversine formula is required.

## PostGIS status

> **blocked: PostGIS not available in cfp_postgres**
>
> All queries that use `ST_Distance`, `ST_DWithin`, `ST_GeogFromText`, or any
> `geometry`/`geography` type are marked blocked. The non-spatial fallback queries
> below run without PostGIS.

## Schema

### Working schema (no PostGIS)

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

CREATE TABLE stores (
    id          SERIAL PRIMARY KEY,
    name        TEXT           NOT NULL,
    address     TEXT           NOT NULL,   -- synthetic, non-real
    city        TEXT           NOT NULL,
    country     TEXT           NOT NULL DEFAULT 'GB',
    lat         FLOAT          NOT NULL,   -- latitude  (-90  to  90)
    lon         FLOAT          NOT NULL,   -- longitude (-180 to 180)
    phone       TEXT,
    opens_at    TIME           NOT NULL DEFAULT '09:00',
    closes_at   TIME           NOT NULL DEFAULT '18:00',
    active      BOOLEAN        NOT NULL DEFAULT TRUE,
    CONSTRAINT lat_range CHECK (lat  BETWEEN -90  AND  90),
    CONSTRAINT lon_range CHECK (lon  BETWEEN -180 AND 180)
);

CREATE INDEX idx_stores_city    ON stores (city);
CREATE INDEX idx_stores_active  ON stores (active) WHERE active = TRUE;
```

### PostGIS schema (blocked)

```sql
-- blocked: PostGIS not available in cfp_postgres
-- The schema below documents what the PostGIS version would look like.

-- CREATE EXTENSION IF NOT EXISTS postgis;

-- CREATE TABLE stores_postgis (
--     id       SERIAL PRIMARY KEY,
--     name     TEXT NOT NULL,
--     location GEOGRAPHY(POINT, 4326)   -- WGS 84 lat/lon
-- );

-- CREATE INDEX idx_stores_location ON stores_postgis USING GIST (location);
```

## Seed data

Synthetic coordinates cluster around two fictional UK cities.
All store names, addresses, and phone numbers are fabricated.

```sql
INSERT INTO stores (name, address, city, lat, lon, phone, opens_at, closes_at) VALUES
  -- Synthetic "Northford" cluster (approx 53.48°N 2.24°W)
  ('Meridian Northford Central',  '12 Market Square, Northford',    'Northford', 53.4800, -2.2400, '0161-000-0001', '09:00', '20:00'),
  ('Meridian Northford North',    '88 Birch Lane, Northford',       'Northford', 53.5050, -2.2150, '0161-000-0002', '10:00', '19:00'),
  ('Meridian Northford West',     '3 Canal Road, Northford',        'Northford', 53.4780, -2.2780, '0161-000-0003', '09:00', '18:00'),
  ('Meridian Northford Retail Pk','55 Retail Park Way, Northford',  'Northford', 53.4650, -2.2600, '0161-000-0004', '09:00', '21:00'),
  ('Meridian Northford Airport',  '1 Terminal Approach, Northford', 'Northford', 53.5200, -2.2000, '0161-000-0005', '07:00', '22:00'),

  -- Synthetic "Ashbridge" cluster (approx 51.50°N 0.12°W)
  ('Meridian Ashbridge City',     '7 Throne St, Ashbridge',         'Ashbridge', 51.5000, -0.1200, '0207-000-0001', '08:00', '21:00'),
  ('Meridian Ashbridge East',     '200 Irongate Rd, Ashbridge',     'Ashbridge', 51.5100, -0.0500, '0207-000-0002', '09:00', '20:00'),
  ('Meridian Ashbridge South',    '45 Riverside Walk, Ashbridge',   'Ashbridge', 51.4850, -0.1000, '0207-000-0003', '10:00', '18:00'),
  ('Meridian Ashbridge West',     '11 Goldhaven Ave, Ashbridge',    'Ashbridge', 51.5050, -0.1900, '0207-000-0004', '09:00', '19:00'),

  -- Inactive store
  ('Meridian Northford Old Town', '99 Old St, Northford',           'Northford', 53.4820, -2.2350, '0161-000-0009', '09:00', '18:00');

UPDATE stores SET active = FALSE WHERE name = 'Meridian Northford Old Town';
```

## Example queries

### All active stores in a city

```sql
SELECT id, name, address, lat, lon
FROM   stores
WHERE  city   = 'Northford'
  AND  active = TRUE
ORDER  BY name;
```

### Non-spatial distance approximation (Euclidean on lat/lon)

Euclidean distance on raw degrees is only meaningful for short distances
(same city). For larger areas, use the Haversine formula (see below).

```sql
-- User location: 53.490, -2.230 (somewhere in Northford)
SELECT id,
       name,
       city,
       lat,
       lon,
       ROUND(
         SQRT(POWER(lat - 53.490, 2) + POWER(lon - (-2.230), 2))::NUMERIC,
         6
       ) AS euclidean_dist   -- in degrees, not metres
FROM   stores
WHERE  active = TRUE
ORDER  BY euclidean_dist
LIMIT  5;
```

### Haversine distance approximation (pure SQL, no PostGIS)

Returns approximate distance in kilometres using the Haversine formula.

```sql
-- User location: 53.490 N, -2.230 W
-- Earth radius: 6371 km
SELECT id,
       name,
       city,
       ROUND((
         6371 * 2 * ASIN(
           SQRT(
             POWER(SIN(RADIANS(lat  - 53.490)  / 2), 2) +
             COS(RADIANS(53.490)) * COS(RADIANS(lat)) *
             POWER(SIN(RADIANS(lon  - (-2.230)) / 2), 2)
           )
         )
       )::NUMERIC, 2) AS distance_km
FROM   stores
WHERE  active = TRUE
ORDER  BY distance_km
LIMIT  5;
```

### Stores within ~5 km of a point (Haversine filter)

```sql
SELECT id, name, city, lat, lon,
       ROUND((
         6371 * 2 * ASIN(
           SQRT(
             POWER(SIN(RADIANS(lat  - 53.490)  / 2), 2) +
             COS(RADIANS(53.490)) * COS(RADIANS(lat)) *
             POWER(SIN(RADIANS(lon  - (-2.230)) / 2), 2)
           )
         )
       )::NUMERIC, 2) AS distance_km
FROM   stores
WHERE  active = TRUE
HAVING ROUND((
         6371 * 2 * ASIN(
           SQRT(
             POWER(SIN(RADIANS(lat  - 53.490)  / 2), 2) +
             COS(RADIANS(53.490)) * COS(RADIANS(lat)) *
             POWER(SIN(RADIANS(lon  - (-2.230)) / 2), 2)
           )
         )
       )::NUMERIC, 2) < 5.0
ORDER  BY distance_km;
```

### Store count per city

```sql
SELECT city,
       COUNT(*)                                    AS total_stores,
       COUNT(*) FILTER (WHERE active = TRUE)       AS active_stores
FROM   stores
GROUP  BY city
ORDER  BY total_stores DESC;
```

## PostGIS version (blocked)

The following queries show what the PostGIS implementation would look like.
They will not run in `cfp_postgres` without the extension.

```sql
-- blocked: PostGIS not available in cfp_postgres

-- Find stores within 5 km of a point using ST_DWithin:
-- SELECT name, city,
--        ST_Distance(location, ST_GeogFromText('POINT(-2.230 53.490)')) / 1000 AS dist_km
-- FROM   stores_postgis
-- WHERE  ST_DWithin(location, ST_GeogFromText('POINT(-2.230 53.490)'), 5000)
-- ORDER  BY dist_km;

-- Bounding box query:
-- SELECT name
-- FROM   stores_postgis
-- WHERE  ST_Within(
--           location::geometry,
--           ST_MakeEnvelope(-2.30, 53.45, -2.18, 53.55, 4326)
--        );
```

## Validation queries

```sql
-- Validation status: blocked: Docker not accessible;
-- re-validate against cfp_postgres when Docker Desktop WSL integration is enabled

SELECT COUNT(*) FROM stores;           -- Expected: 10
SELECT COUNT(*) FROM stores WHERE active = TRUE;   -- Expected: 9

-- Constraint check: all lat/lon in range
SELECT COUNT(*) FROM stores
WHERE lat NOT BETWEEN -90 AND 90 OR lon NOT BETWEEN -180 AND 180;
-- Expected: 0

-- Both cities present
SELECT DISTINCT city FROM stores ORDER BY city;
-- Expected: Ashbridge, Northford

-- Indexes exist
SELECT indexname FROM pg_indexes WHERE tablename = 'stores';
```

## Practice tasks

1. **Nearest store.** Using the Haversine query, find the single nearest active
   store to the coordinates `(51.500, -0.120)` — the Ashbridge city centre. What
   is its name and distance?

2. **Add opening hours filter.** Modify the nearest-store query to only return
   stores that are currently open. You will need to compare `CURRENT_TIME` against
   `opens_at` and `closes_at`.

3. **City bounding box.** Without PostGIS, write a query that returns all stores
   within a bounding box: lat between 53.46 and 53.51, lon between -2.28 and -2.20.
   How many stores are inside this box?

4. **Geocoding column.** Add a `postcode TEXT` column to `stores`. Insert plausible
   synthetic postcodes (e.g. `'NF1 1AA'`, `'AB2 2BB'`). Write a query that returns
   stores grouped by the first part of the postcode (the "outward code" before the
   space).

5. **PostGIS research.** Without running it, describe what `ST_DWithin` does and
   why it is faster than computing `ST_Distance` for every row. What index type
   does PostGIS use for geographic columns?

## MCP and agent perspective

A store-finder agent using this schema via MCP would:

- **Receive user location** — the caller provides lat/lon (from device GPS or
  geocoding a typed address). The agent passes these directly into the Haversine
  query.
- **Return ranked stores** — the distance query result is formatted as a list
  with name, address, and distance for the user.
- **Filter by opening hours** — combine distance ranking with an opening-hours
  filter so the agent only suggests stores the user can actually visit now.
- **When PostGIS is available** — replace the Haversine SQL with `ST_DWithin`
  for better performance and accuracy. The agent's query interface does not change;
  only the SQL template is swapped.

## Teardown

```sql
DROP INDEX IF EXISTS idx_stores_active;
DROP INDEX IF EXISTS idx_stores_city;
DROP TABLE IF EXISTS stores;
```

## References

- Haversine formula: https://en.wikipedia.org/wiki/Haversine_formula
- PostGIS documentation: https://postgis.net/docs/
- PostgreSQL trigonometric functions: https://www.postgresql.org/docs/current/functions-math.html
- PostGIS ST_DWithin: https://postgis.net/docs/ST_DWithin.html
