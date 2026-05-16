# Ontology Notes — RLS and Multi-Tenancy

## Tenant as ontological scope
A tenant is an ontological bounded context: the set of all entities that belong to a single organizational actor. The `tenant_id` column encodes the **ownership relation** (`belongs_to`) between every data entity and its owning tenant.

In ontology terms, RLS implements a **scoped view** of the world: from within a tenant's context, only their entities exist. Other tenants' entities are ontologically invisible. This is the Closed World Assumption applied to tenant scope: if you can't see it, it doesn't exist (in your context).

## RLS as ontological boundary enforcement
The RLS policy is the enforcement mechanism for the ontological boundary between tenants. It translates the abstract ontological constraint ("a tenant can only see their own entities") into a concrete SQL predicate that runs for every query.

`current_setting('app.tenant_id')` is the **context variable** — the runtime declaration of which perspective (tenant context) is currently active. The database's visible world shifts based on this context, just as an observer's perspective shifts their view of a shared world.

## Data sovereignty
Multi-tenant RLS operationalizes the principle of **data sovereignty**: each tenant owns their data, and no other entity can access it without explicit permission (BYPASSRLS, granted to admin roles). This maps to legal concepts of data residency and privacy (GDPR's "data belongs to the subject").

## Obsidian graph mapping
- `tenants` → node type: Tenant (ontological bounded context)
- `projects` → node type: Entity (scope: within one Tenant)
- `tasks` → node type: Entity (scope: within one Project and one Tenant)
- `tenant_id` column → property: ownedBy (linking Entity to Tenant)
- RLS policy → constraint: visibilityScope (only entities ownedBy currentTenant are visible)
- `BYPASSRLS` role → ontological exception: omniscient observer (can see all tenants)
