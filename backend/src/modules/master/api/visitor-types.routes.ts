import { Router, type Request } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { success } from '../../../shared/http/envelope.js';
import { methodNotAllowed } from '../../../shared/http/errors.js';
import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import { apiVisitorType } from '../internal/presenters.js';
import * as service from '../internal/visitor-types.service.js';

const router = Router();
const permission = 'master:visitor_type:read';

function requestIp(req: Request): string | null {
  return req.ip || req.socket.remoteAddress || null;
}

router.get(
  '/master/visitor-types',
  requirePermission(permission),
  asyncHandler(async (req, res) => {
    const items = await service.listVisitorTypes(req.query);
    return success(res, { items: items.map(apiVisitorType) });
  }),
);

router.post(
  '/master/visitor-types',
  requirePermission('master:visitor_type:create'),
  asyncHandler(async (req, res) => {
    const item = await service.createVisitorType(req.body, req.currentUser!, requestIp(req));
    return success(res, apiVisitorType(item), '新增成功');
  }),
);

router.put(
  '/master/visitor-types/:id',
  requirePermission('master:visitor_type:update'),
  asyncHandler(async (req, res) => {
    const item = await service.renameVisitorType(
      req.params.id,
      req.body,
      req.currentUser!,
      requestIp(req),
    );
    return success(res, apiVisitorType(item), '保存成功');
  }),
);

router.put(
  '/master/visitor-types/:id/status',
  requirePermission('master:visitor_type:status'),
  asyncHandler(async (req, res) => {
    return success(
      res,
      await service.changeVisitorTypeStatus(
        req.params.id,
        req.body,
        req.currentUser!,
        requestIp(req),
      ),
    );
  }),
);

router.delete(
  '/master/visitor-types/:id',
  requirePermission('master:visitor_type:status'),
  asyncHandler(async () => {
    throw methodNotAllowed();
  }),
);

export default router;
