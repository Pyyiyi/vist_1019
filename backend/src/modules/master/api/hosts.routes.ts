import { Router, type Request } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { success } from '../../../shared/http/envelope.js';
import { methodNotAllowed } from '../../../shared/http/errors.js';
import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import * as service from '../internal/hosts.service.js';
import { apiHost } from '../internal/presenters.js';

const router = Router();

function requestIp(req: Request): string | null {
  return req.ip || req.socket.remoteAddress || null;
}

router.get(
  '/master/hosts',
  requirePermission('master:host:read'),
  asyncHandler(async (req, res) => {
    return success(res, { items: (await service.listHosts(req.query)).map(apiHost) });
  }),
);

router.post(
  '/master/hosts',
  requirePermission('master:host:create'),
  asyncHandler(async (req, res) => {
    return success(
      res,
      apiHost(await service.createHost(req.body, req.currentUser!, requestIp(req))),
      '新增成功',
    );
  }),
);

router.put(
  '/master/hosts/:id',
  requirePermission('master:host:update'),
  asyncHandler(async (req, res) => {
    const item = await service.updateHost(
      req.params.id,
      req.body,
      req.currentUser!,
      requestIp(req),
    );
    return success(res, apiHost(item), '保存成功');
  }),
);

router.put(
  '/master/hosts/:id/status',
  requirePermission('master:host:status'),
  asyncHandler(async (req, res) => {
    return success(
      res,
      await service.changeHostStatus(
        req.params.id,
        req.body,
        req.currentUser!,
        requestIp(req),
      ),
    );
  }),
);

router.delete(
  '/master/hosts/:id',
  requirePermission('master:host:status'),
  asyncHandler(async () => {
    throw methodNotAllowed();
  }),
);

export default router;
