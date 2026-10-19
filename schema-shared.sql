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
