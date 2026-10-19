import type { Request, RequestHandler, Response } from 'express';

import { MESSAGES } from '../constants/messages.js';
import { fail } from '../http/envelope.js';

export const RATE_LIMITED_CODE = 42901;
const WINDOW_MS = 60_000;

type Bucket = { count: number; resetAt: number };

function clientIp(req: Request): string {
  return req.ip || req.socket.remoteAddress || req.context?.ip || 'unknown';
}

function rejectTooMany(res: Response, bucket: Bucket, now: number): void {
  res.setHeader('Retry-After', String(Math.max(1, Math.ceil((bucket.resetAt - now) / 1000))));
  fail(res, 429, RATE_LIMITED_CODE, MESSAGES['COPY-012']);
}

export function createRateLimiter(limit: number, windowMs = WINDOW_MS): RequestHandler {
  if (!Number.isInteger(limit) || limit <= 0) {
    throw new Error('Rate limit must be a positive integer');
  }

  const buckets = new Map<string, Bucket>();

  return (req, res, next) => {
    const now = Date.now();
    const key = clientIp(req);
    let bucket = buckets.get(key);

    if (!bucket || now >= bucket.resetAt) {
      bucket = { count: 0, resetAt: now + windowMs };
      buckets.set(key, bucket);
    }

    bucket.count += 1;
    if (bucket.count > limit) {
      rejectTooMany(res, bucket, now);
      return;
    }

    next();
  };
}

export const loginRateLimiter = createRateLimiter(20);
export const apiRateLimiter = createRateLimiter(600);
