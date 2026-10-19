import { randomBytes } from 'node:crypto';
import type { Request, RequestHandler } from 'express';

import { MESSAGES } from '../constants/messages.js';
import { fail } from '../http/envelope.js';

export const CSRF_COOKIE_NAME = 'vs.csrf';
export const CSRF_HEADER_NAME = 'X-CSRF-Token';
export const CSRF_COPY_ID = 'COPY-103';
export const CSRF_ERROR_CODE = 40301;

const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

function cookieSecure(): boolean {
  return process.env.COOKIE_SECURE?.trim() === 'true';
}

function isUninitializedLogin(req: Request): boolean {
  if (req.method !== 'POST') {
    return false;
  }

  const path = req.path.replace(/^\/api\/v1/, '').replace(/\/$/, '');
  const hasSession = Boolean(req.session?.user ?? req.session?.userId);
  return !hasSession && (path === '/auth/login' || path === '/login');
}

function issueToken(req: Request, res: Parameters<RequestHandler>[1]): string {
  const existing = req.cookies?.[CSRF_COOKIE_NAME];
  if (typeof existing === 'string' && existing.length > 0) {
    return existing;
  }

  const token = randomBytes(32).toString('base64url');
  res.cookie(CSRF_COOKIE_NAME, token, {
    httpOnly: false,
    sameSite: 'lax',
    secure: cookieSecure(),
    path: '/',
  });
  return token;
}

export const csrfProtection: RequestHandler = (req, res, next) => {
  const token = issueToken(req, res);

  if (SAFE_METHODS.has(req.method) || isUninitializedLogin(req)) {
    next();
    return;
  }

  const supplied = req.get(CSRF_HEADER_NAME);
  if (!supplied || supplied !== token) {
    fail(res, 403, CSRF_ERROR_CODE, MESSAGES.CSRF_INVALID);
    return;
  }

  next();
};
