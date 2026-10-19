import { describe, expect, it } from 'vitest';

import { iconMap } from '@/nav/icons';
import {
  filterNavigation,
  navigation,
  type NavItem,
} from '@/nav/navigation';

function keys(items: NavItem[]): string[] {
  return items.map((item) => item.key);
}

describe('navigation', () => {
  it('uses the exact visible Chinese navigation titles', () => {
    expect(navigation.map((item) => item.title)).toEqual([
      '工作台',
      '访客预约',
      '被访人审核',
      '门卫核验',
      '访客台账',
      '在校清单',
      '统计分析',
      '用户与角色',
      '主数据',
      '通知中心',
      '系统管理',
    ]);
  });

  it('filters admin navigation and keeps all three system children', () => {
    const filtered = filterNavigation(navigation, 'admin');
    const system = filtered.find((item) => item.key === 'system');

    expect(keys(filtered)).toContain('system');
    expect(system?.children).toHaveLength(3);
    expect(system?.children?.map((item) => item.key)).toEqual([
      'system-settings',
      'system-audit',
      'system-privacy',
    ]);
  });

  it('removes admin-only items for guard', () => {
    const filteredKeys = keys(filterNavigation(navigation, 'guard'));

    expect(filteredKeys).not.toContain('users');
    expect(filteredKeys).not.toContain('master');
    expect(filteredKeys).not.toContain('statistics');
    expect(filteredKeys).not.toContain('system');
  });

  it('keeps host-visible workbench, appointment, review, and notification entries', () => {
    expect(keys(filterNavigation(navigation, 'host'))).toEqual([
      'workbench',
      'appointments',
      'reviews',
      'notifications',
    ]);
  });

  it('drops a parent when none of its children are visible', () => {
    const items: NavItem[] = [
      {
        key: 'parent',
        title: '父级',
        path: '/parent',
        roles: ['admin'],
        icon: 'SettingOutlined',
        children: [
          {
            key: 'child',
            title: '子级',
            path: '/parent/child',
            roles: ['guard'],
            icon: 'UserOutlined',
          },
        ],
      },
    ];

    expect(filterNavigation(items, 'admin')).toEqual([]);
  });

  it('resolves every configured navigation icon through iconMap', () => {
    const visit = (items: NavItem[]): void => {
      items.forEach((item) => {
        expect(iconMap[item.icon]).toBeDefined();
        if (item.children) {
          visit(item.children);
        }
      });
    };

    visit(navigation);
  });
});
