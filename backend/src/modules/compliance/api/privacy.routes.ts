import { Router, type Request } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { paginated, success } from '../../../shared/http/envelope.js';
import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import { compliancePermissions } from '../permissions.js';
import {
  eraseAppointmentPrivacy,
  getPrivacyRetention,
  listPrivacyCases,
  updatePrivacyRetention,
} from '../index.js';

const router = Router();

function ip(req: Request): string | null {
  return req.ip || req.socket.remoteAddress || null;
}

router.get('/privacy/retention', requirePermission(compliancePermissions.privacyRead), asyncHandler(async (_req, res) => {
  return success(res, await getPrivacyRetention());
}));

router.put('/privacy/retention', requirePermission(compliancePermissions.privacyUpdate), asyncHandler(async (req, res) => {
  return success(res, await updatePrivacyRetention(req.body, req.currentUser!, ip(req)), '留存期限已保存');
}));

router.post('/privacy/appointments/:id/erase', requirePermission(compliancePermissions.privacyUpdate), asyncHandler(async (req, res) => {
  return success(res, await eraseAppointmentPrivacy(req.params.id, req.body, req.currentUser!), '个人信息已清除');
}));

router.get('/privacy/cases', requirePermission(compliancePermissions.privacyRead), asyncHandler(async (req, res) => {
  const result = await listPrivacyCases(req.query as Record<string, unknown>);
  return paginated(res, result.items, result.total, result.page, result.page_size);
}));

export default router;
