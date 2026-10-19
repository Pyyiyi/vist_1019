import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    path: '/notifications',
    name: 'notifications',
    component: () => import('./NotificationsPage.vue'),
    meta: {
      layout: 'app',
      roles: ['admin', 'guard', 'host'],
      title: '通知中心',
    },
  },
];

export default routes;
