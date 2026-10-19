import { Router, type Request } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { success } from '../../../shared/http/envelope.js';
import { methodNotAllowed } from '../../../shared/http/errors.js';
import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import * as service from '../internal/gates.service.js';
import { apiGate } from '../internal/presenters.js';

const router = Router();

function requestIp(req: Request): string | null {
  return req.ip || req.socket.remoteAddress || null;
}

router.get(
  '/master/gates',
  requirePermission('master:gate:read'),
  asyncHandler(async (req, res) => {
    return success(res, { items: (await service.listGates(req.query)).map(apiGate) });
  }),
);

router.post(
  '/master/gates',
  requirePermission('master:gate:create'),
  asyncHandler(async (req, res) => {
    return success(
      res,
      apiGate(await service.createGate(req.body, req.currentUser!, requestIp(req))),
      '新增成功',
    );
  }),
);

router.put(
  '/master/gates/:id',
  requirePermission('master:gate:update'),
  asyncHandler(async (req, res) => {
    const item = await service.renameGate(
      req.params.id,
      req.body,
      req.currentUser!,
      requestIp(req),
    );
    return success(res, apiGate(item), '保存成功');
  }),
);

router.put(
  '/master/gates/:id/status',
  requirePermission('master:gate:status'),
  asyncHandler(async (req, res) => {
    return success(
      res,
      await service.changeGateStatus(
        req.params.id,
        req.body,
        req.currentUser!,
        requestIp(req),
      ),
    );
  }),
);

router.delete(
  '/master/gates/:id',
  requirePermission('master:gate:status'),
  asyncHandler(async () => {
    throw methodNotAllowed();
  }),
);

export default router;
