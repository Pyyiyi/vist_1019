import { Router, type Request } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { success } from '../../../shared/http/envelope.js';
import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import * as service from '../internal/dictionary.service.js';
import { apiDictionary } from '../internal/presenters.js';

const router = Router();

function requestIp(req: Request): string | null {
  return req.ip || req.socket.remoteAddress || null;
}

router.get(
  '/system/dictionary',
  requirePermission('system:dictionary:read'),
  asyncHandler(async (req, res) => {
    return success(res, {
      items: (await service.listDictionary(req.query)).map(apiDictionary),
    });
  }),
);

router.post(
  '/system/dictionary',
  requirePermission('system:dictionary:create'),
  asyncHandler(async (req, res) => {
    const item = await service.createDictionaryItem(
      req.body,
      req.currentUser!,
      requestIp(req),
    );
    return success(res, apiDictionary(item), '字典项已新增');
  }),
);

router.put(
  '/system/dictionary/:id/status',
  requirePermission('system:dictionary:status'),
  asyncHandler(async (req, res) => {
    return success(
      res,
      await service.changeDictionaryStatus(
        req.params.id,
        req.body,
        req.currentUser!,
        requestIp(req),
      ),
    );
  }),
);

export default router;
