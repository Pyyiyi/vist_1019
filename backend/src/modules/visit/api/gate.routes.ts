import { Router, type Request } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { paginated, success } from '../../../shared/http/envelope.js';
import { requireAdmin, requirePermission } from '../../../shared/middleware/requirePermission.js';
import { validateBody } from '../../../shared/validation/validators.js';
import * as service from '../internal/gate.service.js';
import { codeRules, incidentRules, walkInRules } from './validation.js';

const router = Router();

function context(req: Request) {
  return { actor: req.currentUser!, ip: req.ip || req.socket.remoteAddress || null };
}

router.get('/gate/today', requirePermission('visit:gate:today:read'), asyncHandler(async (_req, res) => success(res, await service.getGateToday())));
router.get('/gate/form-options', requirePermission('visit:gate:verify'), asyncHandler(async (_req, res) => success(res, await service.getGateFormOptions())));
router.post('/gate/verify', requirePermission('visit:gate:verify'), validateBody(codeRules), asyncHandler(async (req, res) => success(res, await service.verifyCode(req.body, context(req)), '核验完成')));
router.post('/gate/admit', requirePermission('visit:gate:admit'), validateBody(codeRules), asyncHandler(async (req, res) => success(res, await service.admitCode(req.body, context(req)), '已放行，进校时刻已登记')));
router.post('/gate/depart', requirePermission('visit:gate:depart'), validateBody(codeRules), asyncHandler(async (req, res) => success(res, await service.departCode(req.body, context(req)), '已登记离校')));
router.post('/gate/walk-in', requirePermission('visit:gate:walkin'), validateBody(walkInRules), asyncHandler(async (req, res) => success(res, await service.walkIn(req.body, context(req)), '现场登记完成，访客已放行')));
router.get('/gate/incidents', requirePermission('visit:gate:incident:report'), asyncHandler(async (req, res) => {
  const result = await service.listIncidents(req.query as Record<string, unknown>);
  return paginated(res, result.items, result.total, result.page, result.page_size);
}));
router.post('/gate/incidents', requirePermission('visit:gate:incident:report'), validateBody(incidentRules), asyncHandler(async (req, res) => success(res, await service.createIncident(req.body, context(req)), '异常已上报')));
router.put('/gate/incidents/:id/disposition', requireAdmin, asyncHandler(async (req, res) => success(res, await service.disposeIncident(req.params.id, req.body, context(req)), '异常已处置')));

export default router;
