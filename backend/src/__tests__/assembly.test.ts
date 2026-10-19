import { createServer, type Server as HttpServer } from 'node:http';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import type { Express, RequestHandler } from 'express';
import { io as createSocketClient, type Socket } from 'socket.io-client';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { emitNotification, initRealtime } from '../realtime/io.js';
import { apiRateLimiter } from '../shared/middleware/rateLimiter.js';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const fixtureContext = path.resolve(testDirectory, '../modules/assembly-fixture');
const fixtureApi = path.join(fixtureContext, 'api');
const fixtureRoute = path.join(fixtureApi, 'ping.routes.ts');

let appModule: typeof import('../app.js');
let app: Express;

beforeAll(async () => {
  mkdirSync(fixtureApi, { recursive: true });
  writeFileSync(
    fixtureRoute,
    `import { Router } from 'express';

const router = Router();
router.get('/ping', (_req, res) => {
  res.json({ code: 0, message: '操作成功', data: { pong: true } });
});

export default router;
`,
    'utf8'
  );

  appModule = await import('../app.js');
  app = appModule.createApp();
  await appModule.waitForRoutes();
});

type AppLayer = { name: string; handle: unknown; route?: { path: string } };

function appLayers(target: Express): AppLayer[] {
  const stack = (target as Express & { _router: { stack: AppLayer[] } })._router.stack;
  return stack.filter((layer: AppLayer) => layer.name !== 'query' && layer.name !== 'expressInit');
}

async function listen(server: HttpServer): Promise<number> {
  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const address = server.address();
  if (!address || typeof address === 'string') {
    throw new Error('HTTP server did not expose a TCP address');
  }
  return address.port;
}

async function waitForEvent<T>(socket: Socket, event: string): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`Timed out waiting for ${event}`)), 2_000);
    socket.once(event, (value: T) => {
      clearTimeout(timer);
      resolve(value);
    });
  });
}

afterAll(() => {
  rmSync(fixtureContext, { recursive: true, force: true });
});

describe('Hub assembly', () => {
  it('assembles the 16 manifest steps in order', () => {
    const layers = appLayers(app);

    expect(app.get('trust proxy')).toBe(1);
    expect(layers.map((layer) => layer.name)).toEqual([
      'helmetMiddleware',
      'corsMiddleware',
      'compression',
      'cookieParser',
      'jsonParser',
      'responseEnvelope',
      'sessionMiddleware',
      'csrfProtection',
      '<anonymous>',
      'bound dispatch',
      'router',
      'auditMiddleware',
      'notFoundHandler',
      'errorHandler',
    ]);
    expect(layers[8]?.handle).toBe(apiRateLimiter);
    expect(layers[9]?.route?.path).toBe('/api/v1/health');
  });

  it('returns health before authentication with the exact envelope', async () => {
    const response = await request(app).get('/api/v1/health');

    expect(response.status).toBe(200);
    expect(response.headers['content-type']).toContain('application/json');
    expect(response.body).toEqual({
      code: 0,
      message: '操作成功',
      data: { status: 'ok' },
    });
  });

  it('automatically discovers module route files', async () => {
    const response = await request(app).get('/api/v1/ping');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      code: 0,
      message: '操作成功',
      data: { pong: true },
    });
  });

  it('returns the JSON 404 envelope for unmatched routes', async () => {
    const response = await request(app).get('/api/v1/no-such-path');

    expect(response.status).toBe(404);
    expect(response.headers['content-type']).toContain('application/json');
    expect(response.body).toEqual({
      code: 40401,
      message: '要查看的记录不存在或已被删除',
      data: null,
    });
  });

  it('returns the COPY-013 JSON envelope for uncaught request errors', async () => {
    const response = await request(app)
      .post('/api/v1/no-such-path')
      .set('content-type', 'application/json')
      .send('{"broken":');

    expect(response.status).toBe(500);
    expect(response.headers['content-type']).toContain('application/json');
    expect(response.body).toEqual({
      code: 50001,
      message: '系统暂时无法处理，请稍后重试',
      data: null,
    });
  });

  it('places createApp, realtime attach, listen, and jobs in the required order', () => {
    const source = readFileSync(path.resolve(testDirectory, '../main.ts'), 'utf8');
    const positions = [
      source.indexOf('loadConfig();'),
      source.indexOf('const pool = getPool();'),
      source.indexOf('await runMigrations();'),
      source.indexOf('const app = createApp();'),
      source.indexOf('const server = http.createServer(app);'),
      source.indexOf('const io = initRealtime(server, sessionMiddleware);'),
      source.indexOf('server.listen(config.PORT'),
      source.indexOf('startJobs();'),
    ];

    expect(positions.every((position) => position >= 0)).toBe(true);
    for (let index = 1; index < positions.length; index += 1) {
      expect(positions[index]).toBeGreaterThan(positions[index - 1] ?? -1);
    }
  });
});

describe('realtime assembly', () => {
  it('rejects unauthenticated clients and delivers notifications to the user room', async () => {
    const server = createServer((_req, res) => res.end());
    const testSession: RequestHandler = (req, _res, next) => {
      if (req.headers.cookie?.includes('authenticated=yes')) {
        Object.assign(req, { session: { userId: 'user-42' } });
      }
      next();
    };
    const socketServer = initRealtime(server, testSession);
    const port = await listen(server);
    const endpoint = `http://127.0.0.1:${port}`;
    const clients: Socket[] = [];

    try {
      const unauthenticated = createSocketClient(endpoint, {
        path: '/ws',
        transports: ['websocket'],
        reconnection: false,
        forceNew: true,
      });
      clients.push(unauthenticated);

      const authenticationError = await new Promise<string>((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('Timed out waiting for handshake rejection')), 2_000);
        unauthenticated.once('connect_error', (error) => {
          clearTimeout(timer);
          resolve(error.message);
        });
        unauthenticated.once('connect', () => {
          clearTimeout(timer);
          reject(new Error('Unauthenticated socket unexpectedly connected'));
        });
      });
      expect(authenticationError).toBe('请先登录');

      const authenticated = createSocketClient(endpoint, {
        path: '/ws',
        transports: ['websocket'],
        reconnection: false,
        forceNew: true,
        extraHeaders: { cookie: 'authenticated=yes' },
      });
      clients.push(authenticated);
      await waitForEvent(authenticated, 'connect');

      const payload = {
        id: 'notification-1',
        title: '您有一条新通知',
        templateType: 'notice',
        createdAt: '2026-10-19T12:00:00.000Z',
      };
      const received = waitForEvent<typeof payload>(authenticated, 'notification:new');
      emitNotification('user-42', payload);

      await expect(received).resolves.toEqual(payload);
    } finally {
      clients.forEach((client) => client.disconnect());
      await new Promise<void>((resolve) => socketServer.close(() => resolve()));
      if (server.listening) {
        await new Promise<void>((resolve) => server.close(() => resolve()));
      }
    }
  });
});
