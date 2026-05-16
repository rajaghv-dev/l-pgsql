-- Practice 14: MCP Tool Database Design — Setup SQL
-- blocked: Docker not accessible
-- Study this SQL; run it when Docker is available.

-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ROLES
-- ============================================================

-- Agent role: no superuser, no BYPASSRLS, no DDL
CREATE ROLE mcp_agent_role
  NOSUPERUSER NOCREATEDB NOCREATEROLE
  NOREPLICATION NOBYPASSRLS NOINHERIT;

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE documents (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 500),
  body        TEXT,
  status      TEXT NOT NULL DEFAULT 'draft'
              CHECK (status IN ('draft','review','published','archived')),
  tenant_id   TEXT NOT NULL,
  created_by  TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- MCP tool calls audit log (INSERT-ONLY)
CREATE TABLE mcp_tool_calls (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tool_name     TEXT NOT NULL,
  agent_id      TEXT NOT NULL,
  tenant_id     TEXT,
  input_json    JSONB,
  output_json   JSONB,
  called_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  success       BOOLEAN NOT NULL DEFAULT true,
  error_message TEXT
);

-- Human approval queue
CREATE TABLE pending_approvals (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id   UUID NOT NULL REFERENCES documents(id),
  action_type   TEXT NOT NULL
                CHECK (action_type IN ('archive','publish','bulk_delete')),
  payload       JSONB NOT NULL DEFAULT '{}',
  requested_by  TEXT NOT NULL,
  tenant_id     TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','approved','rejected','expired')),
  requested_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '24 hours',
  reviewed_by   TEXT,
  reviewed_at   TIMESTAMPTZ,
  review_notes  TEXT
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_documents_tenant ON documents (tenant_id);
CREATE INDEX idx_documents_status ON documents (status, tenant_id);
CREATE INDEX idx_tool_calls_agent ON mcp_tool_calls (agent_id, called_at DESC);
CREATE INDEX idx_tool_calls_tenant ON mcp_tool_calls (tenant_id, called_at DESC);
CREATE INDEX idx_pending_status ON pending_approvals (status, tenant_id, expires_at);

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents FORCE ROW LEVEL SECURITY;

ALTER TABLE mcp_tool_calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE mcp_tool_calls FORCE ROW LEVEL SECURITY;

ALTER TABLE pending_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE pending_approvals FORCE ROW LEVEL SECURITY;

-- Agents see only their tenant's documents
CREATE POLICY doc_tenant_isolation ON documents
  AS PERMISSIVE FOR ALL TO mcp_agent_role
  USING (tenant_id = current_setting('app.tenant_id', true));

-- Agents can only create documents with their own agent_id as created_by
CREATE POLICY doc_agent_write_check ON documents
  AS PERMISSIVE FOR INSERT TO mcp_agent_role
  WITH CHECK (
    tenant_id = current_setting('app.tenant_id', true) AND
    created_by = current_setting('app.agent_id', true)
  );

-- Agents see only their own tool calls
CREATE POLICY tool_calls_own ON mcp_tool_calls
  AS PERMISSIVE FOR SELECT TO mcp_agent_role
  USING (agent_id = current_setting('app.agent_id', true));

-- Agents can insert their own tool calls only
CREATE POLICY tool_calls_insert ON mcp_tool_calls
  AS PERMISSIVE FOR INSERT TO mcp_agent_role
  WITH CHECK (
    agent_id = current_setting('app.agent_id', true) AND
    tenant_id = current_setting('app.tenant_id', true)
  );

-- Agents see pending approvals for their tenant
CREATE POLICY pending_tenant_isolation ON pending_approvals
  AS PERMISSIVE FOR ALL TO mcp_agent_role
  USING (tenant_id = current_setting('app.tenant_id', true));

-- Agents can only INSERT pending approvals (not UPDATE status)
CREATE POLICY pending_insert_only ON pending_approvals
  AS PERMISSIVE FOR INSERT TO mcp_agent_role
  WITH CHECK (
    tenant_id = current_setting('app.tenant_id', true) AND
    requested_by = current_setting('app.agent_id', true) AND
    status = 'pending'
  );

-- ============================================================
-- TRIGGERS — Audit log immutability
-- ============================================================

CREATE OR REPLACE FUNCTION enforce_tool_call_immutability()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION
    'mcp_tool_calls is INSERT-only. Operation % is not permitted.',
    TG_OP;
END;
$$;

CREATE TRIGGER protect_tool_calls
BEFORE UPDATE OR DELETE ON mcp_tool_calls
FOR EACH ROW EXECUTE FUNCTION enforce_tool_call_immutability();

CREATE TRIGGER protect_tool_calls_truncate
BEFORE TRUNCATE ON mcp_tool_calls
FOR EACH STATEMENT EXECUTE FUNCTION enforce_tool_call_immutability();

-- ============================================================
-- TRIGGER — Prevent self-approval
-- ============================================================

CREATE OR REPLACE FUNCTION prevent_self_approval()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status IN ('approved','rejected') AND
     NEW.reviewed_by IS NOT DISTINCT FROM OLD.requested_by THEN
    RAISE EXCEPTION
      'Agent % cannot approve or reject its own pending approval request.',
      OLD.requested_by;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER no_self_approval
BEFORE UPDATE ON pending_approvals
FOR EACH ROW EXECUTE FUNCTION prevent_self_approval();

-- ============================================================
-- TRIGGER — Auto-update updated_at on documents
-- ============================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER documents_updated_at
BEFORE UPDATE ON documents
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- NARROW TOOL FUNCTIONS
-- ============================================================

-- Tool: create_draft — only inserts a document in 'draft' status
CREATE OR REPLACE FUNCTION mcp_create_draft(
  p_title     TEXT,
  p_body      TEXT,
  p_agent_id  TEXT,
  p_tenant_id TEXT
) RETURNS JSONB
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_doc_id UUID;
BEGIN
  -- Input validation
  IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
    RAISE EXCEPTION 'title must not be empty';
  END IF;
  IF length(p_title) > 500 THEN
    RAISE EXCEPTION 'title must be 500 characters or fewer';
  END IF;

  -- Set session context for RLS and audit triggers
  PERFORM set_config('app.agent_id',  p_agent_id,  true);
  PERFORM set_config('app.tenant_id', p_tenant_id, true);
  PERFORM set_config('app.tool_name', 'create_draft', true);

  INSERT INTO documents(title, body, status, tenant_id, created_by)
  VALUES (trim(p_title), p_body, 'draft', p_tenant_id, p_agent_id)
  RETURNING id INTO v_doc_id;

  INSERT INTO mcp_tool_calls(tool_name, agent_id, tenant_id, input_json, success)
  VALUES ('create_draft', p_agent_id, p_tenant_id,
          jsonb_build_object('title', p_title), true);

  RETURN jsonb_build_object('document_id', v_doc_id, 'status', 'draft');
END;
$$;

GRANT EXECUTE ON FUNCTION mcp_create_draft TO mcp_agent_role;

-- Tool: submit_for_archive — routes through pending_approvals, does not execute directly
CREATE OR REPLACE FUNCTION mcp_submit_archive_request(
  p_document_id UUID,
  p_reason      TEXT,
  p_agent_id    TEXT,
  p_tenant_id   TEXT
) RETURNS JSONB
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_pending_id UUID;
BEGIN
  PERFORM set_config('app.agent_id',  p_agent_id,  true);
  PERFORM set_config('app.tenant_id', p_tenant_id, true);

  INSERT INTO pending_approvals(
    document_id, action_type, payload, requested_by, tenant_id
  ) VALUES (
    p_document_id, 'archive',
    jsonb_build_object('document_id', p_document_id, 'reason', p_reason),
    p_agent_id, p_tenant_id
  ) RETURNING id INTO v_pending_id;

  INSERT INTO mcp_tool_calls(tool_name, agent_id, tenant_id, input_json, success)
  VALUES ('submit_archive_request', p_agent_id, p_tenant_id,
          jsonb_build_object('document_id', p_document_id, 'reason', p_reason), true);

  RETURN jsonb_build_object(
    'status', 'pending_approval',
    'pending_approval_id', v_pending_id,
    'message', 'Archive request submitted. A human reviewer will approve or reject it within 24 hours.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION mcp_submit_archive_request TO mcp_agent_role;

-- ============================================================
-- GRANTS
-- ============================================================

-- Agent role can execute tool functions; no direct table access
-- (SECURITY DEFINER functions run as the function owner, not the caller)
-- No GRANT on tables needed for agent role.
