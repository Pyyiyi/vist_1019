import { describe, expect, it } from 'vitest';

import {
  isEffectiveBlacklist,
  normalizeBlacklistIdNos,
  shouldExpireBlacklist,
} from '../internal/domain/blacklist.rules.js';

describe('blacklist domain rules', () => {
  const now = new Date('2026-10-19T12:00:00+08:00');

  it('keeps an entry effective at the exact expiry instant', () => {
    expect(isEffectiveBlacklist({ status: '有效', expireAt: now }, now)).toBe(true);
    expect(shouldExpireBlacklist({ status: '有效', expireAt: now }, now)).toBe(false);
  });

  it('expires only effective entries strictly before now', () => {
    const oneSecondBefore = new Date(now.getTime() - 1000);
    expect(isEffectiveBlacklist({ status: '有效', expireAt: oneSecondBefore }, now)).toBe(false);
    expect(shouldExpireBlacklist({ status: '有效', expireAt: oneSecondBefore }, now)).toBe(true);
    expect(shouldExpireBlacklist({ status: '已删除', expireAt: oneSecondBefore }, now)).toBe(false);
    expect(isEffectiveBlacklist({ status: '已过期', expireAt: now }, now)).toBe(false);
  });

  it('normalizes and deduplicates id numbers before lookup', () => {
    expect(normalizeBlacklistIdNos([' 320101198803034566 ', '320101198803034566', 'abc 123'])).toEqual([
      '320101198803034566',
      'ABC123',
    ]);
  });
});
