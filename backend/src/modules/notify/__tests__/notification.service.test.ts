import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  insertNotification: vi.fn(),
  findDuplicateNotification: vi.fn(),
  listNotifications: vi.fn(),
  countUnread: vi.fn(),
  findNotificationOwner: vi.fn(),
  markRead: vi.fn(),
  markAllRead: vi.fn(),
  listChannels: vi.fn(),
  updateChannel: vi.fn(),
  findDueReminderAppointments: vi.fn(),
  claimReminder: vi.fn(),
  findOverdueAppointments: vi.fn(),
  hasOverdueNotificationToday: vi.fn(),
  listSecurityRecipients: vi.fn(),
  emitNotification: vi.fn(),
  withTransaction: vi.fn(),
}));

vi.mock('../../../realtime/io.js', () => ({ emitNotification: mocks.emitNotification }));
vi.mock('../../../shared/db/pool.js', () => ({ withTransaction: mocks.withTransaction }));
vi.mock('../internal/notification.repo.js', () => ({
  insertNotification: mocks.insertNotification,
  findDuplicateNotification: mocks.findDuplicateNotification,
  listNotifications: mocks.listNotifications,
  countUnread: mocks.countUnread,
  findNotificationOwner: mocks.findNotificationOwner,
  markRead: mocks.markRead,
  markAllRead: mocks.markAllRead,
  listChannels: mocks.listChannels,
  updateChannel: mocks.updateChannel,
  findDueReminderAppointments: mocks.findDueReminderAppointments,
  claimReminder: mocks.claimReminder,
  findOverdueAppointments: mocks.findOverdueAppointments,
  hasOverdueNotificationToday: mocks.hasOverdueNotificationToday,
  listSecurityRecipients: mocks.listSecurityRecipients,
}));

import {
  listNotificationChannels,
  listNotificationsForUser,
  listNotificationsForVisitor,
  markAllReadForUser,
  markReadForUser,
  publishNotification,
  publishSecurityNotification,
  runReminderJob,
  unreadCountForUser,
} from '../internal/notification.service.js';

const baseInput = {
  recipientType: 'user' as const,
  recipientId: 'user-1',
  recipientName: '系统管理员',
  recipientPhone: '13900139000',
  templateType: '到访提醒' as const,
  title: '您的访客即将到访',
  content: '访客陈晨即将到访',
  businessType: 'appointment',
  businessId: 'appointment-1',
  isSecurity: false,
};

function notificationRow(overrides: Record<string, unknown> = {}) {
  return {
    id: 'notification-1',
    recipient_type: 'user',
    recipient_id: 'user-1',
    recipient_name: '系统管理员',
    recipient_phone: '13900139000',
    template_type: '到访提醒',
    title: '您的访客即将到访',
    content: '访客陈晨即将到访',
    business_type: 'appointment',
    business_id: 'appointment-1',
    is_security: false,
    read_at: null,
    created_at: '2026-10-19T04:00:00.000Z',
    ...overrides,
  };
}

beforeEach(() => {
  vi.clearAllMocks();
  mocks.withTransaction.mockImplementation(async (callback: (client: unknown) => unknown) =>
    callback({ query: vi.fn().mockResolvedValue({ rows: [] }) }),
  );
});

describe('通知服务', () => {
  it('inserts a user notification and emits notification:new', async () => {
    mocks.insertNotification.mockResolvedValue(notificationRow());

    await expect(publishNotification(baseInput)).resolves.toEqual({ id: 'notification-1' });

    expect(mocks.insertNotification).toHaveBeenCalledWith(
      undefined,
      expect.objectContaining({
        recipientId: 'user-1',
        isSecurity: false,
        businessId: 'appointment-1',
      }),
    );
    expect(mocks.emitNotification).toHaveBeenCalledWith('user-1', {
      id: 'notification-1',
      title: '您的访客即将到访',
      templateType: '到访提醒',
      createdAt: '2026-10-19T04:00:00.000Z',
    });
  });

  it('forces security notifications to is_security=true', async () => {
    mocks.insertNotification.mockResolvedValue(notificationRow({ is_security: true }));

    await publishSecurityNotification(baseInput);

    expect(mocks.insertNotification).toHaveBeenCalledWith(
      undefined,
      expect.objectContaining({ isSecurity: true }),
    );
  });

  it('does not emit websocket events for visitor recipients', async () => {
    mocks.insertNotification.mockResolvedValue(
      notificationRow({ recipient_type: 'visitor', recipient_id: 'appointment-1' }),
    );

    await publishNotification({ ...baseInput, recipientType: 'visitor' });

    expect(mocks.emitNotification).not.toHaveBeenCalled();
  });

  it('lists only the current user and honors unread_only', async () => {
    mocks.listNotifications.mockResolvedValue({
      rows: [notificationRow()],
      total: 1,
    });

    const result = await listNotificationsForUser('user-1', {
      unread_only: 'true',
      page: '1',
      page_size: '20',
    });

    expect(mocks.listNotifications).toHaveBeenCalledWith(undefined, {
      recipientType: 'user',
      recipientId: 'user-1',
      unreadOnly: true,
      limit: 20,
      offset: 0,
    });
    expect(result).toMatchObject({ total: 1, page: 1, pageSize: 20 });
    expect(result.items[0]).toMatchObject({
      id: 'notification-1',
      templateType: '到访提醒',
      businessId: 'appointment-1',
      readAt: null,
    });
  });

  it('lists visitor notifications by bound appointment id', async () => {
    mocks.listNotifications.mockResolvedValue({
      rows: [notificationRow({ recipient_type: 'visitor', recipient_id: 'appointment-1' })],
      total: 1,
    });

    const result = await listNotificationsForVisitor('appointment-1', { page: '1', page_size: '50' });

    expect(mocks.listNotifications).toHaveBeenCalledWith(undefined, {
      recipientType: 'visitor',
      recipientId: 'appointment-1',
      unreadOnly: false,
      limit: 50,
      offset: 0,
    });
    expect(result.items[0]).toMatchObject({ id: 'notification-1', businessId: 'appointment-1' });
  });

  it('rejects marking another user notification as read', async () => {
    mocks.findNotificationOwner.mockResolvedValue({
      id: 'notification-1',
      recipient_type: 'user',
      recipient_id: 'other-user',
      read_at: null,
    });

    await expect(markReadForUser('notification-1', 'user-1')).rejects.toThrow(
      '您无权查看该记录',
    );
    expect(mocks.markRead).not.toHaveBeenCalled();
  });

  it('marks all notifications read and returns the updated count', async () => {
    mocks.markAllRead.mockResolvedValue(3);

    await expect(markAllReadForUser('user-1')).resolves.toBe(3);
    expect(mocks.markAllRead).toHaveBeenCalledWith(undefined, 'user-1');
  });

  it('returns the unread count as an integer', async () => {
    mocks.countUnread.mockResolvedValue(4);

    await expect(unreadCountForUser('user-1')).resolves.toBe(4);
  });

  it('maps channel rows to camelCase DTOs', async () => {
    mocks.listChannels.mockResolvedValue([
      {
        channel_code: '站内',
        enabled: true,
        updated_at: '2026-10-19T04:00:00.000Z',
        updated_by: null,
      },
    ]);

    await expect(listNotificationChannels()).resolves.toEqual([
      {
        channelCode: '站内',
        enabled: true,
        updatedAt: '2026-10-19T04:00:00.000Z',
        updatedBy: null,
      },
    ]);
  });

  it('sends a reminder once and skips appointments that were already claimed', async () => {
    mocks.findDueReminderAppointments.mockResolvedValue([
      {
        id: 'appointment-1',
        host_user_id: 'host-user-1',
        host_name: '李明',
        host_phone: '13900139001',
        visitor_name: '陈晨',
        visit_start: '2026-10-19T14:00:00+08:00',
        visit_end: '2026-10-19T15:00:00+08:00',
        gate_name: '南门',
      },
      {
        id: 'appointment-2',
        host_user_id: 'host-user-1',
        host_name: '李明',
        host_phone: '13900139001',
        visitor_name: '王五',
        visit_start: '2026-10-19T16:00:00+08:00',
        visit_end: '2026-10-19T17:00:00+08:00',
        gate_name: '南门',
      },
    ]);
    mocks.claimReminder
      .mockResolvedValueOnce(true)
      .mockResolvedValueOnce(false);
    mocks.insertNotification.mockResolvedValue(notificationRow());

    await runReminderJob();

    expect(mocks.claimReminder).toHaveBeenCalledTimes(2);
    expect(mocks.insertNotification).toHaveBeenCalledTimes(1);
    expect(mocks.insertNotification).toHaveBeenCalledWith(
      undefined,
      expect.objectContaining({
        recipientId: 'host-user-1',
        templateType: '到访提醒',
        businessId: 'appointment-1',
        isSecurity: false,
      }),
    );
  });
});
