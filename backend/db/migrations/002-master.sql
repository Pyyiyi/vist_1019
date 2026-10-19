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
