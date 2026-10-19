import request from 'supertest';
import { describe, expect, it } from 'vitest';

import app from '../app.js';

describe('GET /api/v1/health', () => {
  it('returns the exact health envelope', async () => {
    const response = await request(app).get('/api/v1/health');

    expect(response.status).toBe(200);
    expect(response.headers['content-type']).toContain('application/json');
    expect(response.body).toEqual({
      code: 0,
      message: '操作成功',
      data: { status: 'ok' },
    });
  });
});
