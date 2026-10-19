export type NavItem = {
  key: string;
  title: string;
  path: string;
  roles: string[];
  icon: string;
  children?: NavItem[];
};

export const navigation: NavItem[] = [
  { key: 'workbench', title: '工作台', path: '/workbench', roles: ['admin', 'guard', 'host'], icon: 'DashboardOutlined' },
  { key: 'appointments', title: '访客预约', path: '/appointments', roles: ['admin', 'host'], icon: 'FormOutlined' },
  { key: 'reviews', title: '被访人审核', path: '/reviews', roles: ['admin', 'host'], icon: 'AuditOutlined' },
  { key: 'gate', title: '门卫核验', path: '/gate', roles: ['admin', 'guard'], icon: 'SafetyOutlined' },
  { key: 'ledger', title: '访客台账', path: '/ledger', roles: ['admin', 'guard'], icon: 'TableOutlined' },
  { key: 'on-campus', title: '在校清单', path: '/on-campus', roles: ['admin', 'guard'], icon: 'TeamOutlined' },
  { key: 'statistics', title: '统计分析', path: '/statistics', roles: ['admin'], icon: 'BarChartOutlined' },
  { key: 'users', title: '用户与角色', path: '/users', roles: ['admin'], icon: 'UserOutlined' },
  { key: 'master', title: '主数据', path: '/master', roles: ['admin'], icon: 'DatabaseOutlined' },
  { key: 'notifications', title: '通知中心', path: '/notifications', roles: ['admin', 'guard', 'host'], icon: 'BellOutlined' },
  {
    key: 'system',
    title: '系统管理',
    path: '/system',
    roles: ['admin'],
    icon: 'SettingOutlined',
    children: [
      { key: 'system-settings', title: '参数与字典', path: '/system/settings', roles: ['admin'], icon: 'SlidersOutlined' },
      { key: 'system-audit', title: '操作日志', path: '/system/audit', roles: ['admin'], icon: 'FileSearchOutlined' },
      { key: 'system-privacy', title: '信息保护', path: '/system/privacy', roles: ['admin'], icon: 'SafetyCertificateOutlined' },
    ],
  },
];

export function filterNavigation(items: NavItem[], role: string): NavItem[] {
  return items
    .filter((item) => item.roles.includes(role))
    .map((item) => ({
      ...item,
      children: item.children
        ? filterNavigation(item.children, role)
        : undefined,
    }));
}
