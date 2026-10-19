import { Router } from 'express';

import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { paginated, success } from '../../../shared/http/envelope.js';
import * as notify from '../index.js';
import type { NotificationDto } from '../index.js';

const router = Router();

function apiNotification(item: NotificationDto): Record<string, unknown> {
  return {
    id: item.id,
    recipient_type: item.recipientType,
    recipient_id: item.recipientId,
    recipient_name: item.recipientName,
    recipient_phone: item.recipientPhone,
    template_type: item.templateType,
    title: item.title,
    content: item.content,
    business_type: item.businessType,
    business_id: item.businessId,
    is_security: item.isSecurity,
    read_at: item.readAt,
    created_at: item.createdAt,
  };
}

router.get(
  '/notifications/unread-count',
  requirePermission('notify:notification:read'),
  asyncHandler(async (req, res) => {
    const count = await notify.unreadCountForUser(req.currentUser!.id);
    return success(res, { unread_count: count });
  }),
);

router.get(
  '/notifications',
  requirePermission('notify:notification:read'),
  asyncHandler(async (req, res) => {
    const result = await notify.listNotificationsForUser(req.currentUser!.id, req.query);
    return paginated(
      res,
      result.items.map(apiNotification),
      result.total,
      result.page,
      result.pageSize,
    );
  }),
);

router.put(
  '/notifications/read-all',
  requirePermission('notify:notification:read'),
  asyncHandler(async (req, res) => {
    const updated = await notify.markAllReadForUser(req.currentUser!.id);
    return success(res, { updated });
  }),
);

router.put(
  '/notifications/:id/read',
  requirePermission('notify:notification:read'),
  asyncHandler(async (req, res) => {
    const result = await notify.markReadForUser(req.params.id, req.currentUser!.id);
    return success(res, { id: result.id, read_at: result.readAt });
  }),
);

export default router;
