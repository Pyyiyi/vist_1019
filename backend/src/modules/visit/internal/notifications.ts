import { getFirstAdminUser, getUserById } from '../../access/index.js';
import { publishNotification, publishSecurityNotification, renderTemplate } from '../../notify/index.js';
import { logger } from '../../../shared/logger.js';
import { query } from '../../../shared/db/pool.js';
import type { AppointmentRow } from './types.js';
import { iso } from './types.js';

type TemplateInput = Parameters<typeof renderTemplate>[1];

async function publishForUser(
  userId: string,
  templateType: Parameters<typeof renderTemplate>[0],
  input: TemplateInput,
  businessId: string,
  security = false,
): Promise<void> {
  const user = await getUserById(userId);
  if (!user) return;
  const rendered = renderTemplate(templateType, input);
  const payload = {
    recipientType: 'user' as const,
    recipientId: user.id,
    recipientName: user.displayName,
    recipientPhone: null,
    templateType,
    title: rendered.title,
    content: rendered.content,
    businessType: 'appointment',
    businessId,
    isSecurity: security,
  };
  if (security) await publishSecurityNotification(payload);
  else await publishNotification(payload);
}

export async function notifyReviewer(row: AppointmentRow, input: TemplateInput = {}): Promise<void> {
  await notifyReviewerTemplate(row, '提交通知', input);
}

export async function notifyReviewerTemplate(
  row: AppointmentRow,
  templateType: Parameters<typeof renderTemplate>[0],
  input: TemplateInput = {},
): Promise<void> {
  if (!row.reviewer_id) return;
  await publishForUser(row.reviewer_id, templateType, {
    visitorName: row.visitor_name ?? '访客',
    visitStart: row.visit_start,
    visitEnd: row.visit_end,
    ...input,
  }, row.id);
}

export async function notifyVisitor(
  row: AppointmentRow,
  templateType: Parameters<typeof renderTemplate>[0],
  input: TemplateInput = {},
): Promise<void> {
  const rendered = renderTemplate(templateType, {
    visitorName: row.visitor_name ?? '访客',
    visitStart: row.visit_start,
    visitEnd: row.visit_end,
    appointmentNo: row.appoint_no,
    ...input,
  });
  await publishNotification({
    recipientType: 'visitor',
    recipientId: row.id,
    recipientName: row.visitor_name ?? '访客',
    recipientPhone: row.visitor_phone,
    templateType,
    title: rendered.title,
    content: rendered.content,
    businessType: 'appointment',
    businessId: row.id,
    isSecurity: false,
  });
}

export async function notifyBlacklist(row: AppointmentRow, maskedIdNo: string): Promise<void> {
  const input = {
    visitorName: row.visitor_name ?? '访客',
    visitStart: row.visit_start,
    visitEnd: row.visit_end,
    maskedIdNo,
  };
  const recipients = await query<{ id: string }>(
    "SELECT id FROM users WHERE role_code IN ('admin', 'guard') AND status = 'active' ORDER BY role_code, created_at ASC",
  );
  for (const recipient of recipients.rows) {
    await publishForUser(recipient.id, '黑名单命中', input, row.id, true);
  }
  if (recipients.rows.length === 0) {
    const admin = await getFirstAdminUser();
    if (admin) await publishForUser(admin.id, '黑名单命中', input, row.id, true);
  }
}

export async function safeNotify(task: () => Promise<void>): Promise<void> {
  try {
    await task();
  } catch (error) {
    logger.error('来访通知发送失败', { error: error instanceof Error ? error.message : String(error) });
  }
}

export function appointmentNotificationInput(row: AppointmentRow): TemplateInput {
  return {
    visitorName: row.visitor_name ?? '访客',
    visitStart: iso(row.visit_start) ?? undefined,
    visitEnd: iso(row.visit_end) ?? undefined,
    appointmentNo: row.appoint_no,
  };
}
