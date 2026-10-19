import { Router, type Request } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { success } from '../../../shared/http/envelope.js';
import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import * as service from '../internal/params.service.js';
import { apiParam } from '../internal/presenters.js';

const router = Router();

function requestIp(req: Request): string | null {
  return req.ip || req.socket.remoteAddress || null;
}

router.get(
  '/system/params',
  requirePermission('system:param:read'),
  asyncHandler(async (_req, res) => {
    return success(res, { items: (await service.listParams()).map(apiParam) });
  }),
);

router.put(
  '/system/params/:key',
  requirePermission('system:param:update'),
  asyncHandler(async (req, res) => {
    const item = await service.updateParam(req.params.key, req.body, req.currentUser!, requestIp(req));
    return success(res, apiParam(item), '参数已保存，立即生效');
  }),
);

export default router;
