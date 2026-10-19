import type { RequestHandler } from 'express';

import { logger } from '../logger.js';

export const auditMiddleware: RequestHandler = (req, res, next) => {
  res.once('finish', () => {
    const startedAt = req.context?.startedAt ?? Date.now();
    logger.info('请求元数据', {
      requestId: req.context?.requestId,
      ip: req.context?.ip ?? req.ip,
      method: req.method,
      path: req.originalUrl,
      status: res.statusCode,
      durationMs: Date.now() - startedAt,
    });
  });

  next();
};
