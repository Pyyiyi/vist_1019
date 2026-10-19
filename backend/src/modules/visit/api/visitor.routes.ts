import { Router, type Request, type Response } from 'express';

import { MESSAGES } from '../../../shared/constants/messages.js';
import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { success } from '../../../shared/http/envelope.js';
import { VISITOR_COOKIE_NAME, visitorTokenAuth } from '../../../shared/middleware/visitorTokenAuth.js';
import { validateBody } from '../../../shared/validation/validators.js';
import * as service from '../internal/visitor.service.js';
import { appointmentPayloadRules, rescheduleRules } from './validation.js';

const router = Router();

function setVisitorCookie(res: Response, token: string): void {
  res.cookie(VISITOR_COOKIE_NAME, token, {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.COOKIE_SECURE?.trim() === 'true',
    path: '/',
  });
}

router.get('/visitor/form-options', asyncHandler(async (_req, res) => success(res, await service.getVisitorFormOptions())));

router.post('/visitor/appointments', validateBody(appointmentPayloadRules), asyncHandler(async (req, res) => {
  const item = await service.submitVisitorAppointment(req.body);
  setVisitorCookie(res, item.visitor_token);
  return success(res, item, '预约已提交，请等待被访人审核');
}));

router.get('/visitor/appointments', visitorTokenAuth, asyncHandler(async (req, res) => {
  return success(res, await service.listVisitorAppointments(req.visitorAppointmentId!));
}));

router.get('/visitor/appointments/:id', visitorTokenAuth, asyncHandler(async (req, res) => {
  return success(res, await service.getVisitorAppointmentDetail(req.params.id, req.visitorAppointmentId!, req.originalUrl));
}));

router.post('/visitor/appointments/:id/confirm-reschedule', visitorTokenAuth, asyncHandler(async (req, res) => {
  return success(res, await service.confirmVisitorReschedule(req.params.id, req.visitorAppointmentId!, req.originalUrl), '已确认改期，等待被访人重新审核');
}));

router.put('/visitor/appointments/:id/reschedule', visitorTokenAuth, validateBody(rescheduleRules), asyncHandler(async (req, res) => {
  return success(res, await service.rescheduleVisitorAppointment(req.params.id, req.body, req.visitorAppointmentId!, req.originalUrl), '改期成功');
}));

router.put('/visitor/appointments/:id/cancel', visitorTokenAuth, asyncHandler(async (req, res) => {
  return success(res, await service.cancelVisitorAppointment(req.params.id, req.body, req.visitorAppointmentId!, req.originalUrl), '预约已取消');
}));

export default router;
