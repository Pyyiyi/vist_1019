import { createServer, type Server as HttpServer } from 'node:http';
import express from 'express';
import type { RequestHandler } from 'express';
import { Server as SocketServer } from 'socket.io';
import { io as createSocketClient } from 'socket.io-client';
import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

import { initRealtime } from '../../realtime/io.js';
import { writeAudit } from '../audit/writeAudit.js';
import { errorHandler } from '../http/errorHandler.js';
import { notFoundHandler } from '../http/notFoundHandler.js';
import { responseEnvelope } from '../http/responseEnvelope.js';

function envelopeApp() {
  const app = express();
  app.use(responseEnvelope);
  app.get('/success', (_req, res) => res.success({ ok: true }));
  app.get('/fail', (_req, res) =>
    res.fail(422, 42201, '请输入手机号', 'visitor_phone')
  );
  app.get('/page', (_req, res) => res.paginated([1, 2], 12, 1, 20));
  return app;
}

describe('response envelope and error handlers', () => {
  it('returns the exact success and pagination envelopes', async () => {
    const app = envelopeApp();
    const successResponse = await request(app).get('/success');
    const pageResponse = await request(app).get('/page');

    expect(successResponse.status).toBe(200);
    expect(successResponse.body).toEqual({
      code: 0,
      message: '操作成功',
      data: { ok: true },
    });
    expect(pageResponse.body).toEqual({
      code: 0,
      message: '操作成功',
      data: { items: [1, 2], total: 12, page: 1, page_size: 20 },
    });
  });

  it('returns fail envelopes with an optional field', async () => {
    const response = await request(envelopeApp()).get('/fail');

    expect(response.status).toBe(422);
    expect(response.body).toEqual({
      code: 42201,
      message: '请输入手机号',
      data: null,
      field: 'visitor_phone',
    });
  });

  it('returns JSON 404 with COPY-008 for unmatched routes', async () => {
    const app = express();
    app.use(responseEnvelope);
    app.use(notFoundHandler);

    const response = await request(app).get('/missing');

    expect(response.status).toBe(404);
    expect(response.headers['content-type']).toContain('application/json');
    expect(response.body).toEqual({
      code: 40401,
      message: '要查看的记录不存在或已被删除',
      data: null,
    });
    expect(typeof notFoundHandler).toBe('function');
  });

  it('maps unknown exceptions to the COPY-013 server envelope', async () => {
    const app = express();
    app.use(responseEnvelope);
    app.get('/boom', () => {
      throw new Error('database detail that must not leak');
    });
    app.use(errorHandler);
    const logSpy = vi.spyOn(console, 'log').mockImplementation(() => undefined);

    const response = await request(app).get('/boom');

    expect(response.status).toBe(500);
    expect(response.body).toEqual({
      code: 50001,
      message: '系统暂时无法处理，请稍后重试',
      data: null,
    });
    expect(JSON.stringify(response.body)).not.toContain('database detail');
    logSpy.mockRestore();
  });
});

describe('writeAudit', () => {
  it('writes every required operation_logs field', async () => {
    const queryMock = vi.fn().mockResolvedValue({ rows: [], rowCount: 1 });
    const client = { query: queryMock } as unknown as import('pg').PoolClient;

    await writeAudit(client, {
      userId: 'user-1',
      userName: '管理员',
      objectType: 'appointment',
      objectId: 'appointment-1',
      action: '审核同意',
      result: '成功',
      before: { status: '待审核' },
      after: { status: '已通过' },
      ip: '127.0.0.1',
      note: '审核',
    });

    expect(queryMock).toHaveBeenCalledTimes(1);
    const [sql, params] = queryMock.mock.calls[0];
    expect(sql).toContain('INSERT INTO operation_logs');
    for (const field of [
      'user_id',
      'user_name',
      'occurred_at',
      'object_type',
      'object_id',
      'action',
      'result',
      'before_value',
      'after_value',
    ]) {
      expect(sql).toContain(field);
    }
    expect(params[1]).toBe('user-1');
    expect(params[2]).toBe('管理员');
    expect(params[3]).toBeInstanceOf(Date);
    expect(params[4]).toBe('appointment');
    expect(params[5]).toBe('appointment-1');
    expect(params[6]).toBe('审核同意');
    expect(params[7]).toBe('成功');
    expect(params[8]).toBe(JSON.stringify({ status: '待审核' }));
    expect(params[9]).toBe(JSON.stringify({ status: '已通过' }));
  });

  it('does not block business flow when audit persistence fails', async () => {
    const queryMock = vi.fn().mockRejectedValue(new Error('db down'));
    const client = { query: queryMock } as unknown as import('pg').PoolClient;
    const logSpy = vi.spyOn(console, 'log').mockImplementation(() => undefined);

    await expect(
      writeAudit(client, {
        userId: null,
        userName: '',
        objectType: 'appointment',
        objectId: null,
        action: '新增预约',
        result: '失败',
      })
    ).resolves.toBeUndefined();
    logSpy.mockRestore();
  });
});

async function listen(server: HttpServer): Promise<number> {
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  if (!address || typeof address === 'string') {
    throw new Error('测试服务未获得端口');
  }
  return address.port;
}

async function closeServer(server: HttpServer): Promise<void> {
  if (!server.listening) {
    return;
  }
  await new Promise<void>((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
}

describe('initRealtime', () => {
  it('returns a SocketServer mounted at /ws and rejects unauthenticated handshakes', async () => {
    const server = createServer();
    const sessionMiddleware: RequestHandler = (_req, _res, next) => next();
    const socketServer = initRealtime(server, sessionMiddleware);

    expect(socketServer).toBeInstanceOf(SocketServer);
    expect(socketServer.path()).toBe('/ws');

    const port = await listen(server);
    const client = createSocketClient(`http://127.0.0.1:${port}`, {
      path: '/ws',
      transports: ['websocket'],
      reconnection: false,
      forceNew: true,
    });

    const handshakeError = await new Promise<Error>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('握手超时')), 3000);
      client.once('connect_error', (error) => {
        clearTimeout(timer);
        resolve(error);
      });
      client.once('connect', () => {
        clearTimeout(timer);
        reject(new Error('未认证连接不应成功'));
      });
    });

    expect(handshakeError.message).toBe('请先登录');
    client.close();
    await new Promise<void>((resolve) => socketServer.close(() => resolve()));
    await closeServer(server);
  });
});
