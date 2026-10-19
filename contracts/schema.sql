-- 校园访客系统 V1.0 · 契约冻结 DDL 汇总
-- 来源: backend/db/migrations/001-shared.sql ... 005-compliance.sql
-- 本文件与五个迁移文件逐字等价；仅按文件名顺序拼接。

-- ===== 001-shared.sql =====
-- 校园访客系统 V1.0 · 共享基础设施表 DDL
-- 执行入口：backend/src/shared/db/migrate.ts 扫描 backend/db/migrations/*.sql
-- 本文件是共享表的权威 DDL，编号 001-shared.sql 逐字引用本文件内容。
-- 规范：UUID 以 VARCHAR(36) 存储；枚举中文入库并配 CHECK；软状态用 active/inactive。

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. 角色
CREATE TABLE IF NOT EXISTS roles (
  code          VARCHAR(20)  PRIMARY KEY,
  name          VARCHAR(30)  NOT NULL,
  description   VARCHAR(200) NOT NULL DEFAULT '',
  is_system     BOOLEAN      NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT chk_roles_code CHECK (code IN ('admin', 'guard', 'host', 'visitor'))
);

-- 2. 权限点
CREATE TABLE IF NOT EXISTS permissions (
  code          VARCHAR(80)  PRIMARY KEY,
  name          VARCHAR(50)  NOT NULL,
  resource      VARCHAR(40)  NOT NULL,
  action        VARCHAR(40)  NOT NULL,
  description   VARCHAR(200) NOT NULL DEFAULT ''
);

-- 3. 角色-权限
CREATE TABLE IF NOT EXISTS role_permissions (
  role_code       VARCHAR(20) NOT NULL,
  permission_code VARCHAR(80) NOT NULL,
  PRIMARY KEY (role_code, permission_code),
  CONSTRAINT fk_role_permissions_role FOREIGN KEY (role_code) REFERENCES roles (code) ON DELETE CASCADE,
  CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_code) REFERENCES permissions (code) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_role_permissions_permission ON role_permissions (permission_code);

-- 4. 后台账号
CREATE TABLE IF NOT EXISTS users (
  id                 VARCHAR(36)  PRIMARY KEY,
  username           VARCHAR(50)  NOT NULL,
  password_hash      VARCHAR(100) NOT NULL,
  display_name       VARCHAR(50)  NOT NULL,
  role_code          VARCHAR(20)  NOT NULL,
  host_id            VARCHAR(36)  NULL,
  phone              VARCHAR(20)  NULL,
  status             VARCHAR(10)  NOT NULL DEFAULT 'active',
  failed_login_count INTEGER      NOT NULL DEFAULT 0,
  locked_until       TIMESTAMPTZ  NULL,
  last_login_at      TIMESTAMPTZ  NULL,
  created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT uq_users_username UNIQUE (username),
  CONSTRAINT fk_users_role FOREIGN KEY (role_code) REFERENCES roles (code),
  CONSTRAINT chk_users_status CHECK (status IN ('active', 'inactive')),
  CONSTRAINT chk_users_failed_count CHECK (failed_login_count >= 0)
);

CREATE INDEX IF NOT EXISTS idx_users_role ON users (role_code);
CREATE INDEX IF NOT EXISTS idx_users_host ON users (host_id);
CREATE INDEX IF NOT EXISTS idx_users_status ON users (status);

COMMENT ON COLUMN users.host_id IS '软引用 hosts.id；不建外键（跨上下文）';

-- 5. 认证方式
CREATE TABLE IF NOT EXISTS auth_types (
  code        VARCHAR(20)  PRIMARY KEY,
  name        VARCHAR(30)  NOT NULL,
  description VARCHAR(200) NOT NULL DEFAULT '',
  enabled     BOOLEAN      NOT NULL DEFAULT true
);

-- 6. 会话
CREATE TABLE IF NOT EXISTS sessions (
  sid    VARCHAR(200) PRIMARY KEY,
  sess   JSON        NOT NULL,
  expire TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_expire ON sessions (expire);

-- 7. 操作日志（审计）
CREATE TABLE IF NOT EXISTS operation_logs (
  id           VARCHAR(36)  PRIMARY KEY,
  user_id      VARCHAR(36)  NULL,
  user_name    VARCHAR(50)  NOT NULL DEFAULT '',
  occurred_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  object_type  VARCHAR(40)  NOT NULL,
  object_id    VARCHAR(36)  NULL,
  action       VARCHAR(40)  NOT NULL,
  result       VARCHAR(20)  NOT NULL,
  before_value JSONB        NULL,
  after_value  JSONB        NULL,
  ip           VARCHAR(45)  NULL,
  note         VARCHAR(200) NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_operation_logs_occurred ON operation_logs (occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_operation_logs_object ON operation_logs (object_type, object_id);
CREATE INDEX IF NOT EXISTS idx_operation_logs_user ON operation_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_operation_logs_action ON operation_logs (action);

COMMENT ON COLUMN operation_logs.before_value IS '改动前明文；个人信息保护例外：不随主记录清除';
COMMENT ON COLUMN operation_logs.after_value IS '改动后明文；个人信息保护例外：不随主记录清除';

-- 8. 系统参数
CREATE TABLE IF NOT EXISTS system_config (
  config_key   VARCHAR(60)  PRIMARY KEY,
  config_value TEXT         NOT NULL,
  value_type   VARCHAR(10)  NOT NULL DEFAULT 'string',
  description  VARCHAR(200) NOT NULL DEFAULT '',
  updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT chk_system_config_type CHECK (value_type IN ('string', 'number', 'boolean', 'json'))
);

COMMIT;

-- ===== 002-master.sql =====
BEGIN;

-- 主数据上下文：被访人、访客类型、校门、黑名单、时段规则、审核规则、数据字典

CREATE TABLE IF NOT EXISTS hosts (
  id            VARCHAR(36)  PRIMARY KEY,
  name          VARCHAR(50)  NOT NULL,
  employee_no   VARCHAR(30)  NOT NULL,
  department    VARCHAR(100) NOT NULL DEFAULT '',
  phone         VARCHAR(20)  NULL,
  status        VARCHAR(10)  NOT NULL DEFAULT 'active',
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT uq_hosts_employee_no UNIQUE (employee_no),
  CONSTRAINT chk_hosts_status CHECK (status IN ('active', 'inactive'))
);

CREATE INDEX IF NOT EXISTS idx_hosts_status ON hosts (status);
CREATE INDEX IF NOT EXISTS idx_hosts_department ON hosts (department);

CREATE TABLE IF NOT EXISTS visitor_types (
  id            VARCHAR(36) PRIMARY KEY,
  code          VARCHAR(30) NOT NULL,
  name          VARCHAR(30) NOT NULL,
  status        VARCHAR(10) NOT NULL DEFAULT 'active',
  sort_order    INTEGER     NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_visitor_types_code UNIQUE (code),
  CONSTRAINT chk_visitor_types_status CHECK (status IN ('active', 'inactive'))
);

CREATE TABLE IF NOT EXISTS gates (
  id            VARCHAR(36) PRIMARY KEY,
  code          VARCHAR(30) NOT NULL,
  name          VARCHAR(30) NOT NULL,
  status        VARCHAR(10) NOT NULL DEFAULT 'active',
  sort_order    INTEGER     NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_gates_code UNIQUE (code),
  CONSTRAINT chk_gates_status CHECK (status IN ('active', 'inactive'))
);

CREATE TABLE IF NOT EXISTS blacklist_entries (
  id            VARCHAR(36)  PRIMARY KEY,
  id_no         VARCHAR(20)  NOT NULL,
  name          VARCHAR(50)  NOT NULL DEFAULT '',
  reason        VARCHAR(200) NOT NULL,
  expire_at     TIMESTAMPTZ  NOT NULL,
  status        VARCHAR(10)  NOT NULL DEFAULT '有效',
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  deleted_at    TIMESTAMPTZ  NULL,
  CONSTRAINT chk_blacklist_entries_status CHECK (status IN ('有效', '已过期', '已删除'))
);

CREATE INDEX IF NOT EXISTS idx_blacklist_entries_id_no_status ON blacklist_entries (id_no, status);
CREATE INDEX IF NOT EXISTS idx_blacklist_entries_expire_at ON blacklist_entries (expire_at);

CREATE TABLE IF NOT EXISTS time_rules (
  id            VARCHAR(36) PRIMARY KEY,
  weekday       SMALLINT    NOT NULL,
  start_time    TIME        NOT NULL,
  end_time      TIME        NOT NULL,
  rule_type     VARCHAR(10) NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_time_rules_weekday CHECK (weekday BETWEEN 1 AND 7),
  CONSTRAINT chk_time_rules_type CHECK (rule_type IN ('可预约', '禁入')),
  CONSTRAINT chk_time_rules_range CHECK (start_time < end_time)
);

CREATE INDEX IF NOT EXISTS idx_time_rules_weekday_rule_type ON time_rules (weekday, rule_type);

CREATE TABLE IF NOT EXISTS reviewer_rules (
  id                  VARCHAR(36) PRIMARY KEY,
  visitor_type_id     VARCHAR(36) NULL,
  gate_id             VARCHAR(36) NULL,
  start_time          TIME        NULL,
  end_time            TIME        NULL,
  reviewer_kind       VARCHAR(20) NOT NULL,
  reviewer_user_id    VARCHAR(36) NULL,
  declaration_order   INTEGER     NOT NULL,
  status              VARCHAR(10) NOT NULL DEFAULT 'active',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_reviewer_rules_kind CHECK (reviewer_kind IN ('host', 'admin', 'designated')),
  CONSTRAINT chk_reviewer_rules_status CHECK (status IN ('active', 'inactive')),
  CONSTRAINT chk_reviewer_rules_time_range CHECK (start_time IS NULL OR end_time IS NULL OR start_time < end_time),
  CONSTRAINT chk_reviewer_rules_designated CHECK (reviewer_kind <> 'designated' OR reviewer_user_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_reviewer_rules_status_declaration_order ON reviewer_rules (status, declaration_order);

CREATE TABLE IF NOT EXISTS data_dictionary (
  id            VARCHAR(36) PRIMARY KEY,
  dict_type     VARCHAR(30) NOT NULL,
  dict_key      VARCHAR(30) NOT NULL,
  dict_label    VARCHAR(50) NOT NULL,
  sort_order    INTEGER     NOT NULL DEFAULT 0,
  status        VARCHAR(10) NOT NULL DEFAULT 'active',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_data_dictionary_type_key UNIQUE (dict_type, dict_key),
  CONSTRAINT chk_data_dictionary_status CHECK (status IN ('active', 'inactive'))
);

CREATE INDEX IF NOT EXISTS idx_data_dictionary_type_status_sort_order ON data_dictionary (dict_type, status, sort_order);

COMMIT;

-- ===== 003-visit.sql =====
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

-- ===== 004-notify.sql =====
BEGIN;

-- 通知上下文：站内消息与渠道开关

CREATE TABLE IF NOT EXISTS notifications (
  id                VARCHAR(36)  PRIMARY KEY,
  recipient_type    VARCHAR(10)  NOT NULL,
  recipient_id      VARCHAR(36)  NULL,
  recipient_name    VARCHAR(50)  NOT NULL DEFAULT '',
  recipient_phone   VARCHAR(20)  NULL,
  template_type     VARCHAR(30)  NOT NULL,
  title             VARCHAR(100) NOT NULL,
  content           VARCHAR(500) NOT NULL,
  business_type     VARCHAR(30)  NOT NULL,
  business_id       VARCHAR(36)  NULL,
  is_security       BOOLEAN      NOT NULL DEFAULT false,
  read_at           TIMESTAMPTZ  NULL,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT chk_notifications_recipient_type CHECK (recipient_type IN ('user', 'visitor')),
  CONSTRAINT chk_notifications_template_type CHECK (template_type IN ('提交通知', '审核结果', '改期提议', '改期确认结果', '到访提醒', '黑名单命中', '超时未离'))
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_type_recipient_id_read_at_created_at ON notifications (recipient_type, recipient_id, read_at, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_business_type_business_id ON notifications (business_type, business_id);

CREATE TABLE IF NOT EXISTS notification_channels (
  channel_code  VARCHAR(20) PRIMARY KEY,
  enabled       BOOLEAN     NOT NULL,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by    VARCHAR(36) NULL,
  CONSTRAINT chk_notification_channels_channel_code CHECK (channel_code IN ('站内', '短信', '企微'))
);

COMMIT;

-- ===== 005-compliance.sql =====
BEGIN;

-- 合规上下文：个人信息副本与人工清除案件

CREATE TABLE IF NOT EXISTS privacy_cases (
  id              VARCHAR(36)  PRIMARY KEY,
  appointment_id  VARCHAR(36)  NULL,
  case_type       VARCHAR(20)  NOT NULL,
  requested_by    VARCHAR(36)  NULL,
  status          VARCHAR(20)  NOT NULL,
  note            VARCHAR(200) NOT NULL DEFAULT '',
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  completed_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT chk_privacy_cases_type CHECK (case_type IN ('信息副本', '人工清除')),
  CONSTRAINT chk_privacy_cases_status CHECK (status IN ('已完成', '失败'))
);

CREATE INDEX IF NOT EXISTS idx_privacy_cases_created_at ON privacy_cases (created_at DESC);

COMMIT;
