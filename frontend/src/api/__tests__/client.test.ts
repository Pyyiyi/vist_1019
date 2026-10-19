import { beforeEach, describe, expect, it, vi } from 'vitest';

const { interceptors } = vi.hoisted(() => ({
  interceptors: {
    request: { use: vi.fn() },
    response: { use: vi.fn() },
  },
}));

vi.mock('axios', () => ({
  default: {
    create: vi.fn(() => ({ interceptors })),
    get: vi.fn(),
  },
}));

import axios from 'axios';
import apiClient, {
  requestInterceptor,
  responseInterceptor,
} from '../client';

describe('api client interceptors', () => {
  beforeEach(() => {
    document.cookie = 'vs.csrf=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/';
  });

  it('creates the configured axios instance and installs both interceptors', () => {
    expect(axios.create).toHaveBeenCalledWith({
      baseURL: '/api/v1',
      withCredentials: true,
    });
    expect(apiClient.interceptors.request.use).toHaveBeenCalled();
    expect(apiClient.interceptors.response.use).toHaveBeenCalled();
  });

  it('converts request keys to snake_case and injects the CSRF header', async () => {
    document.cookie = 'vs.csrf=csrf-token; path=/';

    const config = {
      method: 'post',
      url: '/appointments',
      headers: {},
      data: {
        visitorName: '张三',
        visitStart: '2026-10-19T09:00:00+08:00',
        visitors: [{ idNo: '110101199001011234' }],
        field: 'visitor_name',
      },
      params: {
        pageSize: 20,
        dateFrom: '2026-10-19',
      },
    } as any;

    const transformed = await requestInterceptor(config);

    expect(transformed.data).toEqual({
      visitor_name: '张三',
      visit_start: '2026-10-19T09:00:00+08:00',
      visitors: [{ id_no: '110101199001011234' }],
      field: 'visitor_name',
    });
    expect(transformed.params).toEqual({
      page_size: 20,
      date_from: '2026-10-19',
    });
    expect(transformed.headers['X-CSRF-Token']).toBe('csrf-token');
  });

  it('converts response data keys without unwrapping the envelope', () => {
    const response = {
      data: {
        code: 0,
        message: '操作成功',
        data: {
          display_name: '系统管理员',
          role_code: 'admin',
          host_id: null,
          appointments: [
            {
              visit_start: '2026-10-19T09:00:00+08:00',
              visitor_name: '张三',
              field: 'visitor_name',
            },
          ],
        },
      },
    } as any;

    const transformed = responseInterceptor(response);

    expect(transformed.data.code).toBe(0);
    expect(transformed.data.message).toBe('操作成功');
    expect(transformed.data.data.displayName).toBe('系统管理员');
    expect(transformed.data.data.roleCode).toBe('admin');
    expect(transformed.data.data.hostId).toBeNull();
    expect(transformed.data.data.appointments[0].visitStart).toBe(
      '2026-10-19T09:00:00+08:00',
    );
    expect(transformed.data.data.appointments[0].field).toBe('visitor_name');
    expect(transformed.data.data).toBeDefined();
  });
});
