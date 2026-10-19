BEGIN;

-- 来访上下文：预约、随行、凭证、通行、告知、异常、状态历史、访客令牌

CREATE TABLE IF NOT EXISTS appointments (
  id                      VARCHAR(36)  PRIMARY KEY,
  appoint_no              VARCHAR(30)  NOT NULL,
  visitor_type_id         VARCHAR(36)  NOT NULL,
  visitor_name            VARCHAR(20)  NULL,
  visitor_phone           VARCHAR(20)  NULL,
  visitor_id_no           VARCHAR(20)  NULL,
  host_id                 VARCHAR(36)  NOT NULL,
  reviewer_id             VARCHAR(36)  NULL,
  expected_gate_id        VARCHAR(36)  NULL,
  visit_start             TIMESTAMPTZ  NOT NULL,
  visit_end               TIMESTAMPTZ  NOT NULL,
  reason                  VARCHAR(100) NOT NULL,
  plate_no                VARCHAR(20)  NULL,
  status                  VARCHAR(20)  NOT NULL,
  people_count            INTEGER      NOT NULL DEFAULT 1,
  black_hit               BOOLEAN      NOT NULL DEFAULT false,
  reschedule_proposed_at  TIMESTAMPTZ  NULL,
  reject_reason           VARCHAR(100) NULL,
  cancel_reason           VARCHAR(200) NULL,
  checkin_at              TIMESTAMPTZ  NULL,
  checkout_at             TIMESTAMPTZ  NULL,
  reminder_sent_at        TIMESTAMPTZ  NULL,
  created_by              VARCHAR(36)  NULL,
  created_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT uq_appointments_appoint_no UNIQUE (appoint_no),
  CONSTRAINT uq_appointments_visitor_slot UNIQUE (visitor_id_no, visit_start, visit_end),
  CONSTRAINT chk_appointments_status CHECK (status IN ('待审核', '已通过', '已拒绝', '已改期', '已过期', '已到访(在校中)', '已离校', '已取消')),
  CONSTRAINT chk_appointments_time_range CHECK (visit_start < visit_end),
  CONSTRAINT chk_appointments_people_count CHECK (people_count BETWEEN 1 AND 11)
);

CREATE INDEX IF NOT EXISTS idx_appointments_visit_start ON appointments (visit_start DESC);
CREATE INDEX IF NOT EXISTS idx_appointments_status_start ON appointments (status, visit_start);
CREATE INDEX IF NOT EXISTS idx_appointments_visitor_id_no ON appointments (visitor_id_no);
CREATE INDEX IF NOT EXISTS idx_appointments_visitor_phone ON appointments (visitor_phone);
CREATE INDEX IF NOT EXISTS idx_appointments_host_id ON appointments (host_id);
CREATE INDEX IF NOT EXISTS idx_appointments_reviewer_id ON appointments (reviewer_id);
CREATE INDEX IF NOT EXISTS idx_appointments_appoint_no ON appointments (appoint_no);
CREATE INDEX IF NOT EXISTS idx_appointments_created_at ON appointments (created_at);

CREATE TABLE IF NOT EXISTS companions (
  id              VARCHAR(36) PRIMARY KEY,
  appointment_id  VARCHAR(36) NOT NULL,
  name            VARCHAR(20) NULL,
  relation        VARCHAR(20) NOT NULL,
  id_no           VARCHAR(20) NULL,
  sort_order      INTEGER     NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_companions_appointment FOREIGN KEY (appointment_id) REFERENCES appointments (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_companions_appointment_id_sort_order ON companions (appointment_id, sort_order);

CREATE TABLE IF NOT EXISTS visit_credentials (
  id              VARCHAR(36) PRIMARY KEY,
  appointment_id  VARCHAR(36) NOT NULL,
  short_code      CHAR(6)     NOT NULL,
  usage_status    VARCHAR(10) NOT NULL DEFAULT '未使用',
  used_at         TIMESTAMPTZ NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_visit_credentials_appointment UNIQUE (appointment_id),
  CONSTRAINT uq_visit_credentials_short_code UNIQUE (short_code),
  CONSTRAINT fk_visit_credentials_appointment FOREIGN KEY (appointment_id) REFERENCES appointments (id) ON DELETE CASCADE,
  CONSTRAINT chk_visit_credentials_usage_status CHECK (usage_status IN ('未使用', '已使用')),
  CONSTRAINT chk_visit_credentials_short_code CHECK (short_code ~ '^[0-9]{6}$')
);

CREATE TABLE IF NOT EXISTS passage_records (
  id              VARCHAR(36) PRIMARY KEY,
  appointment_id  VARCHAR(36) NOT NULL,
  gate_id         VARCHAR(36) NOT NULL,
  record_type     VARCHAR(10) NOT NULL,
  occurred_at     TIMESTAMPTZ NOT NULL,
  operator_id     VARCHAR(36) NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_passage_records_appointment FOREIGN KEY (appointment_id) REFERENCES appointments (id) ON DELETE CASCADE,
  CONSTRAINT chk_passage_records_type CHECK (record_type IN ('进校', '离校'))
);

CREATE INDEX IF NOT EXISTS idx_passage_records_appointment_id_occurred_at ON passage_records (appointment_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_passage_records_gate_id_occurred_at ON passage_records (gate_id, occurred_at DESC);

CREATE TABLE IF NOT EXISTS consent_records (
  id              VARCHAR(36) PRIMARY KEY,
  appointment_id  VARCHAR(36) NOT NULL,
  consent_type    VARCHAR(30) NOT NULL,
  confirmed_at    TIMESTAMPTZ NOT NULL,
  channel         VARCHAR(20) NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_consent_records_appointment_type_channel UNIQUE (appointment_id, consent_type, channel),
  CONSTRAINT fk_consent_records_appointment FOREIGN KEY (appointment_id) REFERENCES appointments (id) ON DELETE CASCADE,
  CONSTRAINT chk_consent_records_type CHECK (consent_type IN ('安全告知', '个人信息授权告知')),
  CONSTRAINT chk_consent_records_channel CHECK (channel IN ('H5', '现场登记', '后台代提'))
);

CREATE INDEX IF NOT EXISTS idx_consent_records_appointment_id ON consent_records (appointment_id);

CREATE TABLE IF NOT EXISTS incidents (
  id                VARCHAR(36)  PRIMARY KEY,
  appointment_id    VARCHAR(36)  NULL,
  incident_type     VARCHAR(20)  NOT NULL,
  status            VARCHAR(10)  NOT NULL DEFAULT '待处理',
  description       VARCHAR(500) NOT NULL DEFAULT '',
  reported_by       VARCHAR(36)  NOT NULL,
  handled_by        VARCHAR(36)  NULL,
  disposition_note  VARCHAR(200) NULL,
  handled_at        TIMESTAMPTZ  NULL,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT fk_incidents_appointment FOREIGN KEY (appointment_id) REFERENCES appointments (id) ON DELETE SET NULL,
  CONSTRAINT chk_incidents_type CHECK (incident_type IN ('黑名单命中', '信息不符', '强行闯入', '超时未离')),
  CONSTRAINT chk_incidents_status CHECK (status IN ('待处理', '已处理', '已忽略'))
);

CREATE INDEX IF NOT EXISTS idx_incidents_status_created_at ON incidents (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_incidents_incident_type ON incidents (incident_type);
CREATE INDEX IF NOT EXISTS idx_incidents_appointment_id ON incidents (appointment_id);

CREATE TABLE IF NOT EXISTS appointment_status_history (
  id              VARCHAR(36)  PRIMARY KEY,
  appointment_id  VARCHAR(36)  NOT NULL,
  from_status     VARCHAR(20)  NULL,
  to_status       VARCHAR(20)  NOT NULL,
  changed_by      VARCHAR(36)  NULL,
  change_reason   VARCHAR(200) NOT NULL DEFAULT '',
  occurred_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT fk_appointment_status_history_appointment FOREIGN KEY (appointment_id) REFERENCES appointments (id) ON DELETE CASCADE,
  CONSTRAINT chk_appointment_status_history_from_status CHECK (from_status IS NULL OR from_status IN ('待审核', '已通过', '已拒绝', '已改期', '已过期', '已到访(在校中)', '已离校', '已取消')),
  CONSTRAINT chk_appointment_status_history_to_status CHECK (to_status IN ('待审核', '已通过', '已拒绝', '已改期', '已过期', '已到访(在校中)', '已离校', '已取消'))
);

CREATE INDEX IF NOT EXISTS idx_appointment_status_history_appointment_id_occurred_at ON appointment_status_history (appointment_id, occurred_at);

CREATE TABLE IF NOT EXISTS visitor_tokens (
  id              VARCHAR(36) PRIMARY KEY,
  appointment_id  VARCHAR(36) NOT NULL,
  token_hash      CHAR(64)    NOT NULL,
  expires_at      TIMESTAMPTZ NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_visitor_tokens_token_hash UNIQUE (token_hash),
  CONSTRAINT fk_visitor_tokens_appointment FOREIGN KEY (appointment_id) REFERENCES appointments (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_visitor_tokens_appointment_id ON visitor_tokens (appointment_id);

COMMIT;
