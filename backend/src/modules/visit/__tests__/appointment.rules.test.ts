import { describe, expect, it } from 'vitest';

import {
  assertRescheduleEligible,
  assertTransition,
  intervalsIntersect,
  normalizeCompanions,
  validateRejectReason,
  validateVisitWindow,
} from '../internal/domain/rules.js';

const at = (value: string) => new Date(value);

describe('appointment rules', () => {
  it('accepts a 15-minute same-day window and rejects a past start', () => {
    const now = at('2026-10-20T09:00:00+08:00');
    expect(() => validateVisitWindow(at('2026-10-20T09:01:00+08:00'), at('2026-10-20T09:16:00+08:00'), now)).not.toThrow();
    expect(() => validateVisitWindow(at('2026-10-20T09:00:00+08:00'), at('2026-10-20T09:15:00+08:00'), now)).toThrow('开始时间必须晚于当前时间');
    expect(() => validateVisitWindow(at('2026-10-19T09:00:00+08:00'), at('2026-10-19T09:15:00+08:00'), now)).toThrow();
  });

  it('rejects cross-day, too-short, and too-long windows', () => {
    const now = at('2026-10-19T00:00:00+08:00');
    expect(() => validateVisitWindow(at('2026-10-20T23:50:00+08:00'), at('2026-10-21T00:10:00+08:00'), now)).toThrow('预约必须在同一天内完成');
    expect(() => validateVisitWindow(at('2026-10-20T10:00:00+08:00'), at('2026-10-20T10:14:00+08:00'), now)).toThrow('到访时段不能少于 15 分钟');
    expect(() => validateVisitWindow(at('2026-10-20T10:00:00+08:00'), at('2026-10-20T14:01:00+08:00'), now)).toThrow('到访时段不能超过 240 分钟');
  });

  it('allows an end-of-day walk-in visit to cross midnight only when explicitly enabled', () => {
    const now = at('2026-10-20T23:55:00+08:00');
    expect(() => validateVisitWindow(at('2026-10-20T23:55:00+08:00'), at('2026-10-21T00:55:00+08:00'), now, 15, 240, true, true)).not.toThrow();
    expect(() => validateVisitWindow(at('2026-10-20T23:55:00+08:00'), at('2026-10-21T00:55:00+08:00'), now, 15, 240, true, false)).toThrow('预约必须在同一天内完成');
  });

  it('limits companions to ten and validates every companion id', () => {
    const rows = Array.from({ length: 10 }, (_, index) => ({ name: `家属${index}`, relation: '家属', id_no: '110101199003071233' }));
    expect(normalizeCompanions(rows)).toHaveLength(10);
    expect(() => normalizeCompanions([...rows, rows[0]])).toThrow('最多添加 10 名随行人员');
    expect(() => normalizeCompanions([{ name: '家属', relation: '家属', id_no: '1' }])).toThrow('请输入正确的随行人员证件号');
  });

  it('uses closed intervals for duplicate appointment detection', () => {
    const start = at('2026-10-20T10:00:00+08:00');
    const end = at('2026-10-20T11:00:00+08:00');
    expect(intervalsIntersect(start, end, at('2026-10-20T10:00:00+08:00'), at('2026-10-20T10:30:00+08:00'))).toBe(true);
    expect(intervalsIntersect(start, end, at('2026-10-20T11:00:00+08:00'), at('2026-10-20T11:30:00+08:00'))).toBe(true);
    expect(intervalsIntersect(start, end, at('2026-10-20T11:00:01+08:00'), at('2026-10-20T11:30:00+08:00'))).toBe(false);
  });

  it('enforces the state machine and repeatable reschedule edge states', () => {
    expect(() => assertTransition('待审核', '已通过')).not.toThrow();
    expect(() => assertTransition('已到访(在校中)', '已取消')).toThrow('当前状态不允许该操作，请刷新后重试');
    expect(() => assertTransition('已改期', '已通过')).toThrow('当前状态不允许该操作，请刷新后重试');
    expect(() => assertRescheduleEligible('已通过')).not.toThrow();
    expect(() => assertRescheduleEligible('已到访(在校中)')).toThrow('当前状态不允许该操作，请刷新后重试');
  });

  it('validates reject reason length by character count', () => {
    expect(validateRejectReason('原因')).toBe('原因');
    expect(() => validateRejectReason('原')).toThrow('拒绝原因至少 2 个字符');
    expect(() => validateRejectReason('长'.repeat(101))).toThrow('拒绝原因不能超过 100 个字符');
  });
});
