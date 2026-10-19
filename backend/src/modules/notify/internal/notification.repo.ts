import type { PoolClient } from 'pg';

import { query } from '../../../shared/db/pool.js';

export type DbClient = Pick<PoolClient, 'query'>;

export type NotificationRow = {
  id: string;
  recipient_type: 'user' | 'visitor';
  recipient_id: string | null;
  recipient_name: string;
  recipient_phone: string | null;
  template_type: string;
  title: string;
  content: string;
  business_type: string;
  business_id: string | null;
  is_security: boolean;
  read_at: Date | string | null;
  created_at: Date | string;
};

export type InsertNotificationInput = {
  id: string;
  recipientType: 'user' | 'visitor';
  recipientId: string;
  recipientName: string;
  recipientPhone: string | null;
  templateType: string;
  title: string;
  content: string;
  businessType: string;
  businessId: string | null;
  isSecurity: boolean;
};

export type NotificationListOptions = {
  recipientId: string;
  unreadOnly: boolean;
  limit: number;
  offset: number;
};

export type NotificationOwnerRow = {
  id: string;
  recipient_type: 'user' | 'visitor';
  recipient_id: string | null;
  read_at: Date | string | null;
};

export type ChannelRow = {
  channel_code: '站内' | '短信' | '企微';
  enabled: boolean;
  updated_at: Date | string;
  updated_by: string | null;
};

export type ReminderAppointmentRow = {
  id: string;
  host_user_id: string;
  host_name: string;
  host_phone: string | null;
  visitor_name: string | null;
  visit_start: Date | string;
  visit_end: Date | string;
  gate_name: string | null;
};

export type OverdueAppointmentRow = {
  id: string;
  visitor_name: string | null;
  checkin_at: Date | string | null;
  visit_start: Date | string;
  visit_end: Date | string;
};

export type SecurityRecipientRow = {
  id: string;
  display_name: string;
  phone: string | null;
};

type CountRow = { count: number };

function executor(client?: DbClient): DbClient {
  return client ?? ({ query } as unknown as DbClient);
}

export async function insertNotification(
  client: DbClient | undefined,
  input: InsertNotificationInput,
): Promise<NotificationRow | null> {
  const result = await executor(client).query<NotificationRow>(
    `INSERT INTO notifications (
       id, recipient_type, recipient_id, recipient_name, recipient_phone,
       template_type, title, content, business_type, business_id, is_security
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
     ON CONFLICT DO NOTHING
     RETURNING *`,
    [
      input.id,
      input.recipientType,
      input.recipientId,
      input.recipientName,
      input.recipientPhone,
      input.templateType,
      input.title,
      input.content,
      input.businessType,
      input.businessId,
      input.isSecurity,
    ],
  );
  return result.rows[0] ?? null;
}

export async function findDuplicateNotification(
  client: DbClient | undefined,
  input: Pick<InsertNotificationInput, 'recipientType' | 'recipientId' | 'templateType' | 'businessId'>,
): Promise<NotificationRow | null> {
  const result = await executor(client).query<NotificationRow>(
    `SELECT *
       FROM notifications
      WHERE recipient_type = $1
        AND recipient_id = $2
        AND template_type = $3
        AND business_id IS NOT DISTINCT FROM $4
        AND (created_at AT TIME ZONE 'Asia/Shanghai')::date = (now() AT TIME ZONE 'Asia/Shanghai')::date
      ORDER BY created_at DESC
      LIMIT 1`,
    [input.recipientType, input.recipientId, input.templateType, input.businessId],
  );
  return result.rows[0] ?? null;
}

export async function listNotifications(
  client: DbClient | undefined,
  options: NotificationListOptions,
): Promise<{ rows: NotificationRow[]; total: number }> {
  const conditions = ["recipient_type = 'user'", 'recipient_id = $1'];
  const params: unknown[] = [options.recipientId];

  if (options.unreadOnly) {
    conditions.push('read_at IS NULL');
  }

  const where = conditions.join(' AND ');
  const countResult = await executor(client).query<CountRow>(
    `SELECT COUNT(*)::int AS count FROM notifications WHERE ${where}`,
    params,
  );
  const itemParams = [...params, options.limit, options.offset];
  const result = await executor(client).query<NotificationRow>(
    `SELECT *
       FROM notifications
      WHERE ${where}
      ORDER BY created_at DESC, id DESC
      LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
    itemParams,
  );

  return { rows: result.rows, total: countResult.rows[0]?.count ?? 0 };
}

export async function countUnread(client: DbClient | undefined, recipientId: string): Promise<number> {
  const result = await executor(client).query<CountRow>(
    `SELECT COUNT(*)::int AS count
       FROM notifications
      WHERE recipient_type = 'user'
        AND recipient_id = $1
        AND read_at IS NULL`,
    [recipientId],
  );
  return result.rows[0]?.count ?? 0;
}

export async function findNotificationOwner(
  client: DbClient | undefined,
  id: string,
): Promise<NotificationOwnerRow | null> {
  const result = await executor(client).query<NotificationOwnerRow>(
    'SELECT id, recipient_type, recipient_id, read_at FROM notifications WHERE id = $1',
    [id],
  );
  return result.rows[0] ?? null;
}

export async function markRead(
  client: DbClient | undefined,
  id: string,
  recipientId: string,
): Promise<NotificationOwnerRow | null> {
  const result = await executor(client).query<NotificationOwnerRow>(
    `UPDATE notifications
        SET read_at = COALESCE(read_at, now())
      WHERE id = $1
        AND recipient_type = 'user'
        AND recipient_id = $2
      RETURNING id, recipient_type, recipient_id, read_at`,
    [id, recipientId],
  );
  return result.rows[0] ?? null;
}

export async function markAllRead(client: DbClient | undefined, recipientId: string): Promise<number> {
  const result = await executor(client).query(
    `UPDATE notifications
        SET read_at = now()
      WHERE recipient_type = 'user'
        AND recipient_id = $1
        AND read_at IS NULL`,
    [recipientId],
  );
  return result.rowCount ?? 0;
}

export async function listChannels(client?: DbClient): Promise<ChannelRow[]> {
  const result = await executor(client).query<ChannelRow>(
    `SELECT channel_code, enabled, updated_at, updated_by
       FROM notification_channels
      ORDER BY CASE channel_code WHEN '站内' THEN 0 WHEN '短信' THEN 1 ELSE 2 END`,
  );
  return result.rows;
}

export async function updateChannel(
  client: DbClient,
  channelCode: '短信' | '企微',
  enabled: boolean,
  updatedBy: string,
): Promise<void> {
  await client.query(
    `UPDATE notification_channels
        SET enabled = $2, updated_at = now(), updated_by = $3
      WHERE channel_code = $1`,
    [channelCode, enabled, updatedBy],
  );
}

export async function findDueReminderAppointments(limit = 100): Promise<ReminderAppointmentRow[]> {
  const result = await query<ReminderAppointmentRow>(
    `SELECT a.id,
            u.id AS host_user_id,
            u.display_name AS host_name,
            u.phone AS host_phone,
            a.visitor_name,
            a.visit_start,
            a.visit_end,
            g.name AS gate_name
       FROM appointments a
       JOIN users u ON u.host_id = a.host_id AND u.status = 'active'
       LEFT JOIN gates g ON g.id = a.expected_gate_id
      WHERE a.status = '已通过'
        AND a.reminder_sent_at IS NULL
        AND a.visit_start - INTERVAL '30 minutes' <= now()
        AND now() < a.visit_start
      ORDER BY a.visit_start ASC
      LIMIT $1`,
    [limit],
  );
  return result.rows;
}

export async function claimReminder(appointmentId: string): Promise<boolean> {
  const result = await query(
    `UPDATE appointments
        SET reminder_sent_at = now(), updated_at = now()
      WHERE id = $1
        AND reminder_sent_at IS NULL
        AND status = '已通过'
        AND visit_start - INTERVAL '30 minutes' <= now()
        AND now() < visit_start`,
    [appointmentId],
  );
  return (result.rowCount ?? 0) === 1;
}

export async function findOverdueAppointments(limit = 100): Promise<OverdueAppointmentRow[]> {
  const result = await query<OverdueAppointmentRow>(
    `SELECT id, visitor_name, checkin_at, visit_start, visit_end
       FROM appointments
      WHERE status = '已到访(在校中)'
        AND visit_end + INTERVAL '60 minutes' < now()
      ORDER BY visit_end ASC
      LIMIT $1`,
    [limit],
  );
  return result.rows;
}

export async function hasOverdueNotificationToday(
  client: DbClient,
  appointmentId: string,
): Promise<boolean> {
  const result = await client.query<{ exists: boolean }>(
    `SELECT EXISTS(
       SELECT 1
         FROM notifications
        WHERE template_type = '超时未离'
          AND business_id = $1
          AND (created_at AT TIME ZONE 'Asia/Shanghai')::date
              = (now() AT TIME ZONE 'Asia/Shanghai')::date
     ) AS exists`,
    [appointmentId],
  );
  return result.rows[0]?.exists ?? false;
}

export async function listSecurityRecipients(client?: DbClient): Promise<SecurityRecipientRow[]> {
  const result = await executor(client).query<SecurityRecipientRow>(
    `SELECT id, display_name, phone
       FROM users
      WHERE role_code IN ('admin', 'guard')
        AND status = 'active'
      ORDER BY CASE role_code WHEN 'admin' THEN 0 ELSE 1 END, username ASC`,
  );
  return result.rows;
}
