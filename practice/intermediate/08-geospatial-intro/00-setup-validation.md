# Setup Validation — Practice 08

**Status: blocked — PostGIS not available in cfp_postgres**

## How to verify on a PostGIS-enabled instance

```sql
-- blocked: PostGIS not available in cfp_postgres

-- 1. Check PostGIS is installed
SELECT extname, extversion FROM pg_extension WHERE extname = 'postgis';

-- 2. Confirm PostGIS version
SELECT PostGIS_Version();

-- 3. After running setup.sql
SELECT name, ST_X(location::geometry) AS lng, ST_Y(location::geometry) AS lat
FROM stores;

-- 4. Confirm GiST index
SELECT indexname FROM pg_indexes WHERE tablename = 'stores';
```

## Workaround for cfp_postgres
Without PostGIS, you can simulate coordinate storage using numeric columns:
```sql
-- Approximate substitute (no spatial functions):
CREATE TABLE stores_approx (
    id   SERIAL PRIMARY KEY,
    name TEXT,
    lng  NUMERIC(9, 6),
    lat  NUMERIC(8, 6)
);
-- Distance queries would require manual Haversine formula — not recommended for production.
```
