# References — Practice 15: Agent-Safe Actions

---

## PostgreSQL Documentation

- [Row Security Policies](https://www.postgresql.org/docs/16/ddl-rowsecurity.html) — USING, WITH CHECK, policy stacking
- [CHECK Constraints](https://www.postgresql.org/docs/16/ddl-constraints.html) — table-level and column-level constraints
- [Trigger Procedures](https://www.postgresql.org/docs/16/plpgsql-trigger.html) — AFTER INSERT triggers
- [GET DIAGNOSTICS](https://www.postgresql.org/docs/16/plpgsql-statements.html#PLPGSQL-STATEMENTS-DIAGNOSTICS) — ROW_COUNT after UPDATE
- [set_config](https://www.postgresql.org/docs/16/functions-admin.html) — setting local configuration parameters

---

## Security Principles

- [Defense in Depth](https://csrc.nist.gov/projects/defense-in-depth) — layering multiple independent security mechanisms
- [OWASP: Least Privilege](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html) — minimum necessary permissions
- [Soft Delete Pattern](https://vladmihalcea.com/the-best-way-to-implement-a-soft-delete-with-hibernate/) — is_active flag instead of DELETE

---

## Concepts Covered in This Practice

- Concept 23: Agent-Safe Database Actions (`concepts/intermediate/23-agent-safe-database-actions.md`)
- Concept 24: Agent Memory and Audit Trails (`concepts/intermediate/24-agent-memory-and-audit-trails.md`)
- Design Principles: Agent Memory (`design-principles/agent-memory-design-principles.md`)
- Design Principles: Agent Permission (`design-principles/agent-permission-design-principles.md`)
- Ontology: Agent Workflow (`ontology/agent-workflow-ontology.md`)
