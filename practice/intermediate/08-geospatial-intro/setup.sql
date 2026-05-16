-- Practice 08: Geospatial Intro with PostGIS
-- STATUS: blocked — PostGIS not available in cfp_postgres image
--
-- This entire file would run on a PostGIS-enabled instance:
--   docker exec postgis_postgres psql -U postgres -d mydb -f setup.sql

-- PostGIS is NOT available in cfp_postgres.
-- All statements below are annotated for learning purposes only.

-- blocked: PostGIS not available in cfp_postgres
-- CREATE EXTENSION IF NOT EXISTS postgis;

-- blocked: PostGIS not available in cfp_postgres
-- CREATE TABLE stores (
--     id       SERIAL PRIMARY KEY,
--     name     TEXT NOT NULL,
--     location GEOGRAPHY(POINT, 4326)  -- WGS84 lat/lng
-- );

-- blocked: PostGIS not available in cfp_postgres
-- CREATE TABLE neighborhoods (
--     id       SERIAL PRIMARY KEY,
--     name     TEXT NOT NULL,
--     boundary GEOMETRY(POLYGON, 4326)
-- );

-- blocked: PostGIS not available in cfp_postgres
-- CREATE INDEX ON stores USING gist(location);
-- CREATE INDEX ON neighborhoods USING gist(boundary);

-- blocked: PostGIS not available in cfp_postgres
-- INSERT INTO stores (name, location) VALUES
--     ('Store SF',  ST_MakePoint(-122.4194, 37.7749)::geography),
--     ('Store LA',  ST_MakePoint(-118.2437, 34.0522)::geography),
--     ('Store NYC', ST_MakePoint( -74.0060, 40.7128)::geography),
--     ('Store CHI', ST_MakePoint( -87.6298, 41.8781)::geography);

-- Verify (blocked):
-- SELECT name, ST_AsText(location) FROM stores;
