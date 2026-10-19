import { createHash } from 'node:crypto';
import type { Request, RequestHandler } from 'express';
import type { QueryResultRow } from 'pg';

import { writeAudit } from '../audit/writeAudit.js';
import { MESSAGES } from '../constants/messages.js';
import { query } from '../db/pool.js';
import { asyncHandler } from '../http/asyncHandler.js';
import { fail } from '../http/envelope.js';

export const VISITOR_COOKIE_NAME = 'vs.visitor';
export const VISITOR_TOKEN_INVALID_CODE = 40303;

const SHORT_CODE = /^\d{6}$/;

type VisitorTokenRow = QueryResultRow & {
  appointment_id: string;
};

function tokenFromRequest(req: Request): string | undefined {
  const authorization = req.headers.authorization;
  if (authorization !== undefined) {
    const value = Array.isArray(authorization) ? authorization[0] : authorization;
    const match = /^Bearer\s+(.+)$/i.exec(value);
    return match?.[1]?.trim() ?? '';
  }

  const cookieToken = req.cookies?.[VISITOR_COOKIE_NAME];
  return typeof cookieToken === 'string' ? cookieToken : undefined;
}

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

async function auditDenied(req: Request, note: string): Promise<void> {
  const user = req.currentUser;
  await writeAudit({
    userId: user?.id ?? null,
    userName: user?.displayName ?? '',
    objectType: 'visitor_token',
    objectId: null,
    action: '越权拦截',
    result: '拒绝',
    before: { method: req.method, path: req.originalUrl || req.path },
    note,
    ip: req.ip || req.socket.remoteAddress || null,
  });
}

async function rejectVisitor(req: Request, res: Parameters<RequestHandler>[1], note: string): Promise<void> {
  await auditDenied(req, note);
  fail(res, 403, VISITOR_TOKEN_INVALID_CODE, MESSAGES['COPY-007']);
}

export const visitorTokenAuth: RequestHandler = asyncHandler(async (req, res, next) => {
  const token = tokenFromRequest(req);
  if (!token) {
    await rejectVisitor(req, res, '访客令牌缺失');
    return;
  }

  if (SHORT_CODE.test(token)) {
    await rejectVisitor(req, res, '6 位短码不能作为访客令牌');
    return;
  }

  const result = await query<VisitorTokenRow>(
    `SELECT appointment_id
       FROM visitor_tokens
      WHERE token_hash = $1
        AND (expires_at IS NULL OR expires_at > now())
      LIMIT 1`,
    [hashToken(token)]
  );

  const row = result.rows[0];
  if (!row) {
    await rejectVisitor(req, res, '访客令牌无效或已过期');
    return;
  }

  req.visitorAppointmentId = row.appointment_id;
  req.visitorToken = token;
  next();
});
