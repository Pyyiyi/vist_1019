import express from 'express';
import { body, query } from 'express-validator';
import request from 'supertest';
import { describe, expect, it } from 'vitest';

import { errorHandler } from '../http/errorHandler.js';
import {
  isValidIdCard,
  isValidOtherId,
  isValidPhone,
  normalizeIdNo,
  validateBody,
  validateQuery,
} from '../validation/validators.js';

function testApp() {
  const app = express();
  app.use(express.json());
  app.post(
    '/body',
    validateBody([
      body('visitor_phone')
        .isLength({ min: 11, max: 11 })
        .withMessage('请输入 11 位手机号'),
    ]),
    (_req, res) => {
      res.json({ ok: true });
    }
  );
  app.get(
    '/query',
    validateQuery([query('page').isInt().withMessage('页码必须是数字')]),
    (_req, res) => {
      res.json({ ok: true });
    }
  );
  app.use(errorHandler);
  return app;
}

describe('validators', () => {
  it('validates request bodies and reports the first field verbatim', async () => {
    const response = await request(testApp()).post('/body').send({ visitor_phone: '123' });

    expect(response.status).toBe(422);
    expect(response.body).toEqual({
      code: 42201,
      message: '请输入 11 位手机号',
      data: null,
      field: 'visitor_phone',
    });
  });

  it('validates query parameters', async () => {
    const response = await request(testApp()).get('/query?page=not-a-number');

    expect(response.status).toBe(422);
    expect(response.body.code).toBe(42201);
    expect(response.body.field).toBe('page');
    expect(response.body.message).toBe('页码必须是数字');
  });

  it('checks Chinese ID cards with the GB 11643 checksum', () => {
    expect(isValidIdCard('11010519491231002X')).toBe(true);
    expect(isValidIdCard('11010519491231002x')).toBe(true);
    expect(isValidIdCard('110105194912310021')).toBe(false);
    expect(isValidIdCard('11010519491231002')).toBe(false);
  });

  it('checks phone and alternate identifier formats', () => {
    expect(isValidPhone('13800138000')).toBe(true);
    expect(isValidPhone('23800138000')).toBe(false);
    expect(isValidPhone('1380013800')).toBe(false);
    expect(isValidOtherId('P1234567')).toBe(true);
    expect(isValidOtherId('A123')).toBe(false);
    expect(isValidOtherId('A123-456')).toBe(false);
  });

  it('normalizes whitespace and letter case', () => {
    expect(normalizeIdNo(' 110105 19491231 002x ')).toBe('11010519491231002X');
  });
});
