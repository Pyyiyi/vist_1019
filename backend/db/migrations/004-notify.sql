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
