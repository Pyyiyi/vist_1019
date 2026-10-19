import { Router } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { success } from '../../../shared/http/envelope.js';
import { visitorTokenAuth } from '../../../shared/middleware/visitorTokenAuth.js';
import { getVisitorPrivacyCopy } from '../index.js';

const router = Router();

router.get('/visitor/privacy/copy', visitorTokenAuth, asyncHandler(async (req, res) => {
  return success(res, await getVisitorPrivacyCopy(req.visitorAppointmentId!));
}));

export default router;
