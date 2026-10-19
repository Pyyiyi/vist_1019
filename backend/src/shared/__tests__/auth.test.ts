import { createHash } from 'node:crypto';

import cookieParser from 'cookie-parser';
import express, { type RequestHandler } from 'express';
import session from 'express-session';
import request from 'supertest';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const boundaryMocks = vi.hoisted(() => ({
  query: vi.fn(),
  writeAudit: vi.fn(),
}));

vi.mock('../audit/writeAudit.js', () => ({ writeAudit: boundaryMocks.writeAudit }));
vi.mock('../db/pool.js', () => ({ query: boundaryMocks.query, getPool: vi.fn() }));

import { hashPassword, verifyPassword } from '../auth/password.js';
import { PERMISSIONS, hasPermission } from '../auth/permissions.js';
import {
  SESSION_COOKIE_NAME,
  SESSION_TTL_MS,
  createSessionMiddleware,
} from '../auth/session.js';
import type { AuthenticatedUser } from '../auth/types.js';
import {
  CSRF_COOKIE_NAME,
  CSRF_HEADER_NAME,
  csrfProtection,
} from '../middleware/csrfProtection.js';
import { createRateLimiter, loginRateLimiter } from '../middleware/rateLimiter.js';
import { requireAuth } from '../middleware/requireAuth.js';
import {
  requireAdmin,
  requirePermission,
} from '../middleware/requirePermission.js';
import { visitorTokenAuth } from '../middleware/visitorTokenAuth.js';

const guard: AuthenticatedUser = {
  id: 'user-guard',
  username: 'guard01',
  displayName: '门卫张师傅',
  roleCode: 'guard',
  hostId: null,
};

function withSession(user: AuthenticatedUser): RequestHandler {
  return (req, _res, next) => {
    Object.assign(req, { session: { user, userId: user.id } });
    next();
  };
}

function csrfApp() {
  const app = express();
  app.use(cookieParser());
  app.use(csrfProtection);
  app.get('/api/v1/auth/csrf', (req, res) => {
    res.json({ token: req.cookies?.[CSRF_COOKIE_NAME] });
  });
  app.post('/api/v1/auth/login', (_req, res) => {
    res.json({ ok: true });
  });
  app.post('/protected', (_req, res) => {
    res.json({ ok: true });
  });
  return app;
}

function visitorApp() {
  const app = express();
  app.use(cookieParser());
  app.get('/visitor', visitorTokenAuth, (req, res) => {
    res.json({ appointment_id: req.visitorAppointmentId });
  });
  return app;
}

describe('CSRF protection', () => {
  it('issues a readable SameSite=Lax vs.csrf cookie', async () => {
    const response = await request(csrfApp()).get('/api/v1/auth/csrf');
    const setCookie = String(response.headers['set-cookie']?.[0] ?? '');

    expect(response.status).toBe(200);
    expect(setCookie).toContain(`${CSRF_COOKIE_NAME}=`);
    expect(setCookie).toContain('SameSite=Lax');
    expect(setCookie).not.toContain('HttpOnly');
  });

  it('rejects a write request without X-CSRF-Token with 403 COPY-103 copy', async () => {
    const response = await request(csrfApp()).post('/protected');

    expect(response.status).toBe(403);
    expect(response.body).toEqual({
      code: 40301,
      message: '安全校验已失效，请刷新页面后重试',
      data: null,
    });
  });

  it('accepts a matching double-submit token and exempts unauthenticated login', async () => {
    const app = csrfApp();
    const issued = await request(app).get('/api/v1/auth/csrf');
    const cookie = String(issued.headers['set-cookie']?.[0] ?? '').split(';')[0];
    const token = decodeURIComponent(cookie.slice(`${CSRF_COOKIE_NAME}=`.length));

    const protectedResponse = await request(app)
      .post('/protected')
      .set('Cookie', cookie)
      .set(CSRF_HEADER_NAME, token);
    const loginResponse = await request(app).post('/api/v1/auth/login');

    expect(protectedResponse.status).toBe(200);
    expect(loginResponse.status).toBe(200);
  });

  it('rejects a mismatched token', async () => {
    const app = csrfApp();
    const issued = await request(app).get('/api/v1/auth/csrf');
    const cookie = String(issued.headers['set-cookie']?.[0] ?? '').split(';')[0];

    const response = await request(app)
      .post('/protected')
      .set('Cookie', cookie)
      .set(CSRF_HEADER_NAME, 'wrong-token');

    expect(response.status).toBe(403);
    expect(response.body.message).toBe('安全校验已失效，请刷新页面后重试');
  });
});

describe('authentication and permissions', () => {
  beforeEach(() => {
    boundaryMocks.writeAudit.mockReset().mockResolvedValue(undefined);
    boundaryMocks.query.mockReset();
  });

  it('exposes exactly the 33 seeded permissions and the role matrix', () => {
    expect(PERMISSIONS).toHaveLength(33);
    expect(new Set(PERMISSIONS).size).toBe(33);
    expect(hasPermission('guard', 'report:ledger:read')).toBe(true);
    expect(hasPermission('guard', 'system:param:manage')).toBe(false);
    expect(hasPermission('guard', 'system:params:read')).toBe(false);
    expect(hasPermission('host', 'visit:review:reschedule')).toBe(true);
    expect(hasPermission('visitor', 'pt:workbench:read')).toBe(false);
    expect(hasPermission('admin', 'custom:resource:read')).toBe(true);
  });

  it('returns 401 COPY-001 when the session is missing', async () => {
    const app = express();
    app.get('/protected', requireAuth, (_req, res) => res.json({ ok: true }));

    const response = await request(app).get('/protected');

    expect(response.status).toBe(401);
    expect(response.body).toEqual({ code: 40101, message: '请先登录', data: null });
  });

  it('attaches the authenticated user from the session', async () => {
    const app = express();
    app.get('/protected', withSession(guard), requireAuth, (req, res) => {
      res.json({ user: req.currentUser });
    });

    const response = await request(app).get('/protected');

    expect(response.status).toBe(200);
    expect(response.body.user).toEqual(guard);
  });

  it('allows a granted permission and rejects a missing permission with an audit', async () => {
    const app = express();
    app.get('/allowed', withSession(guard), requirePermission('report:ledger:read'), (_req, res) => {
      res.json({ ok: true });
    });
    app.get(
      '/denied',
      withSession(guard),
      requirePermission('system:param:manage'),
      (_req, res) => res.json({ ok: true })
    );
    app.get('/admin', withSession(guard), requireAdmin, (_req, res) => res.json({ ok: true }));

    const allowed = await request(app).get('/allowed');
    const denied = await request(app).get('/denied');
    const adminDenied = await request(app).get('/admin');

    expect(allowed.status).toBe(200);
    expect(denied.status).toBe(403);
    expect(denied.body).toEqual({
      code: 40301,
      message: '您没有执行该操作的权限',
      data: null,
    });
    expect(adminDenied.status).toBe(403);
    expect(boundaryMocks.writeAudit).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: guard.id,
        action: '越权拦截',
        result: '拒绝',
        note: '缺少权限点 system:param:manage',
      })
    );
    expect(boundaryMocks.writeAudit).toHaveBeenCalledWith(
      expect.objectContaining({ note: '仅管理员可访问' })
    );
  });
});

describe('visitor token authentication', () => {
  beforeEach(() => {
    boundaryMocks.writeAudit.mockReset().mockResolvedValue(undefined);
    boundaryMocks.query.mockReset();
  });

  it('hashes a bearer token, checks expiry, and binds the appointment id', async () => {
    boundaryMocks.query.mockResolvedValue({
      rows: [{ appointment_id: 'appointment-1' }],
      rowCount: 1,
    });

    const response = await request(visitorApp())
      .get('/visitor')
      .set('Authorization', 'Bearer visitor-token-1');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ appointment_id: 'appointment-1' });
    expect(boundaryMocks.query).toHaveBeenCalledWith(
      expect.stringContaining('expires_at IS NULL OR expires_at > now()'),
      [createHash('sha256').update('visitor-token-1').digest('hex')]
    );
  });

  it('accepts a vs.visitor cookie when no Authorization header exists', async () => {
    boundaryMocks.query.mockResolvedValue({
      rows: [{ appointment_id: 'appointment-2' }],
      rowCount: 1,
    });

    const response = await request(visitorApp())
      .get('/visitor')
      .set('Cookie', 'vs.visitor=cookie-token');

    expect(response.status).toBe(200);
    expect(boundaryMocks.query.mock.calls[0][1]).toEqual([
      createHash('sha256').update('cookie-token').digest('hex'),
    ]);
  });

  it('returns 403 COPY-007 for an invalid or expired token', async () => {
    boundaryMocks.query.mockResolvedValue({ rows: [], rowCount: 0 });

    const response = await request(visitorApp())
      .get('/visitor')
      .set('Authorization', 'Bearer expired-token');

    expect(response.status).toBe(403);
    expect(response.body).toEqual({
      code: 40303,
      message: '该申请链接已失效，请重新扫码申请',
      data: null,
    });
    expect(boundaryMocks.writeAudit).toHaveBeenCalledWith(
      expect.objectContaining({ action: '越权拦截', result: '拒绝' })
    );
  });

  it('rejects a six-digit short code without querying token storage and audits it', async () => {
    const response = await request(visitorApp())
      .get('/visitor')
      .set('Authorization', 'Bearer 123456');

    expect(response.status).toBe(403);
    expect(response.body.message).toBe('该申请链接已失效，请重新扫码申请');
    expect(boundaryMocks.query).not.toHaveBeenCalled();
    expect(boundaryMocks.writeAudit).toHaveBeenCalledWith(
      expect.objectContaining({ note: '6 位短码不能作为访客令牌' })
    );
  });

  it('prioritizes the Authorization header over a visitor cookie', async () => {
    boundaryMocks.query.mockResolvedValue({ rows: [], rowCount: 0 });

    const response = await request(visitorApp())
      .get('/visitor')
      .set('Authorization', 'Bearer invalid-header-token')
      .set('Cookie', 'vs.visitor=valid-cookie-token');

    expect(response.status).toBe(403);
    expect(boundaryMocks.query.mock.calls[0][1]).toEqual([
      createHash('sha256').update('invalid-header-token').digest('hex'),
    ]);
    expect(boundaryMocks.query.mock.calls[0][1]).not.toEqual([
      createHash('sha256').update('valid-cookie-token').digest('hex'),
    ]);
  });
});

describe('session middleware', () => {
  it('uses vs.sid, HttpOnly/SameSite=Lax, and an eight-hour expiry', async () => {
    process.env.SESSION_SECRET = 'test-session-secret';
    process.env.COOKIE_SECURE = 'false';

    const app = express();
    app.use(createSessionMiddleware({ store: new session.MemoryStore() }));
    app.post('/login', (req, res) => {
      req.session.user = guard;
      req.session.userId = guard.id;
      req.session.save((error) => {
        if (error) {
          res.status(500).json({ error: error.message });
          return;
        }
        res.json({ ok: true });
      });
    });
    app.get('/me', (req, res) => res.json({ user: req.session.user }));

    const login = await request(app).post('/login');
    const setCookie = String(login.headers['set-cookie']?.[0] ?? '');
    const cookie = setCookie.split(';')[0];
    const me = await request(app).get('/me').set('Cookie', cookie);

    expect(login.status).toBe(200);
    expect(setCookie).toContain(`${SESSION_COOKIE_NAME}=`);
    expect(setCookie).toContain('HttpOnly');
    expect(setCookie).toContain('SameSite=Lax');
    const expires = /Expires=([^;]+)/.exec(setCookie)?.[1];
    expect(expires).toBeDefined();
    const remainingMs = Date.parse(expires ?? '') - Date.now();
    expect(remainingMs).toBeGreaterThan(SESSION_TTL_MS - 5_000);
    expect(remainingMs).toBeLessThanOrEqual(SESSION_TTL_MS + 5_000);
    expect(me.body.user).toEqual(guard);
  });

  it('rejects unsupported limiter windows', () => {
    expect(() => createRateLimiter(0)).toThrow('Rate limit must be a positive integer');
  });
});

describe('login rate limiter', () => {
  it('allows 20 requests from one IP and returns 429 COPY-012 on the 21st', async () => {
    const app = express();
    app.set('trust proxy', true);
    app.post('/login', loginRateLimiter, (req, res) => res.json({ ip: req.ip }));
    const ip = '203.0.113.21';

    for (let attempt = 1; attempt <= 20; attempt += 1) {
      const response = await request(app).post('/login').set('X-Forwarded-For', ip);
      expect(response.status).toBe(200);
    }

    const limited = await request(app).post('/login').set('X-Forwarded-For', ip);
    const otherIp = await request(app)
      .post('/login')
      .set('X-Forwarded-For', '203.0.113.22');

    expect(limited.status).toBe(429);
    expect(limited.body).toEqual({
      code: 42901,
      message: '登录请求过于频繁，请 1 分钟后再试',
      data: null,
    });
    expect(limited.headers['retry-after']).toBeDefined();
    expect(otherIp.status).toBe(200);
  });
});

describe('password helpers', () => {
  it('hashes with bcrypt cost 10 and verifies the correct password only', async () => {
    const hash = await hashPassword('abc@123');

    expect(hash).toMatch(/^\$2[aby]\$10\$/);
    await expect(verifyPassword('abc@123', hash)).resolves.toBe(true);
    await expect(verifyPassword('wrong', hash)).resolves.toBe(false);
    await expect(verifyPassword('abc@123', 'not-a-bcrypt-hash')).resolves.toBe(false);
  });
});
