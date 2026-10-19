import { Router, type Request } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { success } from '../../../shared/http/envelope.js';
import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import * as service from '../internal/time-rules.service.js';
import { apiTimeRule } from '../internal/presenters.js';

const router = Router();

function requestIp(req: Request): string | null {
  return req.ip || req.socket.remoteAddress || null;
}

router.get(
  '/master/time-rules',
  requirePermission('master:time_rule:read'),
  asyncHandler(async (_req, res) => {
    return success(res, { items: (await service.listTimeRules()).map(apiTimeRule) });
  }),
);

router.post(
  '/master/time-rules',
  requirePermission('master:time_rule:create'),
  asyncHandler(async (req, res) => {
    const item = await service.createTimeRule(req.body, req.currentUser!, requestIp(req));
    return success(res, apiTimeRule(item), '新增成功');
  }),
);

router.delete(
  '/master/time-rules/:id',
  requirePermission('master:time_rule:delete'),
  asyncHandler(async (req, res) => {
    await service.deleteTimeRule(req.params.id, req.currentUser!, requestIp(req));
    return success(res, { deleted: true });
  }),
);

export default router;
