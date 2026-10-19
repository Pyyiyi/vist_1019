import { Router, type Request } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { paginated, success } from '../../../shared/http/envelope.js';
import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import { validateBody } from '../../../shared/validation/validators.js';
import * as service from '../internal/appointment.service.js';
import { appointmentPayloadRules, rescheduleRules } from './validation.js';

const router = Router();

function ip(req: Request): string | null {
  return req.ip || req.socket.remoteAddress || null;
}

router.get('/appointments/form-options', requirePermission('visit:appointment:read'), asyncHandler(async (_req, res) => success(res, await service.getFormOptions())));

router.get('/appointments', requirePermission('visit:appointment:read'), asyncHandler(async (req, res) => {
  const result = await service.listAppointments(req.query as Record<string, unknown>, req.currentUser!);
  return paginated(res, result.items, result.total, result.page, result.page_size);
}));

router.post('/appointments', requirePermission('visit:appointment:create'), validateBody(appointmentPayloadRules), asyncHandler(async (req, res) => {
  const item = await service.createAppointment(req.body, {
    actor: req.currentUser!,
    createdBy: req.currentUser!.id,
    channel: '后台代提',
    ip: ip(req),
  });
  return success(res, item, '预约已提交，请等待被访人审核');
}));

router.get('/appointments/:id', requirePermission('visit:appointment:read'), asyncHandler(async (req, res) => {
  const item = await service.getAppointmentDetail(req.params.id, req.currentUser!, ip(req), req.originalUrl);
  return success(res, item);
}));

router.put('/appointments/:id/reschedule', requirePermission('visit:appointment:update'), validateBody(rescheduleRules), asyncHandler(async (req, res) => {
  const item = await service.rescheduleAppointment(req.params.id, req.body, req.currentUser!, ip(req), 'proposal', req.originalUrl);
  return success(res, item, '改期成功');
}));

router.put('/appointments/:id/cancel', requirePermission('visit:appointment:cancel'), asyncHandler(async (req, res) => {
  const item = await service.cancelAppointment(req.params.id, req.body.reason, req.currentUser!, ip(req), req.originalUrl);
  return success(res, item, '预约已取消');
}));

export default router;
