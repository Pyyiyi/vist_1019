import { Router } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { paginated } from '../../../shared/http/envelope.js';
import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import { compliancePermissions } from '../permissions.js';
import { listAuditLogs, parseAuditFilters } from '../index.js';

const router = Router();

router.get('/audit-logs', requirePermission(compliancePermissions.auditRead), asyncHandler(async (req, res) => {
  const result = await listAuditLogs(parseAuditFilters(req.query as Record<string, unknown>));
  return paginated(res, result.items, result.total, result.page, result.page_size);
}));

export default router;
