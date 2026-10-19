import { Router } from 'express';

import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { success } from '../../../shared/http/envelope.js';
import * as notify from '../index.js';
import type { NotificationChannelDto } from '../index.js';

const router = Router();

function apiChannel(item: NotificationChannelDto): Record<string, unknown> {
  return {
    channel_code: item.channelCode,
    enabled: item.enabled,
    updated_at: item.updatedAt,
    updated_by: item.updatedBy,
  };
}

router.get(
  '/system/notification-channels',
  requirePermission('notify:channel:manage'),
  asyncHandler(async (_req, res) => {
    const channels = await notify.listNotificationChannels();
    return success(res, channels.map(apiChannel));
  }),
);

router.put(
  '/system/notification-channels',
  requirePermission('notify:channel:manage'),
  asyncHandler(async (req, res) => {
    const channels = await notify.updateNotificationChannels(req.body, req.currentUser!);
    return success(res, channels.map(apiChannel));
  }),
);

export default router;
