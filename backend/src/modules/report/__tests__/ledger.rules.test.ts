import { describe, expect, it } from 'vitest';

import type { AuthenticatedUser } from '../../../shared/auth/types.js';
import { AppError } from '../../../shared/http/errors.js';
import {
  EXACT_ID_FORBIDDEN_MESSAGE,
  buildLedgerFilter,
  toLedgerItem,
} from '../internal/ledger.service.js';

const admin: AuthenticatedUser = {
  id: 'user-admin',
  username: 'admin',
  displayName: '管理员',
  roleCode: 'admin',
  hostId: null,
};

const guard: AuthenticatedUser = {
  id: 'user-guard',
  username: 'guard01',
  displayName: '门卫',
  roleCode: 'guard',
  hostId: null,
};

describe('report ledger rules', () => {
  it('guard 使用注入的 now=2026-10-12 固定为当日范围', () => {
    const filter = buildLedgerFilter(
      { date_from: '2026-10-01', date_to: '2026-10-31' },
      guard,
      new Date('2026-10-12T12:00:00+08:00'),
    );

    expect(filter.dateFrom?.toISOString()).toBe('2026-10-11T16:00:00.000Z');
    expect(filter.dateTo?.toISOString()).toBe('2026-10-12T15:59:59.999Z');
    expect(filter.clauses).toContain('a.visit_start >= $1');
    expect(filter.clauses).toContain('a.visit_start <= $2');
  });

  it('admin 可使用显式日期范围', () => {
    const filter = buildLedgerFilter(
      { date_from: '2026-10-01', date_to: '2026-10-31' },
      admin,
      new Date('2026-10-12T12:00:00+08:00'),
    );

    expect(filter.dateFrom?.toISOString()).toBe('2026-09-30T16:00:00.000Z');
    expect(filter.dateTo?.toISOString()).toBe('2026-10-31T15:59:59.999Z');
  });

  it('非 admin 完整证件号检索返回 COPY-208', () => {
    try {
      buildLedgerFilter({ id_no: '320101198803034566' }, guard);
      throw new Error('expected forbidden');
    } catch (error) {
      expect(error).toBeInstanceOf(AppError);
      expect((error as AppError).httpStatus).toBe(403);
      expect((error as AppError).message).toBe(EXACT_ID_FORBIDDEN_MESSAGE);
    }
  });

  it('台账行只输出脱敏证件号', () => {
    const item = toLedgerItem({
      appointment_id: 'a-1',
      appoint_no: 'AP20261012001',
      visitor_name: '陈晨',
      visitor_type: '公务访客',
      visitor_phone: '13800138000',
      visitor_id_no: '110101199003071233',
      host_name: '李明',
      visit_start: '2026-10-12T10:00:00+08:00',
      visit_end: '2026-10-12T11:00:00+08:00',
      checkin_at: null,
      checkout_at: null,
      status: '已通过',
      reason: '沟通',
    });

    expect(item.visitorIdNoMasked).toBe('1101**********1233');
  });
});
