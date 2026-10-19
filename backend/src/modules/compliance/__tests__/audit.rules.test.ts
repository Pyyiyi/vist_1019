import { describe, expect, it } from 'vitest';

import {
  SENSITIVE_AUDIT_ACTIONS,
  parseAuditFilters,
} from '../internal/audit.service.js';

describe('audit query rules', () => {
  it('normalizes all four query dimensions and pagination', () => {
    const filters = parseAuditFilters({
      user_id: '系统管理员',
      action: '审核同意',
      object_type: 'appointment',
      object_id: 'a-1',
      date_from: '2026-10-19',
      date_to: '2026-10-19',
      page: '2',
      page_size: '20',
    });
    expect(filters).toMatchObject({
      userId: '系统管理员',
      action: '审核同意',
      objectType: 'appointment',
      objectId: 'a-1',
      page: 2,
      pageSize: 20,
      offset: 20,
    });
    expect(filters.dateFrom?.toISOString()).toBe('2026-10-18T16:00:00.000Z');
    expect(filters.dateTo?.toISOString()).toBe('2026-10-19T15:59:59.999Z');
  });

  it('rejects malformed date boundaries with a field error', () => {
    expect(() => parseAuditFilters({ date_from: 'not-a-date' })).toThrow(
      '时间范围格式不正确'
    );
  });

  it('covers the seven sensitive operation classes', () => {
    expect(SENSITIVE_AUDIT_ACTIONS).toEqual(expect.arrayContaining([
      '审核同意', '审核拒绝', '放行', '核验', '取消预约',
      '异常上报', '异常处置', '越权拦截', '新增预约', '离校',
    ]));
  });
});
