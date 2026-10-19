import { Router, type Request, type Response } from 'express';
import { body } from 'express-validator';

import { SESSION_COOKIE_NAME } from '../../../shared/auth/session.js';
import { toSessionUser, type AccessUserDto } from '../internal/auth.service.js';
import * as authService from '../internal/auth.service.js';
import { CSRF_COOKIE_NAME } from '../../../shared/middleware/csrfProtection.js';
import { loginRateLimiter } from '../../../shared/middleware/rateLimiter.js';
import { requireAuth } from '../../../shared/middleware/requireAuth.js';
import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { success } from '../../../shared/http/envelope.js';
import { unprocessable } from '../../../shared/http/errors.js';
import { validateBody } from '../../../shared/validation/validators.js';

const router = Router();

function requestIp(req: Request): string | null {
  return req.ip || req.socket.remoteAddress || null;
}

function csrfTokenFromResponse(req: Request, res: Response): string {
  const fromCookie = req.cookies?.[CSRF_COOKIE_NAME];
  if (typeof fromCookie === 'string' && fromCookie.length > 0) {
    return fromCookie;
  }

  const setCookie = res.getHeader('Set-Cookie');
  const values = Array.isArray(setCookie)
    ? setCookie
    : typeof setCookie === 'string'
      ? [setCookie]
      : [];
  for (const value of values) {
    for (const segment of String(value).split(';')) {
      const trimmed = segment.trim();
      if (trimmed.startsWith(`${CSRF_COOKIE_NAME}=`)) {
        return decodeURIComponent(trimmed.slice(CSRF_COOKIE_NAME.length + 1));
      }
    }
  }
  return '';
}

function responseUser(user: AccessUserDto): Record<string, unknown> {
  return {
    id: user.id,
    username: user.username,
    display_name: user.displayName,
    role_code: user.roleCode,
    host_id: user.hostId,
    employee_no: user.employeeNo,
    department: user.department,
  };
}

function regenerateSession(req: Request): Promise<void> {
  return new Promise((resolve, reject) => {
    req.session.regenerate((error) => {
      if (error) reject(error);
      else resolve();
    });
  });
}

function saveSession(req: Request): Promise<void> {
  return new Promise((resolve, reject) => {
    req.session.save((error) => {
      if (error) reject(error);
      else resolve();
    });
  });
}

function destroySession(req: Request): Promise<void> {
  return new Promise((resolve, reject) => {
    req.session.destroy((error) => {
      if (error) reject(error);
      else resolve();
    });
  });
}

router.get('/auth/csrf', (req, res) => {
  const token = csrfTokenFromResponse(req, res);
  return success(res, { csrf_token: token });
});

router.post(
  '/auth/login',
  loginRateLimiter,
  validateBody([
    body('username').isString().trim().notEmpty().withMessage('请输入账号'),
    body('password').isString().notEmpty().withMessage('请输入密码'),
  ]),
  asyncHandler(async (req, res) => {
    const user = await authService.login(
      String(req.body.username),
      String(req.body.password),
      requestIp(req),
    );

    await regenerateSession(req);
    req.session.user = toSessionUser(user);
    req.session.userId = user.id;
    await saveSession(req);

    return success(res, { user: responseUser(user) }, '登录成功');
  }),
);

router.post(
  '/auth/logout',
  requireAuth,
  asyncHandler(async (req, res) => {
    const user = req.currentUser ?? req.session.user;
    if (!user) {
      return res.status(401).json({ code: 40101, message: '请先登录', data: null });
    }

    await authService.logout(user, requestIp(req));
    await destroySession(req);
    res.clearCookie(SESSION_COOKIE_NAME, { path: '/' });
    return success(res, { logged_out: true });
  }),
);

router.get('/auth/me', requireAuth, (req, res) => {
  const user = req.currentUser ?? req.session.user;
  return success(res, { user: responseUser({
    ...user!,
    employeeNo: null,
    department: null,
  }) });
});

router.put(
  '/auth/password',
  requireAuth,
  asyncHandler(async (req, res, next) => {
    const oldPassword = typeof req.body.old_password === 'string' ? req.body.old_password : '';
    const newPassword =
      typeof req.body.new_password === 'string'
        ? req.body.new_password
        : typeof req.body.password === 'string'
          ? req.body.password
          : '';
    if (!oldPassword) {
      return next(unprocessable('请输入原密码', 'old_password'));
    }

    await authService.changePassword(
      req.currentUser ?? req.session.user!,
      oldPassword,
      newPassword,
      requestIp(req),
    );
    return success(res, { changed: true });
  }),
);

export default router;
