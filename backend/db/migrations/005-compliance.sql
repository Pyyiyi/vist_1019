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
