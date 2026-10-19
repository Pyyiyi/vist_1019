import { describe, expect, it } from 'vitest';

import { inVerifyWindow, sameShanghaiDayAsNow } from '../internal/domain/rules.js';

const start = new Date('2026-10-20T10:00:00+08:00');
const end = new Date('2026-10-20T11:00:00+08:00');

describe('gate verification window', () => {
  it('includes both 15-minute boundaries', () => {
    expect(inVerifyWindow(start, end, new Date('2026-10-20T09:45:00+08:00'), 15)).toBe(true);
    expect(inVerifyWindow(start, end, new Date('2026-10-20T11:15:00+08:00'), 15)).toBe(true);
  });

  it('rejects one millisecond outside either boundary', () => {
    expect(inVerifyWindow(start, end, new Date('2026-10-20T09:44:59.999+08:00'), 15)).toBe(false);
    expect(inVerifyWindow(start, end, new Date('2026-10-20T11:15:00.001+08:00'), 15)).toBe(false);
  });

  it('recognises the same Shanghai calendar day for re-entry', () => {
    expect(sameShanghaiDayAsNow(end, new Date('2026-10-20T23:59:59+08:00'))).toBe(true);
    expect(sameShanghaiDayAsNow(end, new Date('2026-10-21T00:00:00+08:00'))).toBe(false);
  });
});
