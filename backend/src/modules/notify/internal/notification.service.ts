import { AppError } from '../../../shared/http/errors.js';
import { forbidden, notFound, unprocessable } from '../../../shared/http/errors.js';
import { parsePagination } from '../../../shared/http/pagination.js';
import { MESSAGES } from '../../../shared/constants/messages.js';
import { withTransaction } from '../../../shared/db/pool.js';
import { logger } from '../../../shared/logger.js';
import { emitNotification } from '../../../realtime/io.js';
import { formatMinute } from '../../../shared/utils/ids.js';
import { newUuid } from '../../../shared/utils/ids.js';
import {
  isNotificationTemplateType,
  renderTemplate,
  type NotificationTemplateType,
  type TemplateRenderInput,
} from './domain/templates.js';
import * as repo from './notification.repo.js';
import type { ChannelRow, NotificationRow } from './notification.repo.js';

export type PublishNotificationInput = {
  recipientType: 'user' | 'visitor';
  recipientId: string;
  recipientName: string;
  recipientPhone?: string | null;
  templateType: NotificationTemplateType;
  title: string;
  content: string;
  businessType: string;
  businessId: string | null;
  isSecurity: boolean;
};

export type NotificationDto = {
  id: string;
  recipientType: 'user' | 'visitor';
  recipientId: string | null;
  recipientName: string;
  recipientPhone: string | null;
  templateType: string;
  title: string;
  content: string;
  businessType: string;
  businessId: string | null;
  isSecurity: boolean;
  readAt: string | null;
  createdAt: string;
};

export type NotificationListInput = {
  unread_only?: unknown;
  unreadOnly?: unknown;
  page?: unknown;
  page_size?: unknown;
};

export type NotificationChannelDto = {
  channelCode: '站内' | '短信' | '企微';
  enabled: boolean;
  updatedAt: string;
  updatedBy: string | null;
};

export type UpdateChannelInput = {
  sms?: unknown;
  wecom?: unknown;
  in_app?: unknown;
  inApp?: unknown;
  '站内'?: unknown;
};

export type ChannelActor = {
  id: string;
};

function iso(value: Date | string | null): string | null {
  if (value === null) {
    return null;
  }
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}

function toNotificationDto(row: NotificationRow): NotificationDto {
  return {
    id: row.id,
    recipientType: row.recipient_type,
    recipientId: row.recipient_id,
    recipientName: row.recipient_name,
    recipientPhone: row.recipient_phone,
    templateType: row.template_type,
    title: row.title,
    content: row.content,
    businessType: row.business_type,
    businessId: row.business_id,
    isSecurity: row.is_security,
    readAt: iso(row.read_at),
    createdAt: iso(row.created_at) ?? new Date(0).toISOString(),
  };
}

function toChannelDto(row: ChannelRow): NotificationChannelDto {
  return {
    channelCode: row.channel_code,
    enabled: row.enabled,
    updatedAt: iso(row.updated_at) ?? new Date(0).toISOString(),
    updatedBy: row.updated_by,
  };
}

function booleanQuery(value: unknown): boolean {
  return value === true || value === 'true' || value === 1 || value === '1';
}

function assertPublishInput(input: PublishNotificationInput): void {
  if (!input.recipientId?.trim()) {
    throw unprocessable('请选择消息接收人', 'recipient_id');
  }
  if (!isNotificationTemplateType(input.templateType)) {
    throw unprocessable('通知模板类型不正确', 'template_type');
  }
  if (!input.title?.trim()) {
    throw unprocessable('消息标题不能为空', 'title');
  }
  if (!input.content?.trim()) {
    throw unprocessable('消息正文不能为空', 'content');
  }
  if (!input.businessType?.trim()) {
    throw unprocessable('业务类型不能为空', 'business_type');
  }
}

async function insertAndEmit(
  input: PublishNotificationInput,
  forceSecurity: boolean,
): Promise<{ id: string }> {
  assertPublishInput(input);
  const isSecurity = forceSecurity || input.isSecurity;
  const inserted = await repo.insertNotification(undefined, {
    id: newUuid(),
    recipientType: input.recipientType,
    recipientId: input.recipientId,
    recipientName: input.recipientName ?? '',
    recipientPhone: input.recipientPhone ?? null,
    templateType: input.templateType,
    title: input.title.trim(),
    content: input.content.trim(),
    businessType: input.businessType,
    businessId: input.businessId,
    isSecurity,
  });

  const row = inserted ?? (await repo.findDuplicateNotification(undefined, {
    recipientType: input.recipientType,
    recipientId: input.recipientId,
    templateType: input.templateType,
    businessId: input.businessId,
  }));

  if (!row) {
    throw new AppError(500, 50001, MESSAGES.INTERNAL_ERROR);
  }

  if (inserted && input.recipientType === 'user') {
    emitNotification(input.recipientId, {
      id: row.id,
      title: row.title,
      templateType: row.template_type,
      createdAt: iso(row.created_at) ?? new Date().toISOString(),
    });
  }

  return { id: row.id };
}

export async function publishNotification(input: PublishNotificationInput): Promise<{ id: string }> {
  return insertAndEmit(input, false);
}

export async function publishSecurityNotification(
  input: PublishNotificationInput,
): Promise<{ id: string }> {
  return insertAndEmit(input, true);
}

export async function listNotificationsForUser(
  userId: string,
  input: NotificationListInput,
): Promise<{ items: NotificationDto[]; total: number; page: number; pageSize: number }> {
  const pagination = parsePagination(input as Record<string, unknown>);
  const unreadOnly = booleanQuery(input.unread_only ?? input.unreadOnly);
  const result = await repo.listNotifications(undefined, {
    recipientId: userId,
    unreadOnly,
    limit: pagination.pageSize,
    offset: pagination.offset,
  });

  return {
    items: result.rows.map(toNotificationDto),
    total: result.total,
    page: pagination.page,
    pageSize: pagination.pageSize,
  };
}

export async function unreadCountForUser(userId: string): Promise<number> {
  return repo.countUnread(undefined, userId);
}

export async function markReadForUser(
  id: string,
  userId: string,
): Promise<{ id: string; readAt: string }> {
  const row = await repo.findNotificationOwner(undefined, id);
  if (!row) {
    throw notFound(MESSAGES.NOT_FOUND);
  }
  if (row.recipient_type !== 'user' || row.recipient_id !== userId) {
    throw forbidden(MESSAGES.OBJECT_FORBIDDEN);
  }

  const updated = await repo.markRead(undefined, id, userId);
  if (!updated) {
    throw notFound(MESSAGES.NOT_FOUND);
  }

  return { id: updated.id, readAt: iso(updated.read_at) ?? new Date().toISOString() };
}

export async function markAllReadForUser(userId: string): Promise<number> {
  return repo.markAllRead(undefined, userId);
}

export async function listNotificationChannels(): Promise<NotificationChannelDto[]> {
  return (await repo.listChannels()).map(toChannelDto);
}

export async function updateNotificationChannels(
  input: UpdateChannelInput,
  actor: ChannelActor,
): Promise<NotificationChannelDto[]> {
  const stationFlag = input.in_app ?? input.inApp ?? input['站内'];
  if (stationFlag === false) {
    throw unprocessable(
      '站内消息为安全类通知的固定通道，不能关闭',
      'in_app',
    );
  }
  if (typeof input.sms !== 'boolean') {
    throw unprocessable('请选择短信渠道状态', 'sms');
  }
  if (typeof input.wecom !== 'boolean') {
    throw unprocessable('请选择企业微信渠道状态', 'wecom');
  }

  return withTransaction(async (client) => {
    await repo.updateChannel(client, '短信', input.sms as boolean, actor.id);
    await repo.updateChannel(client, '企微', input.wecom as boolean, actor.id);
    return (await repo.listChannels(client)).map(toChannelDto);
  });
}

function stayDuration(checkinAt: Date | string | null, fallback: Date | string): string {
  const start = new Date(checkinAt ?? fallback).getTime();
  if (Number.isNaN(start)) {
    return '超过规定时长';
  }
  const minutes = Math.max(0, Math.floor((Date.now() - start) / 60_000));
  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;
  return `${hours}小时${remainder}分钟`;
}

export async function runReminderJob(): Promise<void> {
  const appointments = await repo.findDueReminderAppointments();

  for (const appointment of appointments) {
    try {
      const claimed = await repo.claimReminder(appointment.id);
      if (!claimed) {
        continue;
      }

      const rendered = renderTemplate('到访提醒', {
        visitorName: appointment.visitor_name ?? '访客',
        visitStart: appointment.visit_start,
        visitEnd: appointment.visit_end,
        gateName: appointment.gate_name ?? '校门',
      } satisfies TemplateRenderInput);

      await publishNotification({
        recipientType: 'user',
        recipientId: appointment.host_user_id,
        recipientName: appointment.host_name,
        recipientPhone: appointment.host_phone,
        templateType: '到访提醒',
        title: rendered.title,
        content: rendered.content,
        businessType: 'appointment',
        businessId: appointment.id,
        isSecurity: false,
      });
    } catch (error) {
      logger.error('到访提醒发送失败', {
        appointmentId: appointment.id,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
}

export async function runOverdueJob(): Promise<void> {
  const appointments = await repo.findOverdueAppointments();
  if (appointments.length === 0) {
    return;
  }

  const recipients = await repo.listSecurityRecipients();
  if (recipients.length === 0) {
    return;
  }

  for (const appointment of appointments) {
    try {
      const rendered = renderTemplate('超时未离', {
        visitorName: appointment.visitor_name ?? '访客',
        checkinAt: appointment.checkin_at ?? appointment.visit_start,
        stayDuration: stayDuration(appointment.checkin_at, appointment.visit_start),
      });
      const lockDay = formatMinute(new Date()).slice(0, 10);

      const inserted = await withTransaction(async (client) => {
        await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [
          `overdue:${appointment.id}:${lockDay}`,
        ]);
        if (await repo.hasOverdueNotificationToday(client, appointment.id)) {
          return [] as NotificationRow[];
        }

        const rows: NotificationRow[] = [];
        for (const recipient of recipients) {
          const row = await repo.insertNotification(client, {
            id: newUuid(),
            recipientType: 'user',
            recipientId: recipient.id,
            recipientName: recipient.display_name,
            recipientPhone: recipient.phone,
            templateType: '超时未离',
            title: rendered.title,
            content: rendered.content,
            businessType: 'appointment',
            businessId: appointment.id,
            isSecurity: true,
          });
          if (row) {
            rows.push(row);
          }
        }
        return rows;
      });

      for (const row of inserted) {
        if (row.recipient_id) {
          emitNotification(row.recipient_id, {
            id: row.id,
            title: row.title,
            templateType: row.template_type,
            createdAt: iso(row.created_at) ?? new Date().toISOString(),
          });
        }
      }
    } catch (error) {
      logger.error('超时未离提醒发送失败', {
        appointmentId: appointment.id,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
}
