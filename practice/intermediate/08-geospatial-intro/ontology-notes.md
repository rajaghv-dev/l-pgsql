# Ontology Notes — Geospatial Intro with PostGIS

## Space as an ontological dimension
In an ontology, space is a fundamental dimension of existence alongside time. Every physical entity has a spatial extent (a location, a boundary, or a region). PostGIS reifies spatial extent as a first-class property type: `GEOGRAPHY(POINT)`, `GEOMETRY(POLYGON)`.

## Point vs region ontology
- A `POINT` represents a **location** — a dimensionless position in space. A store is "at" a location.
- A `POLYGON` represents a **region** — a bounded area in space. A neighborhood "is" a region.
- Spatial containment (`ST_Within`) is the ontological "is-in" relationship: a store is-in a neighborhood.
- Spatial proximity (`ST_DWithin`) is the "near" relationship: a store is-near a customer.

## Coordinate reference systems as ontological frames
A coordinate reference system (CRS) is an ontological frame of reference: it defines what "position" means and what unit the numbers represent. Two points with the same coordinates but different CRS are different locations. SRID is the identifier for the CRS — it must be consistent across all spatial operations.

## Geospatial taxonomy
A spatial hierarchy (continent → country → region → city → neighborhood → address) is a classic ontological tree. PostGIS polygons for each level can encode this hierarchy spatially. Combining with ltree (concept 13) enables queries like "find all stores in continent X" without joining through all intermediate levels.

## Obsidian graph mapping
- `stores.location` → property: hasLocation (domain: Store, range: Point)
- `neighborhoods.boundary` → property: hasBoundary (domain: Neighborhood, range: Polygon)
- `ST_Within(a, b)` → relationship: isContainedBy
- `ST_DWithin(a, b, d)` → relationship: isNear (with distance parameter)
- `ST_Distance(a, b)` → function: spatialDistance → Measurement
