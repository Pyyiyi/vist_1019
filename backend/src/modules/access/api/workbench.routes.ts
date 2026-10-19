import { Router } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { success } from '../../../shared/http/envelope.js';
import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import * as workbenchService from '../internal/workbench.service.js';

const router = Router();
router.get(
  '/workbench/summary',
  requirePermission('pt:workbench:read'),
  asyncHandler(async (req, res) => {
    const summary = await workbenchService.getWorkbenchSummary(req.currentUser!);
    return success(res, {
      role: summary.role,
      todo: {
        pending_review: summary.todo.pendingReview,
        pending_verify: summary.todo.pendingVerify,
        pending_incident: summary.todo.pendingIncident,
      },
      kpi: {
        today_appointments: summary.kpi.todayAppointments,
        on_campus: summary.kpi.onCampus,
      },
      unread_count: summary.unreadCount,
      todos: summary.todos,
    });
  }),
);

export default router;
