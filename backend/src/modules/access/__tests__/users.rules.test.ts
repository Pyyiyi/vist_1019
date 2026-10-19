import { describe, expect, it } from 'vitest';

import {
  isAccountRole,
  isSelfDeactivation,
  normalizeHostBinding,
  wouldRemoveLastAdmin,
} from '../internal/users.rules.js';

describe('用户与角色保护规则', () => {
  it('只允许 admin/guard/host 作为后台账号角色', () => {
    expect(isAccountRole('admin')).toBe(true);
    expect(isAccountRole('guard')).toBe(true);
    expect(isAccountRole('host')).toBe(true);
    expect(isAccountRole('visitor')).toBe(false);
    expect(isAccountRole(undefined)).toBe(false);
  });

  it('当前登录账号不能停用自己', () => {
    expect(isSelfDeactivation('user-1', 'user-1', 'inactive')).toBe(true);
    expect(isSelfDeactivation('user-1', 'user-2', 'inactive')).toBe(false);
    expect(isSelfDeactivation('user-1', 'user-1', 'active')).toBe(false);
  });

  it('唯一启用管理员不能被降级', () => {
    expect(
      wouldRemoveLastAdmin({
        targetRole: 'admin',
        targetStatus: 'active',
        nextRole: 'guard',
        activeAdminCount: 1,
      }),
    ).toBe(true);
    expect(
      wouldRemoveLastAdmin({
        targetRole: 'admin',
        targetStatus: 'active',
        nextRole: 'guard',
        activeAdminCount: 2,
      }),
    ).toBe(false);
  });

  it('管理员保留 admin 角色时不触发唯一管理员保护', () => {
    expect(
      wouldRemoveLastAdmin({
        targetRole: 'admin',
        targetStatus: 'active',
        nextRole: 'admin',
        activeAdminCount: 1,
      }),
    ).toBe(false);
  });

  it('非 host 角色清除 host 绑定，host 角色保留绑定', () => {
    expect(normalizeHostBinding('host', 'host-1')).toBe('host-1');
    expect(normalizeHostBinding('guard', 'host-1')).toBeNull();
    expect(normalizeHostBinding('admin', null)).toBeNull();
  });
});
