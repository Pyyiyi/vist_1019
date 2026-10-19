import { Router, type Request } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { paginated, success } from '../../../shared/http/envelope.js';
import { requireAdmin, requirePermission } from '../../../shared/middleware/requirePermission.js';
import { validateBody } from '../../../shared/validation/validators.js';
import * as service from '../internal/review.service.js';
import { rescheduleRules } from './validation.js';

const router = Router();

function ip(req: Request): string | null {
  return req.ip || req.socket.remoteAddress || null;
}

router.get('/reviews/assignment', requireAdmin, asyncHandler(async (_req, res) => success(res, await service.getAssignmentRules())));
router.put('/reviews/assignment', requireAdmin, asyncHandler(async (req, res) => success(res, await service.saveAssignmentRules(req.body), '保存成功')));

router.get('/reviews', requirePermission('visit:review:read'), asyncHandler(async (req, res) => {
  const result = await service.listReviews(req.query as Record<string, unknown>, req.currentUser!);
  return paginated(res, result.items, result.total, result.page, result.page_size);
}));

router.get('/reviews/:id', requirePermission('visit:review:read'), asyncHandler(async (req, res) => success(res, await service.getReviewDetail(req.params.id, req.currentUser!, ip(req), req.originalUrl))));
router.post('/reviews/:id/approve', requirePermission('visit:review:decide'), asyncHandler(async (req, res) => success(res, await service.approveReview(req.params.id, req.currentUser!, ip(req), req.originalUrl), '已同意该预约')));
router.post('/reviews/:id/reject', requirePermission('visit:review:decide'), asyncHandler(async (req, res) => success(res, await service.rejectReview(req.params.id, req.body, req.currentUser!, ip(req), req.originalUrl), '已拒绝该预约，访客将收到拒绝原因')));
router.post('/reviews/:id/reschedule', requirePermission('visit:review:reschedule'), validateBody(rescheduleRules), asyncHandler(async (req, res) => success(res, await service.proposeReschedule(req.params.id, req.body, req.currentUser!, ip(req), req.originalUrl), '改期提议已发送，等待访客确认')));
router.get('/reviews/:id/logs', requirePermission('visit:review:read'), asyncHandler(async (req, res) => success(res, await service.listReviewLogs(req.params.id, req.currentUser!, ip(req), req.originalUrl))));

export default router;
