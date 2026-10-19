import type { ErrorRequestHandler } from 'express';

import { logger } from '../logger.js';
import { MESSAGES } from '../constants/messages.js';
import { AppError } from './errors.js';
import { fail } from './envelope.js';

export const errorHandler: ErrorRequestHandler = (error, req, res, next) => {
  if (res.headersSent) {
    next(error);
    return;
  }

  if (error instanceof AppError) {
    fail(res, error.httpStatus, error.code, error.message, error.field);
    return;
  }

  const unknownError = error instanceof Error ? error : new Error(String(error));
  logger.error('请求处理失败', {
    requestId: req.context?.requestId,
    method: req.method,
    path: req.originalUrl,
    stack: unknownError.stack,
  });
  fail(res, 500, 50001, MESSAGES.INTERNAL_ERROR);
};
