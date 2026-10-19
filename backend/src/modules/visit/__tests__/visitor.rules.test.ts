import { describe, expect, it } from 'vitest';

import { hashVisitorToken, newVisitorToken } from '../internal/visitor.service.js';
import { isRescheduleExpired, rescheduleDeadline } from '../internal/domain/rules.js';

describe('visitor token rules', () => {
  it('issues a 32-byte base64url token and stores a SHA-256 hash', () => {
    const token = newVisitorToken();
    expect(token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(token).not.toMatch(/^\d{6}$/);
    expect(hashVisitorToken(token)).toMatch(/^[a-f0-9]{64}$/);
    expect(hashVisitorToken(token)).toBe(hashVisitorToken(token));
  });

  it('allows confirmation exactly at the three-hour deadline and rejects one millisecond later', () => {
    const proposed = new Date('2026-10-20T08:30:00+08:00');
    const deadline = rescheduleDeadline(proposed, 3);
    expect(deadline.toISOString()).toBe(new Date('2026-10-20T11:30:00+08:00').toISOString());
    expect(isRescheduleExpired(proposed, new Date('2026-10-20T11:30:00+08:00'), 3)).toBe(false);
    expect(isRescheduleExpired(proposed, new Date('2026-10-20T11:30:00.001+08:00'), 3)).toBe(true);
  });
});
