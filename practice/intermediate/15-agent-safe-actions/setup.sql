-- Practice 15: Agent-Safe Actions — Setup SQL
-- blocked: Docker not accessible
-- Study this SQL; run it when Docker is available.

-- ============================================================
-- ROLES
-- ============================================================

CREATE ROLE agent_write_role
  NOSUPERUSER NOCREATEDB NOCREATEROLE
  NOREPLICATION NOBYPASSRLS NOINHERIT;

CREATE ROLE agent_read_role
  NOSUPERUSER NOCREATEDB NOCREATEROLE
  NOREPLICATION NOBYPASSRLS NOINHERIT;

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE agent_memory (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id     TEXT NOT NULL CHECK (length(agent_id) > 0),
  memory_type  TEXT NOT NULL
               CHECK (memory_type IN ('episodic','semantic','procedural')),
  content      TEXT NOT NULL CHECK (length(content) > 0),
  metadata     JSONB DEFAULT '{}',
  is_active    BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at   TIMESTAMPTZ
               CHECK (expires_at IS NULL OR expires_at > created_at)
);

-- INSERT-ONLY audit log for all agent actions
CREATE TABLE agent_action_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id    TEXT NOT NULL,
  action_type TEXT NOT NULL,
  target_table TEXT,
  target_id   UUID,
  payload     JSONB,
  outcome     TEXT NOT NULL
              CHECK (outcome IN ('success','denied','constraint_violation','error')),
  error_detail TEXT,
  logged_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Records of blocked/unsafe operation attempts (observability)
CREATE TABLE unsafe_attempt_log (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id            TEXT NOT NULL,
  attempted_operation TEXT NOT NULL,
  reason_blocked      TEXT NOT NULL,
  attempted_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_agent_memory_agent ON agent_memory (agent_id, created_at DESC);
CREATE INDEX idx_agent_memory_type  ON agent_memory (agent_id, memory_type);
CREATE INDEX idx_agent_action_log_agent ON agent_action_log (agent_id, logged_at DESC);

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE agent_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_memory FORCE ROW LEVEL SECURITY;

ALTER TABLE agent_action_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_action_log FORCE ROW LEVEL SECURITY;

ALTER TABLE unsafe_attempt_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE unsafe_attempt_log FORCE ROW LEVEL SECURITY;

-- agent_memory: each agent sees only its own rows
CREATE POLICY memory_own_agent ON agent_memory
  AS PERMISSIVE FOR ALL TO agent_write_role
  USING (agent_id = current_setting('app.agent_id', true))
  WITH CHECK (agent_id = current_setting('app.agent_id', true));

-- agent_read_role: same isolation, SELECT only
CREATE POLICY memory_read_own ON agent_memory
  AS PERMISSIVE FOR SELECT TO agent_read_role
  USING (agent_id = current_setting('app.agent_id', true));

-- action_log: agent sees only its own log entries
CREATE POLICY action_log_own ON agent_action_log
  AS PERMISSIVE FOR SELECT TO agent_write_role
  USING (agent_id = current_setting('app.agent_id', true));

-- action_log: agents can INSERT their own entries only
CREATE POLICY action_log_insert ON agent_action_log
  AS PERMISSIVE FOR INSERT TO agent_write_role
  WITH CHECK (agent_id = current_setting('app.agent_id', true));

-- unsafe_attempt_log: agents can INSERT; cannot see others'
CREATE POLICY unsafe_log_own ON unsafe_attempt_log
  AS PERMISSIVE FOR ALL TO agent_write_role
  USING (agent_id = current_setting('app.agent_id', true))
  WITH CHECK (agent_id = current_setting('app.agent_id', true));

-- ============================================================
-- TRIGGERS — Audit log immutability
-- ============================================================

CREATE OR REPLACE FUNCTION enforce_log_immutability()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION
    '% is INSERT-only. Operation % is not permitted.',
    TG_TABLE_NAME, TG_OP;
END;
$$;

CREATE TRIGGER protect_action_log
BEFORE UPDATE OR DELETE ON agent_action_log
FOR EACH ROW EXECUTE FUNCTION enforce_log_immutability();

CREATE TRIGGER protect_action_log_truncate
BEFORE TRUNCATE ON agent_action_log
FOR EACH STATEMENT EXECUTE FUNCTION enforce_log_immutability();

CREATE TRIGGER protect_unsafe_log
BEFORE UPDATE OR DELETE ON unsafe_attempt_log
FOR EACH ROW EXECUTE FUNCTION enforce_log_immutability();

-- ============================================================
-- TRIGGER — Auto-audit on agent_memory writes
-- ============================================================

CREATE OR REPLACE FUNCTION audit_memory_write()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO agent_action_log(
    agent_id, action_type, target_table, target_id,
    payload, outcome
  ) VALUES (
    coalesce(current_setting('app.agent_id', true), 'unknown'),
    TG_OP,
    'agent_memory',
    CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
    CASE
      WHEN TG_OP = 'INSERT' THEN row_to_json(NEW)::JSONB
      WHEN TG_OP = 'UPDATE' THEN jsonb_build_object('old', row_to_json(OLD), 'new', row_to_json(NEW))
      ELSE row_to_json(OLD)::JSONB
    END,
    'success'
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER audit_agent_memory
AFTER INSERT OR UPDATE ON agent_memory
FOR EACH ROW EXECUTE FUNCTION audit_memory_write();

-- ============================================================
-- SAFE TOOL FUNCTIONS
-- ============================================================

-- Safe INSERT: validates agent_id matches context
CREATE OR REPLACE FUNCTION agent_remember(
  p_agent_id    TEXT,
  p_memory_type TEXT,
  p_content     TEXT,
  p_metadata    JSONB DEFAULT '{}'
) RETURNS JSONB
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_mem_id UUID;
BEGIN
  -- Validate inputs
  IF p_agent_id IS NULL OR length(p_agent_id) = 0 THEN
    RAISE EXCEPTION 'agent_id must not be empty';
  END IF;
  IF p_memory_type NOT IN ('episodic','semantic','procedural') THEN
    RAISE EXCEPTION 'memory_type must be episodic, semantic, or procedural';
  END IF;
  IF p_content IS NULL OR length(p_content) = 0 THEN
    RAISE EXCEPTION 'content must not be empty';
  END IF;

  -- Set context
  PERFORM set_config('app.agent_id', p_agent_id, true);
  PERFORM set_config('app.tool_name', 'agent_remember', true);

  INSERT INTO agent_memory(agent_id, memory_type, content, metadata)
  VALUES (p_agent_id, p_memory_type, p_content, p_metadata)
  RETURNING id INTO v_mem_id;
  -- audit_agent_memory trigger fires automatically

  RETURN jsonb_build_object('memory_id', v_mem_id, 'status', 'stored');
END;
$$;

GRANT EXECUTE ON FUNCTION agent_remember TO agent_write_role;

-- Safe SELECT: returns only the calling agent's memories
CREATE OR REPLACE FUNCTION agent_recall(
  p_agent_id    TEXT,
  p_memory_type TEXT DEFAULT NULL,
  p_limit       INT DEFAULT 10
) RETURNS JSONB
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_results JSONB;
BEGIN
  PERFORM set_config('app.agent_id', p_agent_id, true);

  SELECT jsonb_agg(row_to_json(m))
  INTO v_results
  FROM (
    SELECT id, memory_type, content, metadata, created_at
    FROM agent_memory
    WHERE agent_id = p_agent_id
      AND is_active = true
      AND (p_memory_type IS NULL OR memory_type = p_memory_type)
      AND (expires_at IS NULL OR expires_at > now())
    ORDER BY created_at DESC
    LIMIT p_limit
  ) m;

  RETURN coalesce(v_results, '[]'::JSONB);
END;
$$;

GRANT EXECUTE ON FUNCTION agent_recall TO agent_write_role;
GRANT EXECUTE ON FUNCTION agent_recall TO agent_read_role;

-- Soft-delete (safe alternative to hard DELETE)
CREATE OR REPLACE FUNCTION agent_forget(
  p_agent_id TEXT,
  p_mem_id   UUID
) RETURNS JSONB
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_rows INT;
BEGIN
  PERFORM set_config('app.agent_id', p_agent_id, true);

  UPDATE agent_memory
  SET is_active = false
  WHERE id = p_mem_id AND agent_id = p_agent_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    RETURN jsonb_build_object('error', 'memory_not_found_or_not_owned');
  END IF;

  -- Audit the soft-delete via action_log directly (trigger covers UPDATE)
  RETURN jsonb_build_object('memory_id', p_mem_id, 'status', 'deactivated');
END;
$$;

GRANT EXECUTE ON FUNCTION agent_forget TO agent_write_role;

-- ============================================================
-- GRANTS (minimal — tool functions mediate access)
-- ============================================================

-- No direct table grants to agent roles; SECURITY DEFINER functions handle access.
-- Humans and maintenance roles have direct access via their own grants.
