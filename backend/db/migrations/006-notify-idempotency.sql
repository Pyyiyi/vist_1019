BEGIN;

-- 超时未离每日每接收人最多一条，保证定时任务幂等
CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_overdue_daily
  ON notifications (
    business_id,
    recipient_id,
    ((created_at AT TIME ZONE 'Asia/Shanghai')::date)
  )
  WHERE template_type = '超时未离';

COMMIT;
