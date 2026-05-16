# Practice: Geospatial Intro with PostGIS

**Stage:** 10 — Non-SQL Capabilities
**Concept file:** `concepts/intermediate/14-geospatial-intro-with-postgis.md`
**Level:** Intermediate

## Status: All SQL blocked — PostGIS not available in cfp_postgres image

PostGIS is not installed in the `cfp_postgres` container. All SQL in this folder is conceptual.

To run these exercises you would need:
```bash
# A PostGIS-enabled PostgreSQL container
docker run --name postgres_postgis -e POSTGRES_PASSWORD=secret \
  -p 5433:5432 -d postgis/postgis:16-3.4

docker exec -it postgres_postgis psql -U postgres -c "CREATE EXTENSION postgis;"
```

## Goal (conceptual)
Understand PostGIS geometry/geography types, spatial indexes, and key spatial functions through reading and annotated examples.

## Docker note
All SQL is blocked: PostGIS not available in cfp_postgres.
