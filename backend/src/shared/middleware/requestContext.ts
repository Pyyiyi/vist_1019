import type { RequestHandler } from 'express';

import { newUuid } from '../utils/ids.js';

export type RequestContext = { requestId: string; startedAt: number; ip: string };

declare global {
  namespace Express {
    interface Request {
      context: RequestContext;
    }
  }
}

export const requestContext: RequestHandler = (req, _res, next) => {
  req.context = {
    requestId: newUuid(),
    startedAt: Date.now(),
    ip: req.ip || req.socket.remoteAddress || '',
  };
  next();
};
