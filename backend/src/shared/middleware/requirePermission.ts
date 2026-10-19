import type { Request, RequestHandler } from 'express';

import { hasPermission } from '../auth/permissions.js';
import type { AuthenticatedUser } from '../auth/types.js';
import { writeAudit } from '../audit/writeAudit.js';
import { MESSAGES } from '../constants/messages.js';
import { asyncHandler } from '../http/asyncHandler.js';
import { fail } from '../http/envelope.js';

export const PERMISSION_DENIED_COPY_ID = 'COPY-005';
export const PERMISSION_DENIED_CODE = 40301;
export const AUTH_REQUIRED_CODE = 40101;
const PERMISSION_DENIED_MESSAGE = MESSAGES[PERMISSION_DENIED_COPY_ID] ?? MESSAGES.FORBIDDEN;

function objectTypeFor(permissionCode: string): string {
  const segments = permissionCode.split(':');
  return segments.length > 1 ? segments.slice(1, -1).join(':') : 'permission';
}

function requestPath(req: Request): string {
  return req.originalUrl || req.path;
}

async function deny(
  req: Request,
  user: AuthenticatedUser,
  note: string,
  objectType: string
): Promise<void> {
  const objectId = typeof req.params.id === 'string' ? req.params.id : null;
  await writeAudit({
    userId: user.id,
    userName: user.displayName,
    objectType,
    objectId,
    action: '越权拦截',
    result: '拒绝',
    before: { method: req.method, path: requestPath(req) },
    note,
    ip: req.ip || req.socket.remoteAddress || null,
  });
}

export function requirePermission(permissionCode: string): RequestHandler {
  return asyncHandler(async (req, res, next) => {
    const user = req.session?.user;
    if (!user) {
      fail(res, 401, AUTH_REQUIRED_CODE, MESSAGES['COPY-001']);
      return;
    }

    req.currentUser = user;
    if (!hasPermission(user.roleCode, permissionCode)) {
      await deny(
        req,
        user,
        `缺少权限点 ${permissionCode}`,
        objectTypeFor(permissionCode)
      );
      fail(res, 403, PERMISSION_DENIED_CODE, PERMISSION_DENIED_MESSAGE);
      return;
    }

    next();
  });
}

export const requireAdmin: RequestHandler = asyncHandler(async (req, res, next) => {
  const user = req.session?.user;
  if (!user) {
    fail(res, 401, AUTH_REQUIRED_CODE, MESSAGES['COPY-001']);
    return;
  }

  req.currentUser = user;
  if (user.roleCode !== 'admin') {
    await deny(req, user, '仅管理员可访问', 'admin');
    fail(res, 403, PERMISSION_DENIED_CODE, PERMISSION_DENIED_MESSAGE);
    return;
  }

  next();
});
