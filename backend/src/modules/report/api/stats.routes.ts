import { Router } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { success } from '../../../shared/http/envelope.js';
import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import { getIncidentStats, getVisitStats } from '../internal/stats.service.js';

const router = Router();

router.get(
  '/stats/visits',
  requirePermission('report:stats:read'),
  asyncHandler(async (req, res) => {
    const result = await getVisitStats(req.query);
    return success(res, result);
  }),
);

router.get(
  '/stats/incidents',
  requirePermission('report:stats:read'),
  asyncHandler(async (req, res) => {
    const result = await getIncidentStats(req.query);
    return success(res, {
      types: result.types,
      timeout_count: result.timeoutCount,
    });
  }),
);

export default router;
