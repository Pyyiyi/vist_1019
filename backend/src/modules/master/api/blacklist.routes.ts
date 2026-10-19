import { Router, type Request } from 'express';

import '../index.js';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { paginated, success } from '../../../shared/http/envelope.js';
import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import * as service from '../internal/blacklist.service.js';
import { apiBlacklist } from '../internal/presenters.js';

const router = Router();

function requestIp(req: Request): string | null {
  return req.ip || req.socket.remoteAddress || null;
}

router.get(
  '/master/blacklist',
  requirePermission('master:blacklist:read'),
  asyncHandler(async (req, res) => {
    const result = await service.listBlacklist(req.query);
    return paginated(
      res,
      result.items.map(apiBlacklist),
      result.total,
      result.page,
      result.pageSize,
    );
  }),
);

router.post(
  '/master/blacklist',
  requirePermission('master:blacklist:create'),
  asyncHandler(async (req, res) => {
    const item = await service.createBlacklist(req.body, req.currentUser!, requestIp(req));
    return success(res, apiBlacklist(item), '新增成功');
  }),
);

router.delete(
  '/master/blacklist/:id',
  requirePermission('master:blacklist:delete'),
  asyncHandler(async (req, res) => {
    await service.deleteBlacklist(req.params.id, req.currentUser!, requestIp(req));
    return success(res, { deleted: true });
  }),
);

export default router;
