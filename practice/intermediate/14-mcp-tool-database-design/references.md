# References — Practice 14: MCP Tool Database Design

---

## PostgreSQL Documentation

- [Row Security Policies](https://www.postgresql.org/docs/16/ddl-rowsecurity.html) — USING, WITH CHECK, PERMISSIVE vs RESTRICTIVE
- [CREATE FUNCTION — SECURITY DEFINER](https://www.postgresql.org/docs/16/sql-createfunction.html) — function security modes
- [Trigger Functions](https://www.postgresql.org/docs/16/plpgsql-trigger.html) — BEFORE/AFTER, per-row, per-statement triggers
- [current_setting](https://www.postgresql.org/docs/16/functions-admin.html) — reading session-local settings
- [SET LOCAL](https://www.postgresql.org/docs/16/sql-set.html) — transaction-scoped configuration
- [ON CONFLICT](https://www.postgresql.org/docs/16/sql-insert.html) — idempotent inserts

---

## MCP Specification

- [MCP Specification](https://spec.modelcontextprotocol.io/) — official MCP protocol documentation
- [MCP Tool Schema](https://spec.modelcontextprotocol.io/specification/server/tools/) — typed input/output schemas

---

## Security Principles

- [OWASP: SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html) — parameterized queries
- [OWASP: Least Privilege](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html) — minimum necessary grants
- [NIST: Access Control Guide](https://csrc.nist.gov/publications/detail/sp/800-162/final) — least privilege, separation of duties

---

## Concepts Covered in This Practice

- Concept 22: PostgreSQL for MCP Tools (`concepts/intermediate/22-postgresql-for-mcp-tools.md`)
- Concept 23: Agent-Safe Database Actions (`concepts/intermediate/23-agent-safe-database-actions.md`)
- Design Principles: MCP Tool Design (`design-principles/mcp-tool-design-principles.md`)
- Ontology: MCP Tool (`ontology/mcp-tool-ontology.md`)
- Ontology: Agent Workflow (`ontology/agent-workflow-ontology.md`)
