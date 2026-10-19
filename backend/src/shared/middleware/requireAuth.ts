import type { RequestHandler } from 'express';

import { MESSAGES } from '../constants/messages.js';
import { fail } from '../http/envelope.js';

export const AUTH_REQUIRED_CODE = 40101;

export const requireAuth: RequestHandler = (req, res, next) => {
  const user = req.session?.user;
  if (!user) {
    fail(res, 401, AUTH_REQUIRED_CODE, MESSAGES['COPY-001']);
    return;
  }

  req.currentUser = user;
  req.session.userId = user.id;
  next();
};
