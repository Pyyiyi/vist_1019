import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    path: '/system/audit',
    name: 'system-audit',
    component: () => import('./AuditLogsPage.vue'),
    meta: { layout: 'app', roles: ['admin'], title: '操作日志' },
  },
  {
    path: '/system/privacy',
    name: 'system-privacy',
    component: () => import('./PrivacyPage.vue'),
    meta: { layout: 'app', roles: ['admin'], title: '信息保护' },
  },
  {
    path: '/h5/privacy',
    name: 'compliance-h5-privacy',
    component: () => import('./H5PrivacyPage.vue'),
    meta: { layout: 'h5', title: '个人信息说明' },
  },
];

export default routes;
