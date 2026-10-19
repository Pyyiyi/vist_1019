import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    path: '/ledger',
    name: 'ledger',
    component: () => import('./LedgerPage.vue'),
    meta: { layout: 'app', roles: ['admin', 'guard'], title: '访客台账' },
  },
  {
    path: '/on-campus',
    name: 'on-campus',
    component: () => import('./OnCampusPage.vue'),
    meta: { layout: 'app', roles: ['admin', 'guard'], title: '在校清单' },
  },
  {
    path: '/statistics',
    name: 'statistics',
    component: () => import('./StatisticsPage.vue'),
    meta: { layout: 'app', roles: ['admin'], title: '统计分析' },
  },
];

export default routes;
