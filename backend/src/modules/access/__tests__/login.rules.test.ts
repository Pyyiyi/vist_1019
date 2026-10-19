import { describe, expect, it } from 'vitest';

import { MESSAGES } from '../../../shared/constants/messages.js';
import {
  isLockActive,
  isPasswordLongEnough,
  nextFailureState,
} from '../internal/auth.rules.js';

describe('登录失败与锁定规则', () => {
  const now = new Date('2026-10-19T12:00:00.000Z');

  it('前四次失败只累计次数，不锁定账号', () => {
    expect(nextFailureState(0, 5, 10, now)).toEqual({
      failedLoginCount: 1,
      lockedUntil: null,
      locked: false,
    });
    expect(nextFailureState(3, 5, 10, now)).toEqual({
      failedLoginCount: 4,
      lockedUntil: null,
      locked: false,
    });
  });

  it('第五次失败锁定十分钟，并在锁定期内保持锁定', () => {
    const state = nextFailureState(4, 5, 10, now);

    expect(state.failedLoginCount).toBe(5);
    expect(state.locked).toBe(true);
    expect(state.lockedUntil?.toISOString()).toBe('2026-10-19T12:10:00.000Z');
    expect(isLockActive(state.lockedUntil, new Date('2026-10-19T12:09:59.999Z'))).toBe(true);
    expect(isLockActive(state.lockedUntil, new Date('2026-10-19T12:10:00.000Z'))).toBe(false);
  });

  it('锁定期结束后允许重新尝试并清零旧计数', () => {
    expect(isLockActive(new Date('2026-10-19T11:59:59.999Z'), now)).toBe(false);
    expect(isLockActive(null, now)).toBe(false);
  });

  it('密码少于六位被拒绝，六位放行', () => {
    expect(isPasswordLongEnough('abc12')).toBe(false);
    expect(isPasswordLongEnough('abcdef')).toBe(true);
  });

  it('三类登录失败文案逐字使用共享常量', () => {
    expect(MESSAGES.INVALID_CREDENTIALS).toBe('账号或密码错误，请重新输入');
    expect(MESSAGES.ACCOUNT_DISABLED).toBe('该账号已停用，请联系管理员');
    expect(MESSAGES.ACCOUNT_LOCKED).toBe(
      '密码错误次数过多，账号已锁定，请在 10 分钟后重试',
    );
  });
});
