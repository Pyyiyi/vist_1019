import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    path: '/master',
    name: 'master-data',
    component: () => import('./MasterDataPage.vue'),
    meta: { layout: 'app', roles: ['admin'], title: '主数据' },
  },
  {
    path: '/system/settings',
    name: 'system-settings',
    component: () => import('./SystemSettingsPage.vue'),
    meta: { layout: 'app', roles: ['admin'], title: '参数与字典' },
  },
];

export default routes;
