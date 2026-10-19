import { describe, expect, it } from 'vitest';

import { assertRescheduleEligible, assertTransition, validateRejectReason } from '../internal/domain/rules.js';

describe('review rules', () => {
  it('allows approval only from pending review', () => {
    expect(() => assertTransition('待审核', '已通过')).not.toThrow();
    expect(() => assertTransition('已改期', '已通过')).toThrow();
    expect(() => assertTransition('已到访(在校中)', '已通过')).toThrow();
  });

  it('accepts reschedule from pending, proposed, and approved states', () => {
    for (const status of ['待审核', '已改期', '已通过']) {
      expect(() => assertRescheduleEligible(status)).not.toThrow();
    }
    for (const status of ['已拒绝', '已过期', '已到访(在校中)', '已离校', '已取消']) {
      expect(() => assertRescheduleEligible(status)).toThrow();
    }
  });

  it('trims and validates reject reasons', () => {
    expect(validateRejectReason('  时间冲突  ')).toBe('时间冲突');
    expect(() => validateRejectReason('')).toThrow('请填写拒绝原因');
    expect(() => validateRejectReason('x'.repeat(100))).not.toThrow();
  });
});
