import { describe, expect, it } from 'vitest';

import { parseEraseReason, parseRetentionDays } from '../internal/privacy.service.js';

describe('privacy service rules', () => {
  it('accepts only positive integer retention days', () => {
    expect(parseRetentionDays(90)).toBe(90);
    expect(parseRetentionDays('365')).toBe(365);
    for (const value of [0, -1, 1.5, '0', 'abc', null]) {
      expect(() => parseRetentionDays(value)).toThrow('留存期限必须是大于 0 的整数');
    }
  });

  it('requires and trims a manual erase reason', () => {
    expect(parseEraseReason({ reason: '  本人申请  ' })).toBe('本人申请');
    expect(() => parseEraseReason({})).toThrow('请填写清除原因');
    expect(() => parseEraseReason({ reason: '长'.repeat(201) })).toThrow(
      '清除原因不能超过 200 个字符'
    );
  });
});
