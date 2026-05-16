# References — Constraint-Driven Design

## PostgreSQL documentation
- Constraints: https://www.postgresql.org/docs/16/ddl-constraints.html
- EXCLUDE constraint syntax: https://www.postgresql.org/docs/16/sql-createtable.html#SQL-CREATETABLE-EXCLUDE
- Deferrable constraints / SET CONSTRAINTS: https://www.postgresql.org/docs/16/sql-set-constraints.html
- `btree_gist` extension: https://www.postgresql.org/docs/16/btree-gist.html
- Range types and operators: https://www.postgresql.org/docs/16/rangetypes.html
- `pg_constraint` catalog: https://www.postgresql.org/docs/16/catalog-pg-constraint.html
- Partial indexes: https://www.postgresql.org/docs/16/indexes-partial.html
- Triggers: https://www.postgresql.org/docs/16/plpgsql-trigger.html

## Design and patterns
- "Make Illegal States Unrepresentable" — Yaron Minsky: https://blog.janestreet.com/effective-ml-revisited/
- Soft deletes and partial unique indexes: https://brandur.org/fragments/deleted-record-insert
- Use The Index, Luke — Partial indexes: https://use-the-index-luke.com/sql/where-clause/partial-and-filtered-indexes

## PostgreSQL-specific patterns
- EXCLUDE for no-overlapping ranges: https://www.postgresql.org/docs/16/rangetypes.html#RANGETYPES-CONSTRAINT
- psycopg2 error classes (for constraint error handling): https://www.psycopg.org/docs/errors.html
